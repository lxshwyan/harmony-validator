import { ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateResult } from '../core/types';
import { SchemaDocs } from '../core/schema';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, TransformSchema } from './EffectSchemas';

/** 接受任意 ArkTS 值；undefined 仍按“未提供的可选值”处理。 */
export class AnyValueSchema implements ParsableSchema<Object | null> {
  readonly __schemaType: Object | null = null;
  protected docs: SchemaDocs = new SchemaDocs();

  meta(value: SchemaMetadata): AnyValueSchema { this.docs.meta(value); return this; }
  describe(value: string): AnyValueSchema { this.docs.describe(value); return this; }
  describeSchema(): SchemaDescriptor { return this.docs.build('any'); }
  label(value: string): AnyValueSchema { this.docs.label(value); return this; }
  nullable(): NullableSchema<Object | null> { return new NullableSchema<Object | null>(this); }
  default(value: Object | null): DefaultSchema<Object | null> {
    return new DefaultSchema<Object | null>(this, value);
  }
  transform<U>(fn: (value: Object | null) => U, message?: string): TransformSchema<Object | null, U> {
    return new TransformSchema<Object | null, U>(this, fn, message);
  }
  validate(_value: Object | null | undefined): ValidateResult { return { valid: true, errors: [] }; }
  validateAsync(value: Object | null | undefined): Promise<ValidateResult> {
    return Promise.resolve(this.validate(value));
  }
  parse(value: Object | null | undefined): ParseResult<Object | null> {
    return value === undefined ? { success: true, errors: [] } : { success: true, value, errors: [] };
  }
  parseAsync(value: Object | null | undefined): Promise<ParseResult<Object | null>> {
    return Promise.resolve(this.parse(value));
  }
}

/** 与 any 的运行时行为相同，但表达“消费方仍需缩小类型”的意图。 */
export class UnknownSchema extends AnyValueSchema {
  describeSchema(): SchemaDescriptor {
    const result = super.describeSchema();
    result.kind = 'unknown';
    return result;
  }
}

/** 永不接受任何值，适合穷尽分支和显式禁止字段。 */
export class NeverSchema implements ParsableSchema<Object> {
  readonly __schemaType: Object | null = null;
  private customMessage?: string;
  private docs: SchemaDocs = new SchemaDocs();

  constructor(message?: string) { this.customMessage = message; }
  meta(value: SchemaMetadata): NeverSchema { this.docs.meta(value); return this; }
  describe(value: string): NeverSchema { this.docs.describe(value); return this; }
  describeSchema(): SchemaDescriptor { return this.docs.build('never', true); }
  label(value: string): NeverSchema { this.docs.label(value); return this; }
  private result(): ValidateResult {
    return { valid: false, errors: [validationError(issue(ErrorCode.NEVER, this.customMessage))] };
  }
  validate(_value: Object | null | undefined): ValidateResult { return this.result(); }
  validateAsync(_value: Object | null | undefined): Promise<ValidateResult> { return Promise.resolve(this.result()); }
  parse(_value: Object | null | undefined): ParseResult<Object> {
    return { success: false, errors: this.result().errors };
  }
  parseAsync(_value: Object | null | undefined): Promise<ParseResult<Object>> {
    const result: ParseResult<Object> = { success: false, errors: this.result().errors };
    return Promise.resolve(result);
  }
}

/** 只接受 null；与 `.nullable()` 的“额外接受 null”语义不同。 */
export class NullSchema implements ParsableSchema<null> {
  readonly __schemaType: null = null;
  private customMessage?: string;
  private docs: SchemaDocs = new SchemaDocs();

  constructor(message?: string) { this.customMessage = message; }
  meta(value: SchemaMetadata): NullSchema { this.docs.meta(value); return this; }
  describe(value: string): NullSchema { this.docs.describe(value); return this; }
  describeSchema(): SchemaDescriptor { return this.docs.build('null', true); }
  label(value: string): NullSchema { this.docs.label(value); return this; }
  default(value: null): DefaultSchema<null> { return new DefaultSchema<null>(this, value); }
  transform<U>(fn: (value: null) => U, message?: string): TransformSchema<null, U> {
    return new TransformSchema<null, U>(this, fn, message);
  }
  private result(value: Object | null | undefined): ValidateResult {
    if (value === null) return { valid: true, errors: [] };
    return { valid: false, errors: [validationError(issue(ErrorCode.TYPE_NULL, this.customMessage))] };
  }
  validate(value: Object | null | undefined): ValidateResult { return this.result(value); }
  validateAsync(value: Object | null | undefined): Promise<ValidateResult> {
    return Promise.resolve(this.result(value));
  }
  parse(value: Object | null | undefined): ParseResult<null> {
    const result = this.result(value);
    return result.valid ? { success: true, value: null, errors: [] } : { success: false, errors: result.errors };
  }
  parseAsync(value: Object | null | undefined): Promise<ParseResult<null>> {
    return Promise.resolve(this.parse(value));
  }
}
