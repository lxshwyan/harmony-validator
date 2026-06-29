import { AnySchema, ValidateError, ValidateResult } from '../core/types';

/** 布尔校验器。常用于「必须勾选同意协议」等场景。 */
export class BooleanSchema implements AnySchema {
  private isRequired: boolean = false;
  private requiredMsg: string = '该字段为必填项';
  private mustBe: boolean | null = null;
  private mustBeMsg: string = '';

  /** 必填（null/undefined 报错）。 */
  required(message?: string): BooleanSchema {
    this.isRequired = true;
    if (message !== undefined) {
      this.requiredMsg = message;
    }
    return this;
  }

  /** 必须为 true（如同意协议）。 */
  isTrue(message?: string): BooleanSchema {
    this.mustBe = true;
    this.mustBeMsg = message ?? '必须为是';
    return this;
  }

  /** 必须为 false。 */
  isFalse(message?: string): BooleanSchema {
    this.mustBe = false;
    this.mustBeMsg = message ?? '必须为否';
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined) {
      if (this.isRequired) {
        errors.push({ path: '', message: this.requiredMsg });
      }
      return { valid: errors.length === 0, errors };
    }
    if (typeof value !== 'boolean') {
      return { valid: false, errors: [{ path: '', message: '类型错误，期望布尔值' }] };
    }
    if (this.mustBe !== null && (value as boolean) !== this.mustBe) {
      errors.push({ path: '', message: this.mustBeMsg });
    }
    return { valid: errors.length === 0, errors };
  }

  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    return this.validate(value, siblings);
  }
}
