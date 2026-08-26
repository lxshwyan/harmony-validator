import {
  AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateError, ValidateResult
} from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { ErrorCode, issue, ValidatorI18n, validationError } from '../core/i18n';

/** 对任意 Schema 执行解析；第三方旧 Schema 没有 parse 时回退为“校验后返回原值”。 */
export function parseSchema<T>(schema: AnySchema<T>, value: Object | null | undefined,
  siblings?: Record<string, Object>): ParseResult<T> {
  if (schema.parse !== undefined) {
    return schema.parse(value, siblings);
  }
  const result = schema.validate(value, siblings);
  if (!result.valid) {
    return { success: false, errors: result.errors };
  }
  return { success: true, value: value as T, errors: [] };
}

export async function parseSchemaAsync<T>(schema: AnySchema<T>, value: Object | null | undefined,
  siblings?: Record<string, Object>): Promise<ParseResult<T>> {
  if (schema.parseAsync !== undefined) {
    return schema.parseAsync(value, siblings);
  }
  const result = await schema.validateAsync(value, siblings);
  if (!result.valid) {
    return { success: false, errors: result.errors };
  }
  return { success: true, value: value as T, errors: [] };
}

function withLabel(errors: ValidateError[], label: string): ValidateError[] {
  if (label === '') {
    return errors;
  }
  const result: ValidateError[] = [];
  const separator = ValidatorI18n.getLocale() === 'zh-CN' ? '：' : ': ';
  for (const error of errors) {
    result.push({ path: error.path, message: `${label}${separator}${error.message}`, code: error.code });
  }
  return result;
}

/** 允许显式 null；undefined 仍交由原 Schema 判断。 */
export class NullableSchema<T> implements ParsableSchema<T | null> {
  readonly __schemaType: T | null = null;
  private inner: AnySchema<T>;
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  constructor(inner: AnySchema<T>) {
    this.inner = inner;
  }

  meta(value: SchemaMetadata): NullableSchema<T> { this.docs.meta(value); return this; }
  describe(description: string): NullableSchema<T> { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    const inner = schemaToDescriptor(this.inner);
    const result = this.docs.build('nullable', inner.required, inner.conditionallyRequired);
    result.inner = inner;
    return result;
  }

  label(name: string): NullableSchema<T> {
    this.fieldLabel = name;
    this.docs.label(name);
    return this;
  }

  nullable(): NullableSchema<T> {
    return this;
  }

  default(value: T): DefaultSchema<T | null> {
    return new DefaultSchema<T | null>(this, value);
  }

  transform<U>(fn: (value: T | null) => U, message?: string): TransformSchema<T | null, U> {
    return new TransformSchema<T | null, U>(this, fn, message);
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    if (value === null) {
      return { valid: true, errors: [] };
    }
    const result = this.inner.validate(value, siblings);
    return { valid: result.valid, errors: withLabel(result.errors, this.fieldLabel) };
  }

  async validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    if (value === null) {
      return { valid: true, errors: [] };
    }
    const result = await this.inner.validateAsync(value, siblings);
    return { valid: result.valid, errors: withLabel(result.errors, this.fieldLabel) };
  }

  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T | null> {
    if (value === null) {
      return { success: true, value: null, errors: [] };
    }
    const result = parseSchema<T>(this.inner, value, siblings);
    return { success: result.success, value: result.value, errors: withLabel(result.errors, this.fieldLabel) };
  }

  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<T | null>> {
    if (value === null) {
      return { success: true, value: null, errors: [] };
    }
    const result = await parseSchemaAsync<T>(this.inner, value, siblings);
    return { success: result.success, value: result.value, errors: withLabel(result.errors, this.fieldLabel) };
  }
}

