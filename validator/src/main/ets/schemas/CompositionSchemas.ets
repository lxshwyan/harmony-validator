import {
  AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateError, ValidateResult
} from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { DefaultSchema, NullableSchema, parseSchema, parseSchemaAsync, TransformSchema } from './EffectSchemas';

export type LazySchemaFactory<T> = () => AnySchema<T>;
export type WhenPredicate = (other: Object | null | undefined, siblings?: Record<string, Object>) => boolean;

/** 延迟取得内部 Schema，支持树形或其他递归数据结构。 */
export class LazySchema<T> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private factory: LazySchemaFactory<T>;
  private resolved?: AnySchema<T>;
  private docs: SchemaDocs = new SchemaDocs();
  private describing: boolean = false;
  private activeDescriptor?: SchemaDescriptor;

  constructor(factory: LazySchemaFactory<T>) { this.factory = factory; }
  meta(value: SchemaMetadata): LazySchema<T> { this.docs.meta(value); return this; }
  describe(value: string): LazySchema<T> { this.docs.describe(value); return this; }
  label(value: string): LazySchema<T> { this.docs.label(value); return this; }
  nullable(): NullableSchema<T> { return new NullableSchema<T>(this); }
  default(value: T): DefaultSchema<T> { return new DefaultSchema<T>(this, value); }
  transform<U>(fn: (value: T) => U, message?: string): TransformSchema<T, U> {
    return new TransformSchema<T, U>(this, fn, message);
  }

  private schema(): AnySchema<T> {
    if (this.resolved === undefined) this.resolved = this.factory();
    if (this.resolved === this) throw new Error('Lazy schema factory cannot return itself directly');
    return this.resolved;
  }

  describeSchema(): SchemaDescriptor {
    if (this.describing && this.activeDescriptor !== undefined) return this.activeDescriptor;
    const result = this.docs.build('lazy');
    this.describing = true;
    this.activeDescriptor = result;
    result.inner = schemaToDescriptor(this.schema());
    this.activeDescriptor = undefined;
    this.describing = false;
    return result;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    return this.schema().validate(value, siblings);
  }
  validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    return this.schema().validateAsync(value, siblings);
  }
  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T> {
    return parseSchema<T>(this.schema(), value, siblings);
  }
  parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<T>> {
    return parseSchemaAsync<T>(this.schema(), value, siblings);
  }
}

function appendUnique(target: ValidateError[], source: ValidateError[]): void {
  for (const error of source) {
    let duplicate = false;
    for (const current of target) {
      if (current.path === error.path && current.code === error.code && current.message === error.message) {
        duplicate = true;
        break;
      }
    }
    if (!duplicate) target.push(error);
  }
}

function isRecord(value: Object | null | undefined): boolean {
  return value !== null && value !== undefined && typeof value === 'object' &&
    !Array.isArray(value) && !(value instanceof Date);
}

function mergeParsed<T>(left: T | undefined, right: T | undefined): T | undefined {
  if (left === undefined) return right;
  if (right === undefined) return left;
  if (isRecord(left as Object) && isRecord(right as Object)) {
    const output: Record<string, Object> = {};
    const leftRecord = left as Record<string, Object>;
    const rightRecord = right as Record<string, Object>;
    for (const key of Object.keys(leftRecord)) output[key] = leftRecord[key];
    for (const key of Object.keys(rightRecord)) output[key] = rightRecord[key];
    return output as T;
  }
  return right;
}

