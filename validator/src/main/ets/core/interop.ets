import { AnySchema, ParseResult, SchemaDescriptor, SchemaRuleDescriptor, ValidateResult } from './types';
import { StringSchema } from '../schemas/StringSchema';
import { NumberSchema } from '../schemas/NumberSchema';
import { BooleanSchema } from '../schemas/BooleanSchema';
import { DateSchema } from '../schemas/DateSchema';
import { ArraySchema } from '../schemas/ArraySchema';
import { ObjectSchema, SchemaShape } from '../schemas/ObjectSchema';
import { EnumSchema } from '../schemas/EnumSchema';
import { LiteralSchema } from '../schemas/LiteralSchema';
import { UnionSchema } from '../schemas/UnionSchema';
import { RecordSchema } from '../schemas/RecordSchema';
import { TupleSchema } from '../schemas/TupleSchema';
import { DiscriminatedUnionSchema } from '../schemas/DiscriminatedUnionSchema';
import { DefaultSchema, NullableSchema } from '../schemas/EffectSchemas';
import { AnyValueSchema, NeverSchema, NullSchema, UnknownSchema } from '../schemas/BasicSchemas';
import { IntersectionSchema, LazySchema } from '../schemas/CompositionSchemas';
import { getStringRule } from '../plugins/StringRulePlugin';
import { ErrorCode, issue, validationError } from './i18n';

export type SchemaDescriptorFactory = (descriptor: SchemaDescriptor, registry: SchemaRegistry) => AnySchema<Object>;

/** 仅用于异构注册表；运行时值和结构描述均原样委托。 */
class ErasedSchema<T> implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private inner: AnySchema<T>;

  constructor(inner: AnySchema<T>) { this.inner = inner; }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    return this.inner.validate(value, siblings);
  }
  validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    return this.inner.validateAsync(value, siblings);
  }
  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<Object> {
    const result = this.inner.parse === undefined ? undefined : this.inner.parse(value, siblings);
    if (result === undefined) {
      const checked = this.inner.validate(value, siblings);
      return checked.valid ? { success: true, value: value as Object, errors: [] }
        : { success: false, errors: checked.errors };
    }
    if (!result.success) return { success: false, errors: result.errors };
    return result.value === undefined ? { success: true, errors: [] }
      : { success: true, value: result.value as Object, errors: [] };
  }
  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<Object>> {
    if (this.inner.parseAsync === undefined) return this.parse(value, siblings);
    const result = await this.inner.parseAsync(value, siblings);
    if (!result.success) return { success: false, errors: result.errors };
    return result.value === undefined ? { success: true, errors: [] }
      : { success: true, value: result.value as Object, errors: [] };
  }
  describeSchema(): SchemaDescriptor {
    return this.inner.describeSchema === undefined ? new SchemaDescriptor('custom') : this.inner.describeSchema();
  }
}

function erase<T>(schema: AnySchema<T>): AnySchema<Object> { return new ErasedSchema<T>(schema); }

/** JSON Schema 的 required 表示“属性必须存在”，不等同于字符串非空。 */
class RequiredPropertySchema implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private inner: AnySchema<Object>;

  constructor(inner: AnySchema<Object>) { this.inner = inner; }
  private missing(): ValidateResult {
    return { valid: false, errors: [validationError(issue(ErrorCode.REQUIRED))] };
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    return value === undefined ? this.missing() : this.inner.validate(value, siblings);
  }
  validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    return value === undefined ? Promise.resolve(this.missing()) : this.inner.validateAsync(value, siblings);
  }
  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<Object> {
    if (value === undefined) return { success: false, errors: this.missing().errors };
    if (this.inner.parse !== undefined) return this.inner.parse(value, siblings);
    const checked = this.inner.validate(value, siblings);
    return checked.valid ? { success: true, value: value as Object, errors: [] }
      : { success: false, errors: checked.errors };
  }
  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<Object>> {
    if (value === undefined) return { success: false, errors: this.missing().errors };
    if (this.inner.parseAsync !== undefined) return this.inner.parseAsync(value, siblings);
    const checked = await this.inner.validateAsync(value, siblings);
    return checked.valid ? { success: true, value: value as Object, errors: [] }
      : { success: false, errors: checked.errors };
  }
  describeSchema(): SchemaDescriptor {
    return this.inner.describeSchema === undefined ? new SchemaDescriptor('custom') : this.inner.describeSchema();
  }
}

