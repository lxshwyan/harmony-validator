import { ParsableSchema, ParseResult, ValidateError, ValidateResult } from '../core/types';
import { RequiredState } from '../core/required';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, TransformSchema } from './EffectSchemas';

/** 布尔校验器。常用于「必须勾选同意协议」等场景。 */
export class BooleanSchema implements ParsableSchema<boolean> {
  readonly __schemaType: boolean | null = null;
  private req: RequiredState = new RequiredState();
  private mustBe: boolean | null = null;
  private mustBeMsg?: string;
  private fieldLabel: string = '';

  label(name: string): BooleanSchema {
    this.fieldLabel = name;
    return this;
  }

  nullable(): NullableSchema<boolean> {
    return new NullableSchema<boolean>(this);
  }

  default(value: boolean): DefaultSchema<boolean> {
    return new DefaultSchema<boolean>(this, value);
  }

  transform<U>(fn: (value: boolean) => U, message?: string): TransformSchema<boolean, U> {
    return new TransformSchema<boolean, U>(this, fn, message);
  }

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
    this.mustBeMsg = message;
    return this;
  }

  /** 必须为 false。 */
  isFalse(message?: string): BooleanSchema {
    this.mustBe = false;
    this.mustBeMsg = message;
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined) {
      const reqError = this.req.error(siblings, this.fieldLabel);
      if (reqError !== null) {
        errors.push(reqError);
      }
      return { valid: errors.length === 0, errors };
    }
    if (typeof value !== 'boolean') {
      return { valid: false, errors: [validationError(issue(ErrorCode.TYPE_BOOLEAN), this.fieldLabel)] };
    }
    if (this.mustBe !== null && (value as boolean) !== this.mustBe) {
      const code = this.mustBe ? ErrorCode.BOOLEAN_TRUE : ErrorCode.BOOLEAN_FALSE;
      errors.push(validationError(issue(code, this.mustBeMsg), this.fieldLabel));
    }
    return { valid: errors.length === 0, errors };
  }

  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    return this.validate(value, siblings);
  }

  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<boolean> {
    const result = this.validate(value, siblings);
    return result.valid ? { success: true, value: value as boolean, errors: [] }
      : { success: false, errors: result.errors };
  }

  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<boolean>> {
    return this.parse(value, siblings);
  }
}
