import {
  AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateError, ValidateResult
} from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, parseSchema, parseSchemaAsync, TransformSchema } from './EffectSchemas';

/** 固定长度、逐位置校验的异构数组。ArkTS 中输出使用 Array<Object>。 */
export class TupleSchema implements ParsableSchema<Array<Object>> {
  readonly __schemaType: Array<Object> | null = null;
  private items: Array<AnySchema>;
  private isOptional: boolean = false;
  private customMessage?: string;
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  constructor(items: Array<AnySchema>, message?: string) { this.items = items.slice(); this.customMessage = message; }
  meta(value: SchemaMetadata): TupleSchema { this.docs.meta(value); return this; }
  describe(description: string): TupleSchema { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    const result = this.docs.build('tuple', !this.isOptional, false);
    for (const item of this.items) result.tupleItems.push(schemaToDescriptor(item));
    return result;
  }
  label(name: string): TupleSchema { this.fieldLabel = name; this.docs.label(name); return this; }
  optional(): TupleSchema { this.isOptional = true; return this; }
  required(message?: string): TupleSchema { this.isOptional = false; this.customMessage = message; return this; }
  nullable(): NullableSchema<Array<Object>> { return new NullableSchema<Array<Object>>(this); }
  default(value: Array<Object>): DefaultSchema<Array<Object>> { return new DefaultSchema<Array<Object>>(this, value); }
  transform<U>(fn: (value: Array<Object>) => U, message?: string): TransformSchema<Array<Object>, U> {
    return new TransformSchema<Array<Object>, U>(this, fn, message);
  }

  private emptyResult(): ValidateResult {
    return this.isOptional ? { valid: true, errors: [] } : {
      valid: false, errors: [validationError(issue(ErrorCode.REQUIRED, this.customMessage), this.fieldLabel)]
    };
  }
  private baseErrors(value: Object | null | undefined): ValidateError[] {
    if (!Array.isArray(value)) return [validationError(issue(ErrorCode.TYPE_ARRAY), this.fieldLabel)];
    if (value.length !== this.items.length) return [validationError(issue(ErrorCode.TUPLE_LENGTH,
      this.customMessage, { 'length': `${this.items.length}` }), this.fieldLabel)];
    return [];
  }
  validate(value: Object | null | undefined): ValidateResult {
    if (value === null || value === undefined) return this.emptyResult();
    const errors = this.baseErrors(value);
    if (errors.length > 0) return { valid: false, errors };
    const source = value as Array<Object>;
    for (let i = 0; i < this.items.length; i++) {
      const result = this.items[i].validate(source[i]);
      for (const error of result.errors) {
        const path = error.path === '' ? `${i}` : `${i}.${error.path}`;
        errors.push({ path, message: error.message, code: error.code });
      }
    }
    return { valid: errors.length === 0, errors };
  }
  async validateAsync(value: Object | null | undefined): Promise<ValidateResult> {
    if (value === null || value === undefined) return this.emptyResult();
    const errors = this.baseErrors(value);
    if (errors.length > 0) return { valid: false, errors };
    const source = value as Array<Object>;
    const tasks: Array<Promise<ValidateResult>> = [];
    for (let i = 0; i < this.items.length; i++) tasks.push(this.items[i].validateAsync(source[i]));
    const results = await Promise.all(tasks);
    for (let i = 0; i < results.length; i++) {
      for (const error of results[i].errors) {
        const path = error.path === '' ? `${i}` : `${i}.${error.path}`;
        errors.push({ path, message: error.message, code: error.code });
      }
    }
    return { valid: errors.length === 0, errors };
  }
  parse(value: Object | null | undefined): ParseResult<Array<Object>> {
    if (value === null || value === undefined) {
      const result = this.emptyResult();
      return result.valid ? { success: true, errors: [] } : { success: false, errors: result.errors };
    }
    const errors = this.baseErrors(value);
    if (errors.length > 0) return { success: false, errors };
    const source = value as Array<Object>;
    const output: Array<Object> = [];
    for (let i = 0; i < this.items.length; i++) {
      const parsed = parseSchema(this.items[i], source[i]);
      if (parsed.success) output.push(parsed.value === undefined ? source[i] : parsed.value as Object);
      else for (const error of parsed.errors) {
        const path = error.path === '' ? `${i}` : `${i}.${error.path}`;
        errors.push({ path, message: error.message, code: error.code });
      }
    }
    return errors.length === 0 ? { success: true, value: output, errors: [] } : { success: false, errors };
  }
  async parseAsync(value: Object | null | undefined): Promise<ParseResult<Array<Object>>> {
    if (value === null || value === undefined) {
      const result = this.emptyResult();
      return result.valid ? { success: true, errors: [] } : { success: false, errors: result.errors };
    }
    const errors = this.baseErrors(value);
    if (errors.length > 0) return { success: false, errors };
    const source = value as Array<Object>;
    const tasks: Array<Promise<ParseResult<Object>>> = [];
    for (let i = 0; i < this.items.length; i++) tasks.push(parseSchemaAsync<Object>(this.items[i], source[i]));
    const results = await Promise.all(tasks);
    const output: Array<Object> = [];
    for (let i = 0; i < results.length; i++) {
      if (results[i].success) output.push(results[i].value === undefined ? source[i] : results[i].value as Object);
      else for (const error of results[i].errors) {
        const path = error.path === '' ? `${i}` : `${i}.${error.path}`;
        errors.push({ path, message: error.message, code: error.code });
      }
    }
    return errors.length === 0 ? { success: true, value: output, errors: [] } : { success: false, errors };
  }
}
