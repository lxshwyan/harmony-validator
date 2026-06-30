import { AnySchema, ValidateError, ValidateResult } from '../core/types';
import { RequiredState } from '../core/required';

/** 布尔校验器。常用于「必须勾选同意协议」等场景。 */
export class BooleanSchema implements AnySchema {
  private req: RequiredState = new RequiredState();
  private mustBe: boolean | null = null;
  private mustBeMsg: string = '';

  /** 必填（null/undefined 报错；注意 false 不算空值）。 */
  required(message?: string): BooleanSchema {
    this.req.markRequired(message);
    return this;
  }

  /** 显式可选。 */
  optional(): BooleanSchema {
    this.req.markOptional();
    return this;
  }

  /** 条件必填：当同级字段满足 predicate 时本字段必填（仅 v.object 中生效）。 */
  requiredWhen(field: string, predicate: (other: Object | null | undefined) => boolean,
    message?: string): BooleanSchema {
    this.req.addWhen(field, predicate, message);
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
      const reqMsg = this.req.message(siblings);
      if (reqMsg !== null) {
        errors.push({ path: '', message: reqMsg });
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
