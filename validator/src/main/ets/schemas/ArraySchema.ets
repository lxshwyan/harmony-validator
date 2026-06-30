import { AnySchema, ValidateError, ValidateResult } from '../core/types';
import { RequiredState } from '../core/required';

/** 单条数组级规则（针对整个数组，如长度）：返回 null 通过，返回字符串为错误提示。 */
type ArrayRule = (value: Array<Object>) => string | null;

/**
 * 数组校验器。逐元素套用 element 校验器，错误路径以下标前缀：
 *   v.array(v.string().min(2)).validate(['a'])  // 错误 path = "0"
 *   v.object({ 'items': v.array(v.object({ 'name': v.string().required() })) })
 *   // 嵌套时 path = "items.0.name"
 */
export class ArraySchema implements AnySchema {
  private element: AnySchema;
  private rules: ArrayRule[] = [];
  private req: RequiredState = new RequiredState();

  constructor(element: AnySchema) {
    this.element = element;
  }

  /** 标记为必填。null/undefined 会报错（空数组视为已填，用 min/nonEmpty 约束长度）。 */
  required(message?: string): ArraySchema {
    this.req.markRequired(message);
    return this;
  }

  /** 显式可选。 */
  optional(): ArraySchema {
    this.req.markOptional();
    return this;
  }

  /** 条件必填：当同级字段满足 predicate 时本字段必填（仅 v.object 中生效）。 */
  requiredWhen(field: string, predicate: (other: Object | null | undefined) => boolean,
    message?: string): ArraySchema {
    this.req.addWhen(field, predicate, message);
    return this;
  }

  /** 最小元素个数。 */
  min(len: number, message?: string): ArraySchema {
    this.rules.push((value: Array<Object>): string | null =>
      value.length >= len ? null : (message ?? `至少需要 ${len} 项`));
    return this;
  }

  /** 最大元素个数。 */
  max(len: number, message?: string): ArraySchema {
    this.rules.push((value: Array<Object>): string | null =>
      value.length <= len ? null : (message ?? `最多 ${len} 项`));
    return this;
  }

  /** 不能为空数组。 */
  nonEmpty(message?: string): ArraySchema {
    this.rules.push((value: Array<Object>): string | null =>
      value.length > 0 ? null : (message ?? '至少需要 1 项'));
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined) {
      const reqMsg = this.req.message(siblings);
      if (reqMsg !== null) {
        errors.push({ path: '', message: reqMsg });
      }
      return { valid: errors.length === 0, errors };
    }
    if (!Array.isArray(value)) {
      return { valid: false, errors: [{ path: '', message: '类型错误，期望数组' }] };
    }
    const arr = value as Array<Object>;
    // 数组级规则（长度等）
    for (const rule of this.rules) {
      const msg = rule(arr);
      if (msg !== null) {
        errors.push({ path: '', message: msg });
      }
    }
    // 逐元素校验，路径加下标前缀
    for (let i = 0; i < arr.length; i++) {
      const result = this.element.validate(arr[i]);
      if (!result.valid) {
        for (const e of result.errors) {
          const path = e.path === '' ? `${i}` : `${i}.${e.path}`;
          errors.push({ path: path, message: e.message });
        }
      }
    }
    return { valid: errors.length === 0, errors };
  }

  /** 异步逐元素校验：对每个元素调用其 validateAsync，路径规则同 validate。 */
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined) {
      const reqMsg = this.req.message(siblings);
      if (reqMsg !== null) {
        errors.push({ path: '', message: reqMsg });
      }
      return { valid: errors.length === 0, errors };
    }
    if (!Array.isArray(value)) {
      return { valid: false, errors: [{ path: '', message: '类型错误，期望数组' }] };
    }
    const arr = value as Array<Object>;
    for (const rule of this.rules) {
      const msg = rule(arr);
      if (msg !== null) {
        errors.push({ path: '', message: msg });
      }
    }
    for (let i = 0; i < arr.length; i++) {
      const result = await this.element.validateAsync(arr[i]);
      if (!result.valid) {
        for (const e of result.errors) {
          const path = e.path === '' ? `${i}` : `${i}.${e.path}`;
          errors.push({ path: path, message: e.message });
        }
      }
    }
    return { valid: errors.length === 0, errors };
  }
}