/** JSON Schema 非 null 类型在属性存在时必须拒绝 null；undefined 仍由对象 required 决定。 */
class JSONNonNullSchema implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private inner: AnySchema<Object>;
  private errorCode: string;

  constructor(inner: AnySchema<Object>, errorCode: string) { this.inner = inner; this.errorCode = errorCode; }
  private nullResult(): ValidateResult {
    return { valid: false, errors: [validationError(issue(this.errorCode))] };
  }
  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    return value === null ? this.nullResult() : this.inner.validate(value, siblings);
  }
  validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    return value === null ? Promise.resolve(this.nullResult()) : this.inner.validateAsync(value, siblings);
  }
  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<Object> {
    if (value === null) return { success: false, errors: this.nullResult().errors };
    if (this.inner.parse !== undefined) return this.inner.parse(value, siblings);
    const checked = this.inner.validate(value, siblings);
    return checked.valid ? { success: true, value: value as Object, errors: [] }
      : { success: false, errors: checked.errors };
  }
  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<Object>> {
    if (value === null) return { success: false, errors: this.nullResult().errors };
    if (this.inner.parseAsync !== undefined) return this.inner.parseAsync(value, siblings);
    const checked = await this.inner.validateAsync(value, siblings);
    return checked.valid ? { success: true, value: value as Object, errors: [] }
      : { success: false, errors: checked.errors };
  }
  describeSchema(): SchemaDescriptor {
    return this.inner.describeSchema === undefined ? new SchemaDescriptor('custom') : this.inner.describeSchema();
  }
}

/** 可插拔的描述文档恢复注册中心；业务 Schema 可注册自己的 kind。 */
export class SchemaRegistry {
  private factories: Map<string, SchemaDescriptorFactory> = new Map<string, SchemaDescriptorFactory>();

  register(kind: string, factory: SchemaDescriptorFactory): SchemaRegistry {
    this.factories.set(kind, factory);
    return this;
  }

  unregister(kind: string): boolean { return this.factories.delete(kind); }

  create(descriptor: SchemaDescriptor): AnySchema<Object> {
    const custom = this.factories.get(descriptor.kind);
    if (custom !== undefined) return custom(descriptor, this);
    return createBuiltIn(descriptor, this);
  }
}

function findRule(descriptor: SchemaDescriptor, name: string): SchemaRuleDescriptor | undefined {
  for (const rule of descriptor.rules) if (rule.name === name) return rule;
  return undefined;
}

function restoreString(descriptor: SchemaDescriptor): StringSchema {
  const schema = new StringSchema();
  if (descriptor.required) schema.required();
  for (const rule of descriptor.rules) {
    if (rule.name === 'minLength') schema.min(rule.value as number);
    else if (rule.name === 'maxLength') schema.max(rule.value as number);
    else if (rule.name === 'pattern') schema.pattern(new RegExp(rule.value as string, rule.detail ?? ''));
    else if (rule.name === 'format' || rule.name === 'plugin') {
      const name = rule.name === 'format' ? rule.value as string : rule.detail ?? '';
      const normalized = name === 'uri' ? 'url' : name;
      const plugin = getStringRule(normalized);
      if (plugin !== undefined) schema.use(plugin);
    }
  }
  return schema;
}

function restoreNumber(descriptor: SchemaDescriptor): NumberSchema {
  const schema = new NumberSchema();
  if (descriptor.required) schema.required();
  for (const rule of descriptor.rules) {
    if (rule.name === 'minimum') schema.min(rule.value as number);
    else if (rule.name === 'maximum') schema.max(rule.value as number);
    else if (rule.name === 'integer') schema.integer();
    else if (rule.name === 'exclusiveMinimum' && rule.value === 0) schema.positive();
  }
  return schema;
}

function restoreBoolean(descriptor: SchemaDescriptor): BooleanSchema {
  const schema = new BooleanSchema();
  if (descriptor.required) schema.required();
  const constant = findRule(descriptor, 'const');
  if (constant?.value === true) schema.isTrue();
  else if (constant?.value === false) schema.isFalse();
  return schema;
}

