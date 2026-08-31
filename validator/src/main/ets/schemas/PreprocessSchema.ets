import {
  AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateError, ValidateResult
} from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { ErrorCode, issue, ValidatorI18n, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, parseSchema, parseSchemaAsync, TransformSchema } from './EffectSchemas';

export type PreprocessFunction = (value: Object | null | undefined) => Object | null | undefined;

function withLabel(errors: ValidateError[], label: string): ValidateError[] {
  if (label === '') return errors;
  const result: ValidateError[] = [];
  const separator = ValidatorI18n.getLocale() === 'zh-CN' ? '：' : ': ';
  for (const error of errors) {
    result.push({ path: error.path, message: `${label}${separator}${error.message}`, code: error.code });
  }
  return result;
}

/** 在内部 Schema 校验前执行安全预处理；回调异常会转为结构化错误。 */
export class PreprocessSchema<T> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private fn: PreprocessFunction;
  private inner: AnySchema<T>;
  private customMessage?: string;
  private errorCode: string;
  private detail: string;
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  constructor(fn: PreprocessFunction, inner: AnySchema<T>, message?: string, errorCode?: string, detail?: string) {
    this.fn = fn;
    this.inner = inner;
    this.customMessage = message;
    this.errorCode = errorCode ?? ErrorCode.PREPROCESS;
    this.detail = detail ?? 'runtime-preprocess';
  }
  meta(value: SchemaMetadata): PreprocessSchema<T> { this.docs.meta(value); return this; }
  describe(description: string): PreprocessSchema<T> { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    const inner = schemaToDescriptor(this.inner);
    const result = this.docs.build('preprocess', inner.required, inner.conditionallyRequired);
    result.inner = inner;
    result.unrepresentable.push(this.detail);
    return result;
  }
  label(name: string): PreprocessSchema<T> { this.fieldLabel = name; this.docs.label(name); return this; }
  nullable(): NullableSchema<T> { return new NullableSchema<T>(this); }
  default(value: T): DefaultSchema<T> { return new DefaultSchema<T>(this, value); }
  transform<U>(fn: (value: T) => U, message?: string): TransformSchema<T, U> {
    return new TransformSchema<T, U>(this, fn, message);
  }
  private preprocess(value: Object | null | undefined): ParseResult<Object> {
    try {
      const output = this.fn(value);
      return { success: true, value: output as Object, errors: [] };
    } catch (_error) {
      return { success: false, errors: [validationError(issue(this.errorCode, this.customMessage), this.fieldLabel)] };
    }
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const result = this.parse(value, siblings);
    return { valid: result.success, errors: result.errors };
  }
  async validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    const result = await this.parseAsync(value, siblings);
    return { valid: result.success, errors: result.errors };
  }
  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T> {
    const prepared = this.preprocess(value);
    if (!prepared.success) return { success: false, errors: prepared.errors };
    const result = parseSchema<T>(this.inner, prepared.value, siblings);
    return { success: result.success, value: result.value, errors: withLabel(result.errors, this.fieldLabel) };
  }
  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<T>> {
    const prepared = this.preprocess(value);
    if (!prepared.success) return { success: false, errors: prepared.errors };
    const result = await parseSchemaAsync<T>(this.inner, prepared.value, siblings);
    return { success: result.success, value: result.value, errors: withLabel(result.errors, this.fieldLabel) };
  }
}
