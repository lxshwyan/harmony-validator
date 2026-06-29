import { AnySchema, ValidateError, ValidateResult } from '../core/types';

/**
 * 枚举校验器：值必须是给定集合中的一个（用 === 比较）。
 * 适用于字符串/数字枚举，如 `v.enumOf(['male', 'female'])`、`v.enumOf([1, 2, 3])`。
 */
export class EnumSchema implements AnySchema {
  private values: Array<Object>;
  private isRequired: boolean = false;
  private requiredMsg: string = '该字段为必填项';
  private message: string;

  constructor(values: Array<Object>, message?: string) {
    this.values = values;
    this.message = message ?? `取值必须是：${values.join(' / ')}`;
  }

  /** 必填。 */
  required(message?: string): EnumSchema {
    this.isRequired = true;
    if (message !== undefined) {
      this.requiredMsg = message;
    }
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined || value === '') {
      if (this.isRequired) {
        errors.push({ path: '', message: this.requiredMsg });
      }
      return { valid: errors.length === 0, errors };
    }
    if (this.values.indexOf(value) === -1) {
      errors.push({ path: '', message: this.message });
    }
    return { valid: errors.length === 0, errors };
  }

  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    return this.validate(value, siblings);
  }
}