function restoreDate(descriptor: SchemaDescriptor): DateSchema {
  const schema = new DateSchema();
  if (descriptor.required) schema.required();
  for (const rule of descriptor.rules) {
    if (rule.name === 'strict-date') schema.strict();
    else if (rule.name === 'minimum-date') schema.min(rule.value as number);
    else if (rule.name === 'maximum-date') schema.max(rule.value as number);
  }
  return schema;
}

function restoreObject(descriptor: SchemaDescriptor, registry: SchemaRegistry): ObjectSchema<Record<string, Object>> {
  const shape: SchemaShape = {};
  if (descriptor.properties !== undefined) {
    for (const key of Object.keys(descriptor.properties)) shape[key] = registry.create(descriptor.properties[key]);
  }
  let schema = new ObjectSchema<Record<string, Object>>(shape);
  if (!descriptor.required) schema = schema.optional();
  if (descriptor.optionalProperties.length > 0) schema = schema.partial(descriptor.optionalProperties);
  if (descriptor.unknownKeys === 'strict') schema.strict();
  else if (descriptor.unknownKeys === 'strip') schema.strip();
  return schema;
}

function restoreEnum(descriptor: SchemaDescriptor): AnySchema<Object> {
  const values: Array<Object> = [];
  let acceptsNull = false;
  for (const rule of descriptor.rules) {
    if (rule.name === 'enum') {
      if (rule.value === null) acceptsNull = true;
      else if (rule.value !== undefined) values.push(rule.value);
    }
  }
  const base: AnySchema<Object> = new EnumSchema<Object>(values);
  return acceptsNull ? erase<Object | null>(new NullableSchema<Object>(base)) : base;
}

function createBuiltIn(descriptor: SchemaDescriptor, registry: SchemaRegistry): AnySchema<Object> {
  if (descriptor.kind === 'string') return restoreString(descriptor);
  if (descriptor.kind === 'number') return restoreNumber(descriptor);
  if (descriptor.kind === 'boolean') return restoreBoolean(descriptor);
  if (descriptor.kind === 'date') return restoreDate(descriptor);
  if (descriptor.kind === 'any') return erase<Object | null>(new AnyValueSchema());
  if (descriptor.kind === 'unknown') return erase<Object | null>(new UnknownSchema());
  if (descriptor.kind === 'never') return new NeverSchema();
  if (descriptor.kind === 'null') return erase<null>(new NullSchema());
  if (descriptor.kind === 'literal') {
    if (descriptor.value === null) return erase<null>(new NullSchema());
    return new LiteralSchema<Object>(descriptor.value as Object);
  }
  if (descriptor.kind === 'enum') return restoreEnum(descriptor);
  if (descriptor.kind === 'object') return restoreObject(descriptor, registry);
  if (descriptor.kind === 'array' && descriptor.items !== undefined) {
    const schema = new ArraySchema<Object>(registry.create(descriptor.items));
    if (descriptor.required) schema.required();
    for (const rule of descriptor.rules) {
      if (rule.name === 'minItems') schema.min(rule.value as number);
      else if (rule.name === 'maxItems') schema.max(rule.value as number);
    }
    return schema;
  }
  if (descriptor.kind === 'record' && descriptor.items !== undefined) {
    const schema = new RecordSchema<Object>(registry.create(descriptor.items));
    if (!descriptor.required) schema.optional();
    return schema;
  }
  if (descriptor.kind === 'tuple') {
    const items: Array<AnySchema> = [];
    for (const item of descriptor.tupleItems) items.push(registry.create(item));
    const schema = new TupleSchema(items);
    if (!descriptor.required) schema.optional();
    return schema;
  }
  if (descriptor.kind === 'union') {
    const options: Array<AnySchema<Object>> = [];
    for (const item of descriptor.options) options.push(registry.create(item) as AnySchema<Object>);
    return new UnionSchema<Object>(options);
  }
  if (descriptor.kind === 'intersection' && descriptor.options.length === 2) {
    return new IntersectionSchema<Object>(registry.create(descriptor.options[0]) as AnySchema<Object>,
      registry.create(descriptor.options[1]) as AnySchema<Object>);
  }
  if (descriptor.kind === 'discriminated-union' && descriptor.discriminator !== undefined &&
    descriptor.variants !== undefined) {
    const variants: Record<string, AnySchema<Record<string, Object>>> = {};
    for (const key of Object.keys(descriptor.variants)) {
      variants[key] = registry.create(descriptor.variants[key]) as AnySchema<Record<string, Object>>;
    }
    return new DiscriminatedUnionSchema<Record<string, Object>>(descriptor.discriminator, variants);
  }
  if (descriptor.kind === 'nullable' && descriptor.inner !== undefined) {
    return erase<Object | null>(new NullableSchema<Object>(registry.create(descriptor.inner)));
  }
  if (descriptor.kind === 'default' && descriptor.inner !== undefined && descriptor.defaultValue !== undefined) {
    return new DefaultSchema<Object>(registry.create(descriptor.inner) as AnySchema<Object>, descriptor.defaultValue);
  }
  if (descriptor.kind === 'lazy' && descriptor.inner !== undefined) {
    return new LazySchema<Object>((): AnySchema<Object> => registry.create(descriptor.inner as SchemaDescriptor));
  }
  throw new Error(`Schema kind cannot be restored without a registered factory: ${descriptor.kind}`);
}

