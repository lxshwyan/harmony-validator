import { AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, ValidateResult } from './types';
import { applyValidationOptions, ValidationOptions } from './errors';
import { parseSchema, parseSchemaAsync } from '../schemas/EffectSchemas';

/** Input-only constraint wrapper. Parsing still delegates defaults/transforms to the inner schema. */
export class CheckedSchema<T> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private inner: AnySchema<T>;
  private check: (value: Object | null | undefined) => ValidateResult;
  private kind: string;
  private outputCheck: boolean;
  constructor(inner: AnySchema<T>, check: (value: Object | null | undefined) => ValidateResult, kind: string, outputCheck: boolean = false) {
    this.inner = inner; this.check = check; this.kind = kind; this.outputCheck = outputCheck;
  }
  describeSchema(): SchemaDescriptor {
    const result = new SchemaDescriptor(this.kind);
    result.unrepresentable.push(this.kind);
    return result;
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): ValidateResult {
    if (this.outputCheck) {
      const result = this.parse(value, siblings, options);
      return { valid: result.success, errors: result.errors };
    }
    const check = applyValidationOptions(this.check(value), options);
    return check.valid ? this.inner.validate(value, siblings, options) : check;
  }
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): Promise<ValidateResult> {
    if (this.outputCheck) {
      const result = await this.parseAsync(value, siblings, options);
      return { valid: result.success, errors: result.errors };
    }
    const check = applyValidationOptions(this.check(value), options);
    return check.valid ? this.inner.validateAsync(value, siblings, options) : check;
  }
  parse(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): ParseResult<T> {
    if (this.outputCheck) {
      const result = parseSchema(this.inner, value, siblings, options);
      if (!result.success) return result;
      const checked = applyValidationOptions(this.check(result.value as Object), options);
      return checked.valid ? result : { success: false, errors: checked.errors };
    }
    const check = applyValidationOptions(this.check(value), options);
    return check.valid ? parseSchema(this.inner, value, siblings, options) : { success: false, errors: check.errors };
  }
  async parseAsync(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): Promise<ParseResult<T>> {
    if (this.outputCheck) {
      const result = await parseSchemaAsync(this.inner, value, siblings, options);
      if (!result.success) return result;
      const checked = applyValidationOptions(this.check(result.value as Object), options);
      return checked.valid ? result : { success: false, errors: checked.errors };
    }
    const check = applyValidationOptions(this.check(value), options);
    return check.valid ? parseSchemaAsync(this.inner, value, siblings, options) : { success: false, errors: check.errors };
  }
}
