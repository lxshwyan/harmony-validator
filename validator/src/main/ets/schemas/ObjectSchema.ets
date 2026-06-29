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

  constructor(shape: SchemaShape) {
    this.shape = shape;
  }

  /**
   * 跨字段校验。`fn` 拿到整个对象，返回 false 时报错。
   * 例：确认密码 —— `.refine(o => o['pwd'] === o['confirm'], '两次密码不一致', 'confirm')`
   * @param path 错误归属的字段路径（默认空串，表示对象级错误）。
   */
  refine(fn: (obj: Record<string, Object>) => boolean, message: string, path?: string): ObjectSchema {
    this.refines.push({ fn, message, path: path ?? '' });
    return this;
  }

  private runRefines(data: Record<string, Object>, errors: ValidateError[]): void {
    for (const r of this.refines) {
      if (!r.fn(data)) {
        errors.push({ path: r.path, message: r.message });
      }
    }
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    if (value === null || value === undefined) {
      return { valid: false, errors: [{ path: '', message: '对象不能为空' }] };
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
      return { valid: false, errors: [{ path: '', message: '对象不能为空' }] };
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
