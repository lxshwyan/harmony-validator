import { ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateError, ValidateResult } from '../core/types';
import { SchemaDocs } from '../core/schema';
import { RequiredState } from '../core/required';
import { ErrorCode, issue, RuleIssue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, TransformSchema } from './EffectSchemas';

type NumberRule = (value: number) => RuleIssue | null;
type NumberAsyncRule = (value: number) => Promise<RuleIssue | null>;

/** 数字校验器，支持链式调用。 */
export class NumberSchema implements ParsableSchema<number> {
  readonly __schemaType: number | null = null;
  private rules: NumberRule[] = [];
  private asyncRules: NumberAsyncRule[] = [];
  private req: RequiredState = new RequiredState();
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  meta(value: SchemaMetadata): NumberSchema { this.docs.meta(value); return this; }
  describe(description: string): NumberSchema { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    return this.docs.build('number', this.req.requiredForDescription(),
      this.req.conditionallyRequiredForDescription());
  }

  label(name: string): NumberSchema {
    this.fieldLabel = name;
    this.docs.label(name);
    return this;
  }

  nullable(): NullableSchema<number> {
    return new NullableSchema<number>(this);
  }

  default(value: number): DefaultSchema<number> {
    return new DefaultSchema<number>(this, value);
  }

  transform<U>(fn: (value: number) => U, message?: string): TransformSchema<number, U> {
    return new TransformSchema<number, U>(this, fn, message);
  }

  required(message?: string): NumberSchema {
    this.req.markRequired(message);
    return this;
  }

  /** 显式标记为可选（默认即可选）。 */
  optional(): NumberSchema {
    this.req.markOptional();
    return this;
  }

  /** 条件必填：当同级字段 `field` 满足 `predicate` 时本字段必填（仅 v.object 中生效）。 */
  requiredWhen(field: string, predicate: (other: Object | null | undefined) => boolean,
    message?: string): NumberSchema {
    this.req.addWhen(field, predicate, message);
    return this;
  }

  /** 最小值（含）。 */
  min(value: number, message?: string): NumberSchema {
    this.docs.rule('minimum', value);
    this.rules.push((v: number): RuleIssue | null =>
      v >= value ? null : issue(ErrorCode.NUMBER_MIN, message, { 'min': `${value}` }));
    return this;
  }

  /** 最大值（含）。 */
  max(value: number, message?: string): NumberSchema {
    this.docs.rule('maximum', value);
    this.rules.push((v: number): RuleIssue | null =>
      v <= value ? null : issue(ErrorCode.NUMBER_MAX, message, { 'max': `${value}` }));
    return this;
  }

  /** 必须为整数。 */
  integer(message?: string): NumberSchema {
    this.docs.rule('integer');
    this.rules.push((v: number): RuleIssue | null =>
      Number.isInteger(v) ? null : issue(ErrorCode.INTEGER, message));
    return this;
  }

  /** 必须为正数。 */
  positive(message?: string): NumberSchema {
    this.docs.rule('exclusiveMinimum', 0);
    this.rules.push((v: number): RuleIssue | null =>
      v > 0 ? null : issue(ErrorCode.POSITIVE, message));
    return this;
  }

  custom(fn: (value: number) => boolean, message: string): NumberSchema {
    this.docs.rule('custom', undefined, 'synchronous predicate', false, false);
    this.rules.push((v: number): RuleIssue | null => {
      try {
        return fn(v) ? null : issue(ErrorCode.CUSTOM, message);
      } catch (e) {
        return issue(ErrorCode.CUSTOM, message);
      }
    });
    return this;
  }

  /** 自定义异步规则。返回 Promise<true> 通过。仅 validateAsync 时生效。 */
  customAsync(fn: (value: number) => Promise<boolean>, message: string): NumberSchema {
    this.docs.rule('custom', undefined, 'asynchronous predicate', true, false);
    this.asyncRules.push(async (v: number): Promise<RuleIssue | null> => {
      try {
        return (await fn(v)) ? null : issue(ErrorCode.CUSTOM, message);
      } catch (e) {
        return issue(ErrorCode.CUSTOM, message);
      }
    });
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    // 空串也视为「空值」(ArkUI 表单未填的数字输入常是 '')，与字符串保持一致
    if (value === null || value === undefined || value === '') {
      const reqError = this.req.error(siblings, this.fieldLabel);
      if (reqError !== null) {
        errors.push(reqError);
      }
      return { valid: errors.length === 0, errors };
    }
    if (typeof value !== 'number') {
      return { valid: false, errors: [validationError(issue(ErrorCode.TYPE_NUMBER), this.fieldLabel)] };
    }
    const num = value as number;
    if (!Number.isFinite(num)) {
      return { valid: false, errors: [validationError(issue(ErrorCode.INVALID_NUMBER), this.fieldLabel)] };
    }
    for (const rule of this.rules) {
      const currentIssue = rule(num);
      if (currentIssue !== null) {
        errors.push(validationError(currentIssue, this.fieldLabel));
      }
    }
    return { valid: errors.length === 0, errors };
  }

  /** 异步校验：先跑同步规则，再跑异步规则。 */
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    const base = this.validate(value, siblings);
    // 同步规则未通过则短路
    if (!base.valid) {
      return base;
    }
    const errors: ValidateError[] = base.errors.slice();
    if (value !== null && value !== undefined && typeof value === 'number'
      && Number.isFinite(value as number) && this.asyncRules.length > 0) {
      const num = value as number;
      for (const rule of this.asyncRules) {
        const currentIssue = await rule(num);
        if (currentIssue !== null) {
          errors.push(validationError(currentIssue, this.fieldLabel));
        }
      }
    }
    return { valid: errors.length === 0, errors };
  }

  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<number> {
    const result = this.validate(value, siblings);
    return result.valid ? { success: true, value: value as number, errors: [] }
      : { success: false, errors: result.errors };
  }

  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<number>> {
    const result = await this.validateAsync(value, siblings);
    return result.valid ? { success: true, value: value as number, errors: [] }
      : { success: false, errors: result.errors };
  }
}
