import { AnySchema, ValidateResult } from '../core/types';

/** ArkUI 字段事件触发类型。 */
export class FormTrigger {
  static readonly CHANGE: string = 'change';
  static readonly BLUR: string = 'blur';
  static readonly SUBMIT: string = 'submit';
  static readonly MANUAL: string = 'manual';
}

/** 单字段的事件校验配置。 */
export interface FormFieldOptions {
  /** 允许触发校验的事件；默认继承表单配置。 */
  triggers?: string[];
  /** change 事件的防抖毫秒数；默认继承表单配置。 */
  debounceMs?: number;
  /** 当前字段依赖的源字段。源字段变化时会重新校验当前字段。 */
  dependencies?: string[];
}

/** FormValidator 的事件与字段配置。 */
export interface FormValidatorOptions {
  /** 默认触发事件，缺省为 change。 */
  triggers?: string[];
  /** 默认 change 防抖毫秒数，缺省为 0。 */
  debounceMs?: number;
  /** 字段级配置。 */
  fields?: Record<string, FormFieldOptions>;
}

/** 可安全读取的单字段状态快照。 */
export class FormFieldState {
  touched: boolean = false;
  dirty: boolean = false;
  validating: boolean = false;
  error: string | null = null;
}

/** 可安全读取的整表状态快照。 */
export class FormState {
  submitting: boolean = false;
  errors: Record<string, string> = {};
}

export type FormSubmitHandler = (values: Record<string, Object>) => Promise<void>;
type DebounceResolver = (message: string | null) => void;

/**
 * 与 UI 解耦的 ArkUI 表单校验控制器。
 *
 * 旧版显式校验 API 保持不变；0.6.0 起可通过 validateOn 在 change/blur 等事件中
 * 使用触发策略、防抖、字段依赖和状态快照。页面销毁时应调用 dispose()。
 */
export class FormValidator {
  private shape: Record<string, AnySchema>;
  private options: FormValidatorOptions;
  private fieldStates: Map<string, FormFieldState> = new Map<string, FormFieldState>();
  private errors: Record<string, string> = {};
  private submitting: boolean = false;
  private versions: Map<string, number> = new Map<string, number>();
  private timers: Map<string, number> = new Map<string, number>();
  private debounceResolvers: Map<string, DebounceResolver> = new Map<string, DebounceResolver>();
  private dependents: Map<string, string[]> = new Map<string, string[]>();
  private disposed: boolean = false;

  constructor(shape: Record<string, AnySchema>, options?: FormValidatorOptions) {
    this.shape = shape;
    this.options = options === undefined ? {} : options;
    const keys = Object.keys(shape);
    for (const key of keys) {
      this.fieldStates.set(key, new FormFieldState());
    }
    this.buildDependencyIndex();
  }

  /** 校验单个字段并记录首条错误；未知字段返回 null。 */
  validateField(name: string, value: Object | null | undefined,
    allValues?: Record<string, Object>): string | null {
    const schema: AnySchema = this.shape[name];
    if (schema === undefined) {
      return null;
    }
    this.cancelDebounce(name);
    this.nextVersion(name);
    const r = schema.validate(value, allValues);
    const message = r.valid ? null : r.errors[0].message;
    this.setError(name, message);
    return message;
  }

  /** 异步校验单个字段；过期请求不会覆盖较新的字段状态。 */
  async validateFieldAsync(name: string, value: Object | null | undefined,
    allValues?: Record<string, Object>): Promise<string | null> {
    if (this.shape[name] === undefined) {
      return null;
    }
    this.cancelDebounce(name);
    const version = this.nextVersion(name);
    return this.runLatestValidation(name, value, allValues, version);
  }

  /** 整体同步校验，返回只含出错字段的 map。 */
  validateAll(values: Record<string, Object>): Record<string, string> {
    const errors: Record<string, string> = {};
    const keys = Object.keys(this.shape);
    for (const key of keys) {
      this.cancelDebounce(key);
      this.nextVersion(key);
      const r = this.shape[key].validate(values[key], values);
      if (!r.valid) {
        errors[key] = r.errors[0].message;
      }
      this.setError(key, r.valid ? null : r.errors[0].message);
    }
    return errors;
  }