/** 仅在输入为 undefined 时使用默认值；显式 null 不会被替换。 */
export class DefaultSchema<T> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private inner: AnySchema<T>;
  private fallback: T;
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  constructor(inner: AnySchema<T>, fallback: T) {
    this.inner = inner;
    this.fallback = fallback;
  }

  meta(value: SchemaMetadata): DefaultSchema<T> { this.docs.meta(value); return this; }
  describe(description: string): DefaultSchema<T> { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    const result = this.docs.build('default', false, false);
    result.inner = schemaToDescriptor(this.inner);
    result.defaultValue = this.fallback as Object;
    return result;
  }

  label(name: string): DefaultSchema<T> {
    this.fieldLabel = name;
    this.docs.label(name);
    return this;
  }

  nullable(): NullableSchema<T> {
    return new NullableSchema<T>(this);
  }

  default(value: T): DefaultSchema<T> {
    this.fallback = value;
    return this;
  }

  transform<U>(fn: (value: T) => U, message?: string): TransformSchema<T, U> {
    return new TransformSchema<T, U>(this, fn, message);
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    if (value === undefined) {
      return { valid: true, errors: [] };
    }
    const result = this.inner.validate(value, siblings);
    return { valid: result.valid, errors: withLabel(result.errors, this.fieldLabel) };
  }

  async validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    if (value === undefined) {
      return { valid: true, errors: [] };
    }
    const result = await this.inner.validateAsync(value, siblings);
    return { valid: result.valid, errors: withLabel(result.errors, this.fieldLabel) };
  }

  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T> {
    if (value === undefined) {
      return { success: true, value: this.fallback, errors: [] };
    }
    const result = parseSchema<T>(this.inner, value, siblings);
    return { success: result.success, value: result.value, errors: withLabel(result.errors, this.fieldLabel) };
  }

  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<T>> {
    if (value === undefined) {
      return { success: true, value: this.fallback, errors: [] };
    }
    const result = await parseSchemaAsync<T>(this.inner, value, siblings);
    return { success: result.success, value: result.value, errors: withLabel(result.errors, this.fieldLabel) };
  }
}

/** 先校验/解析输入，再将值转换为 U；转换异常返回 transform 错误。 */
export class TransformSchema<T, U> implements ParsableSchema<U> {
  readonly __schemaType: U | null = null;
  private inner: AnySchema<T>;
  private fn: (value: T) => U;
  private customMessage?: string;
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  constructor(inner: AnySchema<T>, fn: (value: T) => U, message?: string) {
    this.inner = inner;
    this.fn = fn;
    this.customMessage = message;
  }

  meta(value: SchemaMetadata): TransformSchema<T, U> { this.docs.meta(value); return this; }
  describe(description: string): TransformSchema<T, U> { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    const inner = schemaToDescriptor(this.inner);
    const result = this.docs.build('transform', inner.required, inner.conditionallyRequired);
    result.inner = inner;
    result.unrepresentable.push('runtime-transform');
    return result;
  }

  label(name: string): TransformSchema<T, U> {
    this.fieldLabel = name;
    this.docs.label(name);
    return this;
  }

  nullable(): NullableSchema<U> {
    return new NullableSchema<U>(this);
  }

  default(value: U): DefaultSchema<U> {
    return new DefaultSchema<U>(this, value);
  }

  transform<V>(fn: (value: U) => V, message?: string): TransformSchema<U, V> {
    return new TransformSchema<U, V>(this, fn, message);
  }

  private transformResult(input: ParseResult<T>): ParseResult<U> {
    if (!input.success) {
      return { success: false, errors: withLabel(input.errors, this.fieldLabel) };
    }
    // 基础 Schema 默认允许缺失值；缺失时保持 undefined，不把它伪装成 T 传给转换函数。
    if (input.value === undefined) {
      return { success: true, errors: [] };
    }
    try {
      return { success: true, value: this.fn(input.value as T), errors: [] };
    } catch (e) {
      return {
        success: false,
        errors: [validationError(issue(ErrorCode.TRANSFORM, this.customMessage), this.fieldLabel)],
      };
    }
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const parsed = this.parse(value, siblings);
    return { valid: parsed.success, errors: parsed.errors };
  }

  async validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    const parsed = await this.parseAsync(value, siblings);
    return { valid: parsed.success, errors: parsed.errors };
  }

  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<U> {
    return this.transformResult(parseSchema<T>(this.inner, value, siblings));
  }

  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<U>> {
    return this.transformResult(await parseSchemaAsync<T>(this.inner, value, siblings));
  }
}
