import { AnySchema, ValidateError, ValidateResult } from './types';
import { ValidationOptions } from './errors';
import { issue, validationError } from './i18n';

class DecimalInteger {
  digits: string;
  scale: number;
  constructor(value: number) {
    const parts = Math.abs(value).toString().toLowerCase().split('e');
    const decimal = parts[0].split('.');
    this.digits = (decimal[0] + (decimal[1] ?? '')).replace(/^0+/, '') || '0';
    this.scale = (decimal[1]?.length ?? 0) - (parts[1] === undefined ? 0 : Number(parts[1]));
  }
}

function subtract(left: string, right: string): string {
  let borrow = 0;
  let output = '';
  for (let i = left.length - 1, j = right.length - 1; i >= 0; i--, j--) {
    let digit = Number(left[i]) - (j >= 0 ? Number(right[j]) : 0) - borrow;
    borrow = digit < 0 ? 1 : 0;
    if (borrow) digit += 10;
    output = `${digit}${output}`;
  }
  return output.replace(/^0+/, '') || '0';
}

/** Exact divisibility of the canonical decimal representations of two JS numbers. */
function multiple(value: number, divisor: number): boolean {
  const a = new DecimalInteger(value);
  const b = new DecimalInteger(divisor);
  const scale = Math.max(a.scale, b.scale);
  const numerator = a.digits + '0'.repeat(scale - a.scale);
  const denominator = b.digits + '0'.repeat(scale - b.scale);
  let remainder = '0';
  for (const digit of numerator) {
    remainder = (remainder + digit).replace(/^0+/, '') || '0';
    while (remainder.length > denominator.length || (remainder.length === denominator.length && remainder >= denominator)) {
      remainder = subtract(remainder, denominator);
    }
  }
  return remainder === '0';
}

export class JSONNumberKeywords implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private minimum?: number;
  private maximum?: number;
  private divisor?: number;
  constructor(node: Record<string, Object>) {
    this.minimum = node['exclusiveMinimum'] as number | undefined;
    this.maximum = node['exclusiveMaximum'] as number | undefined;
    this.divisor = node['multipleOf'] as number | undefined;
    if (this.divisor !== undefined && (!Number.isFinite(this.divisor) || this.divisor <= 0)) {
      throw new RangeError('multipleOf must be finite and positive');
    }
  }
  validate(value: Object | null | undefined): ValidateResult {
    const errors: ValidateError[] = [];
    if (typeof value !== 'number') return { valid: true, errors };
    if (!Number.isFinite(value)) return { valid: false, errors: [validationError(issue('invalid_number'))] };
    if (this.minimum !== undefined && value <= this.minimum) errors.push(validationError(issue('exclusive_minimum')));
    if (this.maximum !== undefined && value >= this.maximum) errors.push(validationError(issue('exclusive_maximum')));
    if (this.divisor !== undefined && !multiple(value, this.divisor)) errors.push(validationError(issue('multiple_of')));
    return { valid: errors.length === 0, errors };
  }
  validateAsync(value: Object | null | undefined): Promise<ValidateResult> { return Promise.resolve(this.validate(value)); }
}

class ValuePair {
  left: Object | null | undefined;
  right: Object | null | undefined;
  constructor(left: Object | null | undefined, right: Object | null | undefined) { this.left = left; this.right = right; }
}

/** Structural JSON equality, independent of object property insertion order. */
function equal(left: Object | null | undefined, right: Object | null | undefined): boolean {
  const work: ValuePair[] = [new ValuePair(left, right)];
  const seen: Map<Object, Set<Object>> = new Map<Object, Set<Object>>();
  while (work.length > 0) {
    const pair = work.pop() as ValuePair;
    const a = pair.left; const b = pair.right;
    if (a === b) continue;
    if (a === null || b === null || typeof a !== 'object' || typeof b !== 'object') return false;
    if (Array.isArray(a) !== Array.isArray(b)) return false;
    if (Array.isArray(a) && (a as Object[]).length !== (b as Object[]).length) return false;
    const partners = seen.get(a) ?? new Set<Object>();
    if (partners.has(b)) continue;
    partners.add(b); seen.set(a, partners);
    const keys = Object.keys(a); const otherKeys = Object.keys(b);
    if (keys.length !== otherKeys.length) return false;
    for (const key of keys) {
      if (otherKeys.indexOf(key) === -1) return false;
      work.push(new ValuePair((a as Record<string, Object>)[key], (b as Record<string, Object>)[key]));
    }
  }
  return true;
}

export class JSONArrayKeywords implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private unique: boolean;
  private contains?: AnySchema<Object>;
  private minimum: number;
  private maximum?: number;
  constructor(node: Record<string, Object>, contains?: AnySchema<Object>) {
    this.unique = node['uniqueItems'] === true; this.contains = contains;
    this.minimum = node['minContains'] === undefined ? 1 : node['minContains'] as number;
    this.maximum = node['maxContains'] as number | undefined;
  }
  private uniqueErrors(values: Object[]): ValidateError[] {
    const errors: ValidateError[] = [];
    if (!this.unique) return errors;
    for (let i = 1; i < values.length; i++) {
      for (let j = 0; j < i; j++) {
        if (equal(values[i], values[j])) {
          const error = validationError(issue('unique_items')); error.path = `${i}`; errors.push(error); break;
        }
      }
    }
    return errors;
  }
  private result(errors: ValidateError[], matches: number): ValidateResult {
    if (this.contains !== undefined && (matches < this.minimum || (this.maximum !== undefined && matches > this.maximum))) {
      errors.push(validationError(issue('contains')));
    }
    return { valid: errors.length === 0, errors };
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): ValidateResult {
    if (!Array.isArray(value)) return { valid: true, errors: [] };
    const values = value as Object[]; let matches = 0;
    if (this.contains !== undefined) for (const item of values) if (this.contains.validate(item, siblings, options).valid) matches++;
    return this.result(this.uniqueErrors(values), matches);
  }
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): Promise<ValidateResult> {
    if (!Array.isArray(value)) return { valid: true, errors: [] };
    const values = value as Object[]; let matches = 0;
    if (this.contains !== undefined) for (const item of values) if ((await this.contains.validateAsync(item, siblings, options)).valid) matches++;
    return this.result(this.uniqueErrors(values), matches);
  }
}

export class JSONConditional implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private condition: AnySchema<Object>;
  private yes?: AnySchema<Object>;
  private no?: AnySchema<Object>;
  constructor(condition: AnySchema<Object>, yes?: AnySchema<Object>, no?: AnySchema<Object>) {
    this.condition = condition; this.yes = yes; this.no = no;
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): ValidateResult {
    const branch = this.condition.validate(value, siblings, options).valid ? this.yes : this.no;
    return branch === undefined ? { valid: true, errors: [] } : branch.validate(value, siblings, options);
  }
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): Promise<ValidateResult> {
    const branch = (await this.condition.validateAsync(value, siblings, options)).valid ? this.yes : this.no;
    return branch === undefined ? { valid: true, errors: [] } : branch.validateAsync(value, siblings, options);
  }
}
