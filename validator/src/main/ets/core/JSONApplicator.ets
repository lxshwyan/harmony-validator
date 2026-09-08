import { AnySchema, ParseResult, ValidateError, ValidateResult } from './types';
import { ValidationOptions } from './errors';
import { ErrorCode, issue, validationError } from './i18n';

/** JSON string keywords apply to empty strings and count Unicode code points. */
export class JSONStringKeywords implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private minimum?: number;
  private maximum?: number;
  private pattern?: RegExp;
  constructor(node: Record<string, Object>) {
    this.minimum = node['minLength'] as number | undefined;
    this.maximum = node['maxLength'] as number | undefined;
    if (node['pattern'] !== undefined) this.pattern = new RegExp(node['pattern'] as string);
  }
  validate(value: Object | null | undefined): ValidateResult {
    const errors: ValidateError[] = [];
    if (typeof value !== 'string') return { valid: true, errors };
    let length = 0;
    for (let i = 0; i < value.length; i++) {
      const code = value.charCodeAt(i);
      const next = value.charCodeAt(i + 1);
      if (code >= 0xD800 && code <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF) i++;
      length++;
    }
    if (this.minimum !== undefined && length < this.minimum) {
      errors.push(validationError(issue(ErrorCode.STRING_MIN, undefined, { 'min': `${this.minimum}` })));
    }
    if (this.maximum !== undefined && length > this.maximum) {
      errors.push(validationError(issue(ErrorCode.STRING_MAX, undefined, { 'max': `${this.maximum}` })));
    }
    if (this.pattern !== undefined && !this.pattern.test(value)) errors.push(validationError(issue(ErrorCode.PATTERN)));
    return { valid: errors.length === 0, errors };
  }
  validateAsync(value: Object | null | undefined): Promise<ValidateResult> { return Promise.resolve(this.validate(value)); }
}

/** Import-only JSON applicator: validates raw input without merging or transforming it. */
export class JSONApplicator implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private schemas: Array<AnySchema<Object>>;
  private mode: string;
  constructor(schemas: Array<AnySchema<Object>>, mode: string) { this.schemas = schemas; this.mode = mode; }
  private combine(results: Array<ValidateResult>): ValidateResult {
    let matches = 0;
    const errors: ValidateError[] = [];
    for (const result of results) {
      if (result.valid) matches++;
      else for (const error of result.errors) errors.push(error);
    }
    const valid = this.mode === 'allOf' ? matches === results.length
      : this.mode === 'oneOf' ? matches === 1 : matches > 0;
    if (valid) return { valid: true, errors: [] };
    return { valid: false, errors: this.mode === 'allOf' ? errors
      : [validationError(issue(this.mode === 'oneOf' ? ErrorCode.ONE_OF : ErrorCode.UNION))] };
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): ValidateResult {
    return this.combine(this.schemas.map((schema: AnySchema<Object>): ValidateResult => schema.validate(value, siblings, options)));
  }
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): Promise<ValidateResult> {
    return this.combine(await Promise.all(this.schemas.map((schema: AnySchema<Object>): Promise<ValidateResult> => schema.validateAsync(value, siblings, options))));
  }
  parse(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): ParseResult<Object> {
    const result = this.validate(value, siblings, options);
    return { success: result.valid, value: result.valid ? value as Object : undefined, errors: result.errors };
  }
  async parseAsync(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): Promise<ParseResult<Object>> {
    const result = await this.validateAsync(value, siblings, options);
    return { success: result.valid, value: result.valid ? value as Object : undefined, errors: result.errors };
  }
}

/** JSON keywords without type apply only to instances of the corresponding type. */
export class JSONTypeGuard implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private inner: AnySchema<Object>;
  private type: string;
  constructor(inner: AnySchema<Object>, type: string) { this.inner = inner; this.type = type; }
  private applies(value: Object | null | undefined): boolean {
    if (this.type === 'array') return Array.isArray(value);
    if (this.type === 'object') return value !== null && typeof value === 'object' && !Array.isArray(value);
    return typeof value === this.type;
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): ValidateResult {
    return this.applies(value) ? this.inner.validate(value, siblings, options) : { valid: true, errors: [] };
  }
  validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): Promise<ValidateResult> {
    const passed: ValidateResult = { valid: true, errors: [] };
    return this.applies(value) ? this.inner.validateAsync(value, siblings, options) : Promise.resolve(passed);
  }
}
