import { ParsableSchema, ParseResult, ValidateResult } from '../core/types';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, TransformSchema } from './EffectSchemas';
import { RequiredState } from '../core/required';

/** 精确值校验器，使用 === 比较。 */
export class LiteralSchema<T extends Object = Object> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private expected: T;
  private customMessage?: string;
  private fieldLabel: string = '';
  private req: RequiredState = new RequiredState();

  constructor(expected: T, message?: string) {
    this.expected = expected;
    this.customMessage = message;
  }

  label(name: string): LiteralSchema<T> {
    this.fieldLabel = name;
    return this;
  }

  required(message?: string): LiteralSchema<T> {
    this.req.markRequired(message);
    return this;
  }

  optional(): LiteralSchema<T> {
    this.req.markOptional();
    return this;
  }

  nullable(): NullableSchema<T> {
    return new NullableSchema<T>(this);
  }

  default(value: T): DefaultSchema<T> {
    return new DefaultSchema<T>(this, value);
  }

  transform<U>(fn: (value: T) => U, message?: string): TransformSchema<T, U> {
    return new TransformSchema<T, U>(this, fn, message);
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    if (value === null || value === undefined) {
      const required = this.req.error(siblings, this.fieldLabel);
      return required === null ? { valid: true, errors: [] } : { valid: false, errors: [required] };
    }
    if (value !== this.expected) {
      return {
        valid: false,
        errors: [validationError(issue(ErrorCode.LITERAL, this.customMessage,
          { 'expected': `${this.expected}` }), this.fieldLabel)],
      };
    }
    return { valid: true, errors: [] };
  }

  async validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    return this.validate(value, siblings);
  }

  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T> {
    const result = this.validate(value, siblings);
    return result.valid ? { success: true, value: value as T, errors: [] }
      : { success: false, errors: result.errors };
  }

  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<T>> {
    return this.parse(value, siblings);
  }
}