export function schemaFromDescriptor(descriptor: SchemaDescriptor, registry?: SchemaRegistry): AnySchema<Object> {
  return (registry ?? new SchemaRegistry()).create(descriptor);
}

/** 从版本化文档恢复可执行 Schema；运行时函数需通过 SchemaRegistry 自定义恢复。 */
export function deserializeSchemaDocument(source: string, registry?: SchemaRegistry): AnySchema<Object> {
  const raw = JSON.parse(source) as Record<string, Object>;
  if (raw['format'] !== 'hmkit-schema') throw new Error('Unsupported schema document format');
  if (raw['version'] !== '1.0') throw new Error(`Unsupported schema document version: ${raw['version']}`);
  if (raw['schema'] === undefined) throw new Error('Schema document is missing schema');
  return schemaFromDescriptor(raw['schema'] as SchemaDescriptor, registry);
}

class JSONSchemaImportContext {
  private root: Record<string, Object>;

  constructor(root: Record<string, Object>) { this.root = root; }

  private arrayOfSchemas(value: Object): Array<AnySchema<Object>> {
    const result: Array<AnySchema<Object>> = [];
    for (const item of value as Array<Object>) result.push(this.convert(item as Record<string, Object>));
    return result;
  }

  private reference(value: string): AnySchema<Object> {
    const prefix = '#/$defs/';
    if (!value.startsWith(prefix)) throw new Error(`Only local $defs references are supported: ${value}`);
    const definitions = this.root['$defs'] as Record<string, Object>;
    const key = value.substring(prefix.length);
    const target = definitions?.[key] as Record<string, Object>;
    if (target === undefined) throw new Error(`JSON Schema reference not found: ${value}`);
    return new LazySchema<Object>((): AnySchema<Object> => this.convert(target));
  }

  private stringSchema(node: Record<string, Object>): StringSchema {
    const schema = new StringSchema();
    if (node['minLength'] !== undefined) schema.min(node['minLength'] as number);
    if (node['maxLength'] !== undefined) schema.max(node['maxLength'] as number);
    if (node['pattern'] !== undefined) schema.pattern(new RegExp(node['pattern'] as string));
    if (node['format'] !== undefined) {
      const format = node['format'] as string;
      const plugin = getStringRule(format === 'uri' ? 'url' : format);
      if (plugin !== undefined) schema.use(plugin);
    }
    return schema;
  }

  private numberSchema(node: Record<string, Object>, integer: boolean): NumberSchema {
    const schema = new NumberSchema();
    if (integer) schema.integer();
    if (node['minimum'] !== undefined) schema.min(node['minimum'] as number);
    if (node['maximum'] !== undefined) schema.max(node['maximum'] as number);
    return schema;
  }

