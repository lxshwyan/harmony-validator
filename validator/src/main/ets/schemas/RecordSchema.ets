import {
  AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateError, ValidateResult
} from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, parseSchema, parseSchemaAsync, TransformSchema } from './EffectSchemas';

/** 字符串键对象校验器：所有自有属性都使用同一个 value Schema。 */
export class RecordSchema<T extends Object = Object> implements ParsableSchema<Record<string, T>> {
  readonly __schemaType: Record<string, T> | null = null;
  private valueSchema: AnySchema<T>;
  private isOptional: boolean = false;
  private customMessage?: string;
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  constructor(valueSchema: AnySchema<T>, message?: string) {
    this.valueSchema = valueSchema;
    this.customMessage = message;
  }

  meta(value: SchemaMetadata): RecordSchema<T> { this.docs.meta(value); return this; }
  describe(description: string): RecordSchema<T> { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    const result = this.docs.build('record', !this.isOptional, false);
    result.items = schemaToDescriptor(this.valueSchema);
    return result;
  }

  label(name: string): RecordSchema<T> { this.fieldLabel = name; this.docs.label(name); return this; }
  optional(): RecordSchema<T> { this.isOptional = true; return this; }
  required(message?: string): RecordSchema<T> {
    this.isOptional = false;
    this.customMessage = message;
    return this;
  }
  nullable(): NullableSchema<Record<string, T>> { return new NullableSchema<Record<string, T>>(this); }
  default(value: Record<string, T>): DefaultSchema<Record<string, T>> {
    return new DefaultSchema<Record<string, T>>(this, value);
  }
  transform<U>(fn: (value: Record<string, T>) => U, message?: string): TransformSchema<Record<string, T>, U> {
    return new TransformSchema<Record<string, T>, U>(this, fn, message);
  }

  private emptyResult(): ValidateResult {
    if (this.isOptional) {
      return { valid: true, errors: [] };
    }
    return { valid: false, errors: [validationError(issue(ErrorCode.OBJECT_REQUIRED,
      this.customMessage), this.fieldLabel)] };
  }

  private typeError(): ValidateResult {
    return { valid: false, errors: [validationError(issue(ErrorCode.TYPE_OBJECT), this.fieldLabel)] };
  }

  validate(value: Object | null | undefined): ValidateResult {
    if (value === null || value === undefined) return this.emptyResult();
    if (typeof value !== 'object' || Array.isArray(value) || value instanceof Date) return this.typeError();
    const source = value as Record<string, Object>;
    const errors: ValidateError[] = [];
    for (const key of Object.keys(source)) {
      const result = this.valueSchema.validate(source[key], source);
      for (const error of result.errors) {
        const path = error.path === '' ? key : `${key}.${error.path}`;
        errors.push({ path, message: error.message, code: error.code });
      }
    }
    return { valid: errors.length === 0, errors };
  }

  async validateAsync(value: Object | null | undefined): Promise<ValidateResult> {
    if (value === null || value === undefined) return this.emptyResult();
    if (typeof value !== 'object' || Array.isArray(value) || value instanceof Date) return this.typeError();
    const source = value as Record<string, Object>;
    const keys = Object.keys(source);
    const tasks: Array<Promise<ValidateResult>> = [];
    for (const key of keys) tasks.push(this.valueSchema.validateAsync(source[key], source));
    const results = await Promise.all(tasks);
    const errors: ValidateError[] = [];
    for (let i = 0; i < keys.length; i++) {
      for (const error of results[i].errors) {
        const path = error.path === '' ? keys[i] : `${keys[i]}.${error.path}`;
        errors.push({ path, message: error.message, code: error.code });
      }
    }
    return { valid: errors.length === 0, errors };
  }

  parse(value: Object | null | undefined): ParseResult<Record<string, T>> {
    if (value === null || value === undefined) {
      const result = this.emptyResult();
      return result.valid ? { success: true, errors: [] } : { success: false, errors: result.errors };
    }
    if (typeof value !== 'object' || Array.isArray(value) || value instanceof Date) {
      return { success: false, errors: this.typeError().errors };
    }
    const source = value as Record<string, Object>;
    const output: Record<string, T> = {};
    const errors: ValidateError[] = [];
    for (const key of Object.keys(source)) {
      const parsed = parseSchema<T>(this.valueSchema, source[key], source);
      if (parsed.success) {
        output[key] = parsed.value as T;
      } else {
        for (const error of parsed.errors) {
          const path = error.path === '' ? key : `${key}.${error.path}`;
          errors.push({ path, message: error.message, code: error.code });
        }
      }
    }
    return errors.length === 0 ? { success: true, value: output, errors: [] } : { success: false, errors };
  }

  async parseAsync(value: Object | null | undefined): Promise<ParseResult<Record<string, T>>> {
    if (value === null || value === undefined) {
      const result = this.emptyResult();
      return result.valid ? { success: true, errors: [] } : { success: false, errors: result.errors };
    }
    if (typeof value !== 'object' || Array.isArray(value) || value instanceof Date) {
      return { success: false, errors: this.typeError().errors };
    }
    const source = value as Record<string, Object>;
    const keys = Object.keys(source);
    const tasks: Array<Promise<ParseResult<T>>> = [];
    for (const key of keys) tasks.push(parseSchemaAsync<T>(this.valueSchema, source[key], source));
    const results = await Promise.all(tasks);
    const output: Record<string, T> = {};
    const errors: ValidateError[] = [];
    for (let i = 0; i < keys.length; i++) {
      const parsed = results[i];
      if (parsed.success) {
        output[keys[i]] = parsed.value as T;
      } else {
        for (const error of parsed.errors) {
          const path = error.path === '' ? keys[i] : `${keys[i]}.${error.path}`;
          errors.push({ path, message: error.message, code: error.code });
        }
      }
    }
    return errors.length === 0 ? { success: true, value: output, errors: [] } : { success: false, errors };
  }
}
