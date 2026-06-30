import { AnySchema, ValidateError, ValidateResult } from '../core/types';

/** 对象形状：字段名 -> 对应字段的校验器。 */
export type SchemaShape = Record<string, AnySchema>;

/** 跨字段规则：拿到整个对象判断，返回 true 通过。 */
interface RefineRule {
  fn: (obj: Record<string, Object>) => boolean;
  message: string;
  path: string;
}

/** 对象校验器：按 shape 逐字段校验，并把错误路径拼成 "字段名" 或 "父.子"。 */
export class ObjectSchema implements AnySchema {
  private shape: SchemaShape;
  private refines: RefineRule[] = [];
  private isOptional: boolean = false;
  private emptyMsg: string = '对象不能为空';

  constructor(shape: SchemaShape) {
    this.shape = shape;
  }

  /** 显式可选：值为 null/undefined 时直接通过（用于可空的嵌套对象字段）。 */
  optional(): ObjectSchema {
    this.isOptional = true;
    return this;
  }

  /**
   * 跨字段校验。`fn` 拿到整个对象，返回 false 时报错。
   * 例：确认密码 —— `.refine(o => o['pwd'] === o['confirm'], '两次密码不一致', 'confirm')`
   * `fn` 内部应自行判空（字段可能缺失）；即便 `fn` 抛异常也会被捕获并按「未通过」处理，不会让整个校验崩溃。
   * @param path 错误归属的字段路径（默认空串，表示对象级错误）。
   */
  refine(fn: (obj: Record<string, Object>) => boolean, message: string, path?: string): ObjectSchema {
    this.refines.push({ fn, message, path: path ?? '' });
    return this;
  }

  private runRefines(data: Record<string, Object>, errors: ValidateError[]): void {
    for (const r of this.refines) {
      let passed = false;
      try {
        passed = r.fn(data);
      } catch (e) {
        // refine 体内解引用缺失字段等抛异常时，视为未通过而非让校验崩溃
        passed = false;
      }
      if (!passed) {
        errors.push({ path: r.path, message: r.message });
      }
    }
  }

  /** 空对象（null/undefined）的处理：可选则通过，否则报错。 */
  private emptyResult(): ValidateResult {
    if (this.isOptional) {
      return { valid: true, errors: [] };
    }
    return { valid: false, errors: [{ path: '', message: this.emptyMsg }] };
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    if (value === null || value === undefined) {
      return this.emptyResult();
    }
    const data = value as Record<string, Object>;
    const errors: ValidateError[] = [];
    const keys = Object.keys(this.shape);
    for (const key of keys) {
      const fieldSchema = this.shape[key];
      // 把当前对象作为 siblings 传下去，供字段的 requiredWhen 读取兄弟字段
      const result = fieldSchema.validate(data[key], data);
      if (!result.valid) {
        for (const e of result.errors) {
          const path = e.path === '' ? key : `${key}.${e.path}`;
          errors.push({ path: path, message: e.message });
        }
      }
    }
    this.runRefines(data, errors);
    return { valid: errors.length === 0, errors };
  }

  /** 异步逐字段校验：对每个字段调用其 validateAsync，路径拼接规则同 validate。 */
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    if (value === null || value === undefined) {
      return this.emptyResult();
    }
    const data = value as Record<string, Object>;
    const errors: ValidateError[] = [];
    const keys = Object.keys(this.shape);
    for (const key of keys) {
      const fieldSchema = this.shape[key];
      const result = await fieldSchema.validateAsync(data[key], data);
      if (!result.valid) {
        for (const e of result.errors) {
          const path = e.path === '' ? key : `${key}.${e.path}`;
          errors.push({ path: path, message: e.message });
        }
      }
    }
    this.runRefines(data, errors);
    return { valid: errors.length === 0, errors };
  }
}
