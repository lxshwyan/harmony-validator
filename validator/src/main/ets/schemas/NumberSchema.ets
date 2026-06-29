import { AnySchema, ValidateError, ValidateResult } from '../core/types';

type NumberRule = (value: number) => string | null;
type NumberAsyncRule = (value: number) => Promise<string | null>;

/** 数字校验器，支持链式调用。 */
export class NumberSchema implements AnySchema {
  private rules: NumberRule[] = [];
  private asyncRules: NumberAsyncRule[] = [];
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

  /** 自定义异步规则。返回 Promise<true> 通过。仅 validateAsync 时生效。 */
  customAsync(fn: (value: number) => Promise<boolean>, message: string): NumberSchema {
    this.asyncRules.push(async (v: number): Promise<string | null> =>
      (await fn(v)) ? null : message);
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

  /** 异步校验：先跑同步规则，再跑异步规则。 */
  async validateAsync(value: Object | null | undefined): Promise<ValidateResult> {
    const base = this.validate(value);
    const errors: ValidateError[] = base.errors.slice();
    if (value !== null && value !== undefined && typeof value === 'number'
      && !Number.isNaN(value as number) && this.asyncRules.length > 0) {
      const num = value as number;
      for (const rule of this.asyncRules) {
        const msg = await rule(num);
        if (msg !== null) {
          errors.push({ path: '', message: msg });
        }
      }
    }
    return { valid: errors.length === 0, errors };
  }
}