  private objectSchema(node: Record<string, Object>): AnySchema<Object> {
    const properties = node['properties'] as Record<string, Object> | undefined;
    const additional = node['additionalProperties'];
    if ((properties === undefined || Object.keys(properties).length === 0) &&
      additional !== undefined && typeof additional === 'object') {
      return new RecordSchema<Object>(this.convert(additional as Record<string, Object>));
    }
    const requiredObjects = node['required'] as Array<Object> | undefined;
    const required: Array<string> = [];
    if (requiredObjects !== undefined) for (const key of requiredObjects) required.push(key as string);
    const shape: SchemaShape = {};
    if (properties !== undefined) {
      for (const key of Object.keys(properties)) {
        const child = this.convert(properties[key] as Record<string, Object>);
        shape[key] = required.indexOf(key) === -1 ? child : new RequiredPropertySchema(child);
      }
    }
    let schema = new ObjectSchema<Record<string, Object>>(shape);
    const optional: Array<string> = [];
    for (const key of Object.keys(shape)) if (required.indexOf(key) === -1) optional.push(key);
    if (optional.length > 0) schema = schema.partial(optional);
    if (additional === false) schema.strict();
    return schema;
  }

  convert(node: Record<string, Object>): AnySchema<Object> {
    if (node['$ref'] !== undefined) return this.reference(node['$ref'] as string);
    if (node['const'] !== undefined) {
      if (node['const'] === null) return erase<null>(new NullSchema());
      return new JSONNonNullSchema(new LiteralSchema<Object>(node['const']), ErrorCode.LITERAL);
    }
    if (node['enum'] !== undefined) {
      const values = node['enum'] as Array<Object>;
      let acceptsNull = false;
      for (const value of values) if (value === null) acceptsNull = true;
      return !acceptsNull
        ? new JSONNonNullSchema(new EnumSchema<Object>(values), ErrorCode.ENUM)
        : new EnumSchema<Object>(values);
    }
    if (node['allOf'] !== undefined) {
      const schemas = this.arrayOfSchemas(node['allOf']);
      if (schemas.length === 0) return erase<Object | null>(new AnyValueSchema());
      let result = schemas[0];
      for (let i = 1; i < schemas.length; i++) result = new IntersectionSchema<Object>(result, schemas[i]);
      return result;
    }
    const alternatives = node['anyOf'] ?? node['oneOf'];
    if (alternatives !== undefined) return new UnionSchema<Object>(this.arrayOfSchemas(alternatives));
    const type = node['type'];
    if (type === 'string') return new JSONNonNullSchema(this.stringSchema(node) as AnySchema<Object>,
      ErrorCode.TYPE_STRING);
    if (type === 'number') return new JSONNonNullSchema(this.numberSchema(node, false) as AnySchema<Object>,
      ErrorCode.TYPE_NUMBER);
    if (type === 'integer') return new JSONNonNullSchema(this.numberSchema(node, true) as AnySchema<Object>,
      ErrorCode.TYPE_NUMBER);
    if (type === 'boolean') return new JSONNonNullSchema(new BooleanSchema() as AnySchema<Object>,
      ErrorCode.TYPE_BOOLEAN);
    if (type === 'null') return erase<null>(new NullSchema());
    if (type === 'array') {
      const item = node['items'] === undefined ? erase<Object | null>(new AnyValueSchema())
        : this.convert(node['items'] as Record<string, Object>);
      const schema = new ArraySchema<Object>(item);
      if (node['minItems'] !== undefined) schema.min(node['minItems'] as number);
      if (node['maxItems'] !== undefined) schema.max(node['maxItems'] as number);
      return new JSONNonNullSchema(schema as AnySchema<Object>, ErrorCode.TYPE_ARRAY);
    }
    if (type === 'object' || node['properties'] !== undefined) {
      return new JSONNonNullSchema(this.objectSchema(node), ErrorCode.TYPE_OBJECT);
    }
    return erase<Object | null>(new AnyValueSchema());
  }
}

/** 导入常用 JSON Schema Draft 2020-12 子集；未知关键字保持宽松，不伪造业务回调。 */
export function fromJSONSchema(source: Record<string, Object>): AnySchema<Object> {
  return new JSONSchemaImportContext(source).convert(source);
}
