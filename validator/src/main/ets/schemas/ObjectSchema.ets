import { AnySchema, ValidateError, ValidateResult } from '../core/types';

/** 对象形状：字段名 -> 对应字段的校验器。 */
export type SchemaShape = Record<string, AnySchema>;

/** 对象校验器：按 shape 逐字段校验，并把错误路径拼成 "字段名" 或 "父.子"。 */
export class ObjectSchema implements AnySchema {
  private shape: SchemaShape;

  constructor(shape: SchemaShape) {
    this.shape = shape;
  }

  validate(value: Object | null | undefined): ValidateResult {
    if (value === null || value === undefined) {
      return { valid: false, errors: [{ path: '', message: '对象不能为空' }] };
    }
    const data = value as Record<string, Object>;
    const errors: ValidateError[] = [];
    const keys = Object.keys(this.shape);
    for (const key of keys) {
      const fieldSchema = this.shape[key];
      const fieldValue = data[key];
      const result = fieldSchema.validate(fieldValue);
      if (!result.valid) {
        for (const e of result.errors) {
          const path = e.path === '' ? key : `${key}.${e.path}`;
          errors.push({ path: path, message: e.message });
        }
      }
    }
    return { valid: errors.length === 0, errors };
  }
}
