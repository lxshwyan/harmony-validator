import {
  AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateResult
} from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, parseSchema, parseSchemaAsync, TransformSchema } from './EffectSchemas';

/** 按对象中的判别字段直接选择候选，避免普通 union 逐项尝试。 */
export class DiscriminatedUnionSchema<T extends Object = Record<string, Object>> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private discriminator: string;
  private variants: Record<string, AnySchema<T>>;
  private customMessage?: string;
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  constructor(discriminator: string, variants: Record<string, AnySchema<T>>, message?: string) {
    this.discriminator = discriminator;
    this.variants = variants;
    this.customMessage = message;
  }
  meta(value: SchemaMetadata): DiscriminatedUnionSchema<T> { this.docs.meta(value); return this; }
  describe(description: string): DiscriminatedUnionSchema<T> { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    const result = this.docs.build('discriminated-union', true, false);
    result.discriminator = this.discriminator;
    const variants: Record<string, SchemaDescriptor> = {};
    for (const key of Object.keys(this.variants)) variants[key] = schemaToDescriptor(this.variants[key]);
    result.variants = variants;
    return result;
  }
  label(name: string): DiscriminatedUnionSchema<T> { this.fieldLabel = name; this.docs.label(name); return this; }
  nullable(): NullableSchema<T> { return new NullableSchema<T>(this); }
  default(value: T): DefaultSchema<T> { return new DefaultSchema<T>(this, value); }
  transform<U>(fn: (value: T) => U, message?: string): TransformSchema<T, U> {
    return new TransformSchema<T, U>(this, fn, message);
  }
  private select(value: Object | null | undefined): AnySchema<T> | undefined {
    if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value) || value instanceof Date) {
      return undefined;
    }
    const data = value as Record<string, Object>;
    const tag = data[this.discriminator];
    if (typeof tag !== 'string' && typeof tag !== 'number') return undefined;
    return this.variants[`${tag}`];
  }
  private failure(value: Object | null | undefined): ValidateResult {
    if (value !== null && value !== undefined &&
      (typeof value !== 'object' || Array.isArray(value) || value instanceof Date)) {
      return { valid: false, errors: [validationError(issue(ErrorCode.TYPE_OBJECT), this.fieldLabel)] };
    }
    return { valid: false, errors: [validationError(issue(ErrorCode.DISCRIMINATOR, this.customMessage,
      { 'field': this.discriminator }), this.fieldLabel, this.discriminator)] };
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const selected = this.select(value);
    return selected === undefined ? this.failure(value) : selected.validate(value, siblings);
  }
  async validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    const selected = this.select(value);
    return selected === undefined ? this.failure(value) : selected.validateAsync(value, siblings);
  }
  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T> {
    const selected = this.select(value);
    return selected === undefined ? { success: false, errors: this.failure(value).errors }
      : parseSchema<T>(selected, value, siblings);
  }
  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<T>> {
    const selected = this.select(value);
    return selected === undefined ? { success: false, errors: this.failure(value).errors }
      : parseSchemaAsync<T>(selected, value, siblings);
  }
}
