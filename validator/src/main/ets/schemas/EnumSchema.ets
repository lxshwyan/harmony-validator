import { ParsableSchema, ParseResult, ValidateError, ValidateResult } from '../core/types';
import { RequiredState } from '../core/required';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, TransformSchema } from './EffectSchemas';

/**
 * 枚举校验器：值必须是给定集合中的一个（用 === 比较）。
 * 适用于字符串/数字枚举，如 `v.enumOf(['male', 'female'])`、`v.enumOf([1, 2, 3])`。
 */
export class EnumSchema<T extends Object = Object> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private values: Array<T>;
  private req: RequiredState = new RequiredState();
  private customMessage?: string;
  private fieldLabel: string = '';

  constructor(values: Array<T>, message?: string) {
    this.values = values;
    this.customMessage = message;
  }

  label(name: string): EnumSchema<T> {
    this.fieldLabel = name;
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

  /** 必填。 */
  required(message?: string): EnumSchema<T> {
    this.req.markRequired(message);
    return this;
  }

  /** 显式可选。 */
  optional(): EnumSchema<T> {
    this.req.markOptional();
    return this;
  }

  /** 条件必填：当同级字段满足 predicate 时本字段必填（仅 v.object 中生效）。 */
  requiredWhen(field: string, predicate: (other: Object | null | undefined) => boolean,
    message?: string): EnumSchema<T> {
    this.req.addWhen(field, predicate, message);
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    // null/undefined 一定是空值；'' 仅当它不是合法枚举值时才当空值
    // （这样 '' 本身是合法选项时按成员校验通过，否则 required 能正常报「必填」）
    const objectValues = this.values as Array<Object>;
    const isEmpty = value === null || value === undefined
      || (value === '' && objectValues.indexOf('') === -1);
    if (isEmpty) {
      const reqError = this.req.error(siblings, this.fieldLabel);
      if (reqError !== null) {
        errors.push(reqError);
      }
      return { valid: errors.length === 0, errors };
    }
    if (objectValues.indexOf(value) === -1) {
      errors.push(validationError(issue(ErrorCode.ENUM, this.customMessage,
        { 'values': this.values.join(' / ') }), this.fieldLabel));
    }
    return { valid: errors.length === 0, errors };
  }

  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
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