  /** 整体异步校验；顶层字段并发执行，结果按 shape 顺序归并。 */
  async validateAllAsync(values: Record<string, Object>): Promise<Record<string, string>> {
    const errors: Record<string, string> = {};
    const keys = Object.keys(this.shape);
    const versions: number[] = [];
    const tasks: Array<Promise<ValidateResult>> = [];
    for (const key of keys) {
      this.cancelDebounce(key);
      versions.push(this.nextVersion(key));
      this.getMutableFieldState(key).validating = true;
      tasks.push(this.shape[key].validateAsync(values[key], values));
    }
    try {
      const results = await Promise.all(tasks);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const result = results[i];
        if (!result.valid) {
          errors[key] = result.errors[0].message;
        }
        if (this.isLatest(key, versions[i])) {
          this.setError(key, result.valid ? null : result.errors[0].message);
        }
      }
      return errors;
    } finally {
      for (let i = 0; i < keys.length; i++) {
        if (this.isLatest(keys[i], versions[i])) {
          this.getMutableFieldState(keys[i]).validating = false;
        }
      }
    }
  }

  /** 整体是否通过。 */
  isValid(values: Record<string, Object>): boolean {
    return Object.keys(this.validateAll(values)).length === 0;
  }

  /** 异步整体校验是否通过。 */
  async isValidAsync(values: Record<string, Object>): Promise<boolean> {
    return Object.keys(await this.validateAllAsync(values)).length === 0;
  }

  /**
   * 按 ArkUI 事件校验字段。change 会标记 dirty，blur 会标记 touched；
   * 仅配置的触发类型会执行校验。源字段 change 后会重校验其直接依赖字段。
   */
  async validateOn(name: string, value: Object | null | undefined, trigger: string,
    allValues?: Record<string, Object>): Promise<string | null> {
    if (this.shape[name] === undefined || this.disposed) {
      return null;
    }
    const state = this.getMutableFieldState(name);
    if (trigger === FormTrigger.CHANGE) {
      state.dirty = true;
    }
    if (trigger === FormTrigger.BLUR) {
      state.touched = true;
    }

    let message: string | null = state.error;
    if (this.shouldValidate(name, trigger)) {
      const debounceMs = trigger === FormTrigger.CHANGE ? this.getDebounceMs(name) : 0;
      if (debounceMs > 0) {
        message = await this.validateDebounced(name, value, allValues, debounceMs);
      } else {
        message = await this.validateFieldAsync(name, value, allValues);
      }
    }
    if (trigger === FormTrigger.CHANGE) {
      await this.validateDependents(name, allValues);
    }
    return message;
  }

  /** ArkUI onChange 的便捷入口。 */
  async onChange(name: string, value: Object | null | undefined,
    allValues?: Record<string, Object>): Promise<string | null> {
    return this.validateOn(name, value, FormTrigger.CHANGE, allValues);
  }

  /** ArkUI onBlur 的便捷入口。 */
  async onBlur(name: string, value: Object | null | undefined,
    allValues?: Record<string, Object>): Promise<string | null> {
    return this.validateOn(name, value, FormTrigger.BLUR, allValues);
  }

  /**
   * 提交整表。所有字段先标记 touched 并执行异步校验；无错误时才调用 handler。
   * handler 抛出的异常会继续向调用方传播，submitting 状态始终在 finally 中恢复。
   */
  async submit(values: Record<string, Object>, handler?: FormSubmitHandler): Promise<Record<string, string>> {
    this.submitting = true;
    const keys = Object.keys(this.shape);
    for (const key of keys) {
      this.getMutableFieldState(key).touched = true;
    }
    try {
      const errors = await this.validateAllAsync(values);
      if (Object.keys(errors).length === 0 && handler !== undefined) {
        await handler(values);
      }
      return errors;
    } finally {
      this.submitting = false;
    }
  }

  /** 获取字段状态副本，调用方无法修改控制器内部状态。 */
  getFieldState(name: string): FormFieldState {
    const source = this.getMutableFieldState(name);
    const snapshot = new FormFieldState();
    snapshot.touched = source.touched;
    snapshot.dirty = source.dirty;
    snapshot.validating = source.validating;
    snapshot.error = source.error;
    return snapshot;
  }

  /** 获取整表状态副本。 */
  getState(): FormState {
    const snapshot = new FormState();
    snapshot.submitting = this.submitting;
    const keys = Object.keys(this.errors);
    for (const key of keys) {
      snapshot.errors[key] = this.errors[key];
    }
    return snapshot;
  }

  /** 重置错误、交互状态和待执行防抖任务，之后仍可继续使用。 */
  reset(): void {
    this.clearPending();
    this.errors = {};
    this.submitting = false;
    this.disposed = false;
    const keys = Object.keys(this.shape);
    for (const key of keys) {
      this.nextVersion(key);
      this.fieldStates.set(key, new FormFieldState());
    }
  }

  /** 页面销毁时清理定时器并使后续事件调用安全地忽略。 */
  dispose(): void {
    this.disposed = true;
    this.clearPending();
    const keys = Object.keys(this.shape);
    for (const key of keys) {
      this.nextVersion(key);
      this.getMutableFieldState(key).validating = false;
    }
    this.submitting = false;
  }

  private async runLatestValidation(name: string, value: Object | null | undefined,
    allValues: Record<string, Object> | undefined, version: number): Promise<string | null> {
    const state = this.getMutableFieldState(name);
    state.validating = true;
    try {
      const r = await this.shape[name].validateAsync(value, allValues);
      const message = r.valid ? null : r.errors[0].message;
      if (this.isLatest(name, version) && !this.disposed) {
        this.setError(name, message);
        return message;
      }
      return this.getMutableFieldState(name).error;
    } finally {
      if (this.isLatest(name, version)) {
        state.validating = false;
      }
    }
  }

  private validateDebounced(name: string, value: Object | null | undefined,
    allValues: Record<string, Object> | undefined, debounceMs: number): Promise<string | null> {
    this.cancelDebounce(name);
    const version = this.nextVersion(name);
    this.getMutableFieldState(name).validating = true;
    return new Promise<string | null>((resolve: DebounceResolver, reject: (reason: Error) => void): void => {
      this.debounceResolvers.set(name, resolve);
      const timer = setTimeout((): void => {
        this.timers.delete(name);
        this.debounceResolvers.delete(name);
        this.runLatestValidation(name, value, allValues, version).then((message: string | null): void => {
          resolve(message);
        }).catch((error: Error): void => {
          reject(error);
        });
      }, debounceMs);
      this.timers.set(name, timer);
    });
  }

  private async validateDependents(source: string, allValues?: Record<string, Object>): Promise<void> {
    if (allValues === undefined) {
      return;
    }
    const fields = this.dependents.get(source);
    if (fields === undefined) {
      return;
    }
    const tasks: Array<Promise<string | null>> = [];
    for (const field of fields) {
      tasks.push(this.validateFieldAsync(field, allValues[field], allValues));
    }
    await Promise.all(tasks);
  }

  private shouldValidate(name: string, trigger: string): boolean {
    const field = this.getFieldOptions(name);
    const triggers = field !== undefined && field.triggers !== undefined ? field.triggers : this.options.triggers;
    if (triggers === undefined) {
      return trigger === FormTrigger.CHANGE;
    }
    return triggers.indexOf(trigger) >= 0;
  }

  private getDebounceMs(name: string): number {
    const field = this.getFieldOptions(name);
    if (field !== undefined && field.debounceMs !== undefined) {
      return Math.max(0, field.debounceMs);
    }
    return Math.max(0, this.options.debounceMs === undefined ? 0 : this.options.debounceMs);
  }

  private getFieldOptions(name: string): FormFieldOptions | undefined {
    return this.options.fields === undefined ? undefined : this.options.fields[name];
  }

  private buildDependencyIndex(): void {
    if (this.options.fields === undefined) {
      return;
    }
    const fields = Object.keys(this.options.fields);
    for (const field of fields) {
      const config = this.options.fields[field];
      if (config.dependencies === undefined) {
        continue;
      }
      for (const source of config.dependencies) {
        const current = this.dependents.get(source);
        if (current === undefined) {
          this.dependents.set(source, [field]);
        } else if (current.indexOf(field) < 0) {
          current.push(field);
        }
      }
    }
  }

  private setError(name: string, message: string | null): void {
    const state = this.getMutableFieldState(name);
    state.error = message;
    if (message === null) {
      const nextErrors: Record<string, string> = {};
      const keys = Object.keys(this.errors);
      for (const key of keys) {
        if (key !== name) {
          nextErrors[key] = this.errors[key];
        }
      }
      this.errors = nextErrors;
    } else {
      this.errors[name] = message;
    }
  }

  private getMutableFieldState(name: string): FormFieldState {
    const current = this.fieldStates.get(name);
    if (current !== undefined) {
      return current;
    }
    const state = new FormFieldState();
    this.fieldStates.set(name, state);
    return state;
  }

  private nextVersion(name: string): number {
    const current = this.versions.get(name);
    const next = (current === undefined ? 0 : current) + 1;
    this.versions.set(name, next);
    return next;
  }

  private isLatest(name: string, version: number): boolean {
    return this.versions.get(name) === version;
  }

  private cancelDebounce(name: string): void {
    let cancelled = false;
    const timer = this.timers.get(name);
    if (timer !== undefined) {
      clearTimeout(timer);
      this.timers.delete(name);
      cancelled = true;
    }
    const resolver = this.debounceResolvers.get(name);
    if (resolver !== undefined) {
      this.debounceResolvers.delete(name);
      resolver(this.getMutableFieldState(name).error);
      cancelled = true;
    }
    if (cancelled) {
      this.getMutableFieldState(name).validating = false;
    }
  }

  private clearPending(): void {
    const fields = Array.from(this.timers.keys());
    for (const field of fields) {
      this.cancelDebounce(field);
    }
  }
}