/** 同一输入必须同时满足两个 Schema；对象 parse 结果按右侧优先合并。 */
export class IntersectionSchema<T> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private left: AnySchema<T>;
  private right: AnySchema<T>;
  private docs: SchemaDocs = new SchemaDocs();

  constructor(left: AnySchema<T>, right: AnySchema<T>) { this.left = left; this.right = right; }
  meta(value: SchemaMetadata): IntersectionSchema<T> { this.docs.meta(value); return this; }
  describe(value: string): IntersectionSchema<T> { this.docs.describe(value); return this; }
  label(value: string): IntersectionSchema<T> { this.docs.label(value); return this; }
  nullable(): NullableSchema<T> { return new NullableSchema<T>(this); }
  default(value: T): DefaultSchema<T> { return new DefaultSchema<T>(this, value); }
  transform<U>(fn: (value: T) => U, message?: string): TransformSchema<T, U> {
    return new TransformSchema<T, U>(this, fn, message);
  }
  describeSchema(): SchemaDescriptor {
    const result = this.docs.build('intersection');
    result.options.push(schemaToDescriptor(this.left));
    result.options.push(schemaToDescriptor(this.right));
    return result;
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    appendUnique(errors, this.left.validate(value, siblings).errors);
    appendUnique(errors, this.right.validate(value, siblings).errors);
    return { valid: errors.length === 0, errors };
  }
  async validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    const results = await Promise.all([
      this.left.validateAsync(value, siblings), this.right.validateAsync(value, siblings)
    ]);
    const errors: ValidateError[] = [];
    appendUnique(errors, results[0].errors);
    appendUnique(errors, results[1].errors);
    return { valid: errors.length === 0, errors };
  }
  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T> {
    const left = parseSchema<T>(this.left, value, siblings);
    const right = parseSchema<T>(this.right, value, siblings);
    const errors: ValidateError[] = [];
    appendUnique(errors, left.errors);
    appendUnique(errors, right.errors);
    if (errors.length > 0) return { success: false, errors };
    return { success: true, value: mergeParsed(left.value, right.value), errors: [] };
  }
  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<T>> {
    const results = await Promise.all([
      parseSchemaAsync<T>(this.left, value, siblings), parseSchemaAsync<T>(this.right, value, siblings)
    ]);
    const errors: ValidateError[] = [];
    appendUnique(errors, results[0].errors);
    appendUnique(errors, results[1].errors);
    if (errors.length > 0) return { success: false, errors };
    return { success: true, value: mergeParsed(results[0].value, results[1].value), errors: [] };
  }
}

/** 根据兄弟字段选择 Schema；条件异常会稳定地选择 otherwise 分支。 */
export class WhenSchema<T> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private field: string;
  private predicate: WhenPredicate;
  private thenSchema: AnySchema<T>;
  private otherwiseSchema: AnySchema<T>;
  private docs: SchemaDocs = new SchemaDocs();

  constructor(field: string, predicate: WhenPredicate, thenSchema: AnySchema<T>, otherwiseSchema: AnySchema<T>) {
    this.field = field;
    this.predicate = predicate;
    this.thenSchema = thenSchema;
    this.otherwiseSchema = otherwiseSchema;
  }
  meta(value: SchemaMetadata): WhenSchema<T> { this.docs.meta(value); return this; }
  describe(value: string): WhenSchema<T> { this.docs.describe(value); return this; }
  label(value: string): WhenSchema<T> { this.docs.label(value); return this; }
  nullable(): NullableSchema<T> { return new NullableSchema<T>(this); }
  default(value: T): DefaultSchema<T> { return new DefaultSchema<T>(this, value); }
  transform<U>(fn: (value: T) => U, message?: string): TransformSchema<T, U> {
    return new TransformSchema<T, U>(this, fn, message);
  }
  private selected(siblings?: Record<string, Object>): AnySchema<T> {
    let matched = false;
    try { matched = this.predicate(siblings?.[this.field], siblings); } catch (_error) { matched = false; }
    return matched ? this.thenSchema : this.otherwiseSchema;
  }
  describeSchema(): SchemaDescriptor {
    const result = this.docs.build('conditional', false, true);
    result.options.push(schemaToDescriptor(this.thenSchema));
    result.options.push(schemaToDescriptor(this.otherwiseSchema));
    result.value = this.field;
    result.unrepresentable.push(`runtime-condition:${this.field}`);
    return result;
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    return this.selected(siblings).validate(value, siblings);
  }
  validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    return this.selected(siblings).validateAsync(value, siblings);
  }
  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T> {
    return parseSchema<T>(this.selected(siblings), value, siblings);
  }
  parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<T>> {
    return parseSchemaAsync<T>(this.selected(siblings), value, siblings);
  }
}
