import { AnySchema, ValidateError, ValidateResult } from '../core/types';

type NumberRule = (value: number) => string | null;

/** 数字校验器，支持链式调用。 */
export class NumberSchema implements AnySchema {
  private rules: NumberRule[] = [];
  private isRequired: boolean = false;
  private requiredMsg: string = '该字段为必填项';

  required(message?: string): NumberSchema {
    this.isRequired = true;
    if (message !== undefined) {
      this.requiredMsg = message;
    }
    return this;
  }

  /** 最小值（含）。 */
  min(value: number, message?: string): NumberSchema {
    this.rules.push((v: number): string | null =>
      v >= value ? null : (message ?? `不能小于 ${value}`));
    return this;
  }

  /** 最大值（含）。 */
  max(value: number, message?: string): NumberSchema {
    this.rules.push((v: number): string | null =>
      v <= value ? null : (message ?? `不能大于 ${value}`));
    return this;
  }

  /** 必须为整数。 */
  integer(message?: string): NumberSchema {
    this.rules.push((v: number): string | null =>
      Number.isInteger(v) ? null : (message ?? '必须为整数'));
    return this;
  }

  /** 必须为正数。 */
  positive(message?: string): NumberSchema {
    this.rules.push((v: number): string | null =>
      v > 0 ? null : (message ?? '必须为正数'));
    return this;
  }

  custom(fn: (value: number) => boolean, message: string): NumberSchema {
    this.rules.push((v: number): string | null => fn(v) ? null : message);
    return this;
  }

  validate(value: Object | null | undefined): ValidateResult {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined) {
      if (this.isRequired) {
        errors.push({ path: '', message: this.requiredMsg });
      }
      return { valid: errors.length === 0, errors };
    }
    if (typeof value !== 'number') {
      return { valid: false, errors: [{ path: '', message: '类型错误，期望数字' }] };
    }
    const num = value as number;
    if (Number.isNaN(num)) {
      return { valid: false, errors: [{ path: '', message: '不是有效的数字' }] };
    }
    for (const rule of this.rules) {
      const msg = rule(num);
      if (msg !== null) {
        errors.push({ path: '', message: msg });
      }
    }
    return { valid: errors.length === 0, errors };
  }
}
