import { AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateResult } from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { ConfigurableSchema, ValidationOptions } from '../core/errors';
import { DefaultSchema, NullableSchema, parseSchema, parseSchemaAsync, TransformSchema } from './EffectSchemas';

export type ContextPredicate<T> = (value: T, context: Record<string, Object>) => boolean;

/** 在基础 Schema 通过后，使用调用方上下文执行可定制业务规则。 */
export class ContextSchema<T> implements ParsableSchema<T>, ConfigurableSchema<T> {
  readonly __schemaType: T | null = null;
  private inner: AnySchema<T>;
  private predicate: ContextPredicate<T>;
  private customMessage?: string;
  private docs: SchemaDocs = new SchemaDocs();

  constructor(inner: AnySchema<T>, predicate: ContextPredicate<T>, message?: string) {
    this.inner = inner; this.predicate = predicate; this.customMessage = message;
  }
  meta(value: SchemaMetadata): ContextSchema<T> { this.docs.meta(value); return this; }
  describe(value: string): ContextSchema<T> { this.docs.describe(value); return this; }
  label(value: string): ContextSchema<T> { this.docs.label(value); return this; }
  nullable(): NullableSchema<T> { return new NullableSchema<T>(this); }
  default(value: T): DefaultSchema<T> { return new DefaultSchema<T>(this, value); }
  transform<U>(fn: (value: T) => U, message?: string): TransformSchema<T, U> {
    return new TransformSchema<T, U>(this, fn, message);
  }
  describeSchema(): SchemaDescriptor {
    const inner = schemaToDescriptor(this.inner);
    const result = this.docs.build('context', inner.required, inner.conditionallyRequired);
    result.inner = inner;
    result.unrepresentable.push('runtime-context-predicate');
    return result;
  }
  private withContext(result: ParseResult<T>, context?: Record<string, Object>): ParseResult<T> {
    if (!result.success || result.value === undefined) return result;
    let passed = false;
    try { passed = this.predicate(result.value, context ?? {}); } catch (_error) { passed = false; }
    return passed ? result : { success: false,
      errors: [validationError(issue(ErrorCode.CONTEXT, this.customMessage))] };
  }
  validateWithOptions(value: Object | null | undefined, options?: ValidationOptions): ValidateResult {
    const parsed = this.withContext(parseSchema<T>(this.inner, value), options?.context);
    return { valid: parsed.success, errors: parsed.errors };
  }
  async validateAsyncWithOptions(value: Object | null | undefined,
    options?: ValidationOptions): Promise<ValidateResult> {
    const parsed = this.withContext(await parseSchemaAsync<T>(this.inner, value), options?.context);
    return { valid: parsed.success, errors: parsed.errors };
  }
  validate(value: Object | null | undefined): ValidateResult { return this.validateWithOptions(value); }
  validateAsync(value: Object | null | undefined): Promise<ValidateResult> {
    return this.validateAsyncWithOptions(value);
  }
  parse(value: Object | null | undefined): ParseResult<T> {
    return this.withContext(parseSchema<T>(this.inner, value));
  }
  async parseAsync(value: Object | null | undefined): Promise<ParseResult<T>> {
    return this.withContext(await parseSchemaAsync<T>(this.inner, value));
  }
  parseWithContext(value: Object | null | undefined, context: Record<string, Object>): ParseResult<T> {
    return this.withContext(parseSchema<T>(this.inner, value), context);
  }
  async parseAsyncWithContext(value: Object | null | undefined,
    context: Record<string, Object>): Promise<ParseResult<T>> {
    return this.withContext(await parseSchemaAsync<T>(this.inner, value), context);
  }
}
