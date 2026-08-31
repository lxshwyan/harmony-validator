import { AnySchema, SchemaDescriptor, SchemaDocument, SchemaMetadata, SchemaRuleDescriptor } from './types';

/** 每个内置 Schema 使用的轻量文档状态，不参与实际校验。 */
export class SchemaDocs {
  private metadata?: SchemaMetadata;
  private labelValue: string = '';
  private rules: Array<SchemaRuleDescriptor> = [];

  meta(value: SchemaMetadata): void {
    const copy: SchemaMetadata = {};
    copy.id = value.id;
    copy.title = value.title;
    copy.description = value.description;
    copy.examples = value.examples === undefined ? undefined : value.examples.slice();
    copy.deprecated = value.deprecated;
    this.metadata = copy;
  }

  describe(description: string): void {
    if (this.metadata === undefined) {
      this.metadata = { description };
    } else {
      this.metadata.description = description;
    }
  }

  label(value: string): void {
    this.labelValue = value;
  }

  rule(name: string, value?: Object, detail?: string, asyncRule?: boolean, standard?: boolean): void {
    this.rules.push(new SchemaRuleDescriptor(name, value, detail, asyncRule, standard));
  }

  replaceRule(name: string, value?: Object, detail?: string, asyncRule?: boolean, standard?: boolean): void {
    const next: Array<SchemaRuleDescriptor> = [];
    for (const rule of this.rules) {
      if (rule.name !== name) {
        next.push(rule);
      }
    }
    next.push(new SchemaRuleDescriptor(name, value, detail, asyncRule, standard));
    this.rules = next;
  }

  copy(): SchemaDocs {
    const result = new SchemaDocs();
    const metadata = this.metadataCopy();
    if (metadata !== undefined) result.meta(metadata);
    if (this.labelValue !== '') result.label(this.labelValue);
    for (const rule of this.rules) {
      result.rule(rule.name, rule.value, rule.detail, rule.async, rule.standard);
    }
    return result;
  }

  private metadataCopy(): SchemaMetadata | undefined {
    if (this.metadata === undefined) {
      return undefined;
    }
    const copy: SchemaMetadata = {};
    copy.id = this.metadata.id;
    copy.title = this.metadata.title;
    copy.description = this.metadata.description;
    copy.examples = this.metadata.examples === undefined ? undefined : this.metadata.examples.slice();
    copy.deprecated = this.metadata.deprecated;
    return copy;
  }

  build(kind: string, required?: boolean, conditionallyRequired?: boolean): SchemaDescriptor {
    const result = new SchemaDescriptor(kind);
    result.metadata = this.metadataCopy();
    if (this.labelValue !== '') {
      result.label = this.labelValue;
    }
    result.required = required ?? false;
    result.conditionallyRequired = conditionallyRequired ?? false;
    const rules: Array<SchemaRuleDescriptor> = [];
    for (const rule of this.rules) {
      rules.push(new SchemaRuleDescriptor(rule.name, rule.value, rule.detail, rule.async, rule.standard));
    }
    result.rules = rules;
    return result;
  }
}

/** 取得结构描述；第三方 Schema 会得到 kind=custom 的明确占位。 */
export function schemaToDescriptor<T>(schema: AnySchema<T>): SchemaDescriptor {
  if (schema.describeSchema !== undefined) {
    return schema.describeSchema();
  }
  const result = new SchemaDescriptor('custom');
  result.unrepresentable.push('third-party-schema');
  return result;
}

class NullJsonSchema {
  type: string = 'null';
}

function applyMetadata(target: Record<string, Object>, metadata?: SchemaMetadata): void {
  if (metadata === undefined) {
    return;
  }
  if (metadata.id !== undefined) {
    target['$id'] = metadata.id;
  }
  if (metadata.title !== undefined) {
    target['title'] = metadata.title;
  }
  if (metadata.description !== undefined) {
    target['description'] = metadata.description;
  }
  if (metadata.examples !== undefined) {
    target['examples'] = metadata.examples;
  }
  if (metadata.deprecated !== undefined) {
    target['deprecated'] = metadata.deprecated;
  }
}

function addUnrepresentable(target: Record<string, Object>, items: Array<string>, mode: string): void {
  if (items.length === 0 || mode === 'ignore') {
    return;
  }
  if (mode === 'throw') {
    throw new Error(`Schema contains unrepresentable rules: ${items.join(', ')}`);
  }
  target['x-hmkit-unrepresentable'] = items;
}

function pushUnique(values: Array<string>, value: string): void {
  if (values.indexOf(value) === -1) {
    values.push(value);
  }
}

function setLowerBound(target: Record<string, Object>, key: string, value: number): void {
  const current = target[key];
  if (current === undefined || value > (current as number)) {
    target[key] = value;
  }
}

function setUpperBound(target: Record<string, Object>, key: string, value: number): void {
  const current = target[key];
  if (current === undefined || value < (current as number)) {
    target[key] = value;
  }
}

function ruleToJSON(target: Record<string, Object>, rule: SchemaRuleDescriptor,
  extensions: Array<string>, patterns: Array<string>): void {
  if (rule.name === 'minLength') {
    setLowerBound(target, 'minLength', rule.value as number);
  } else if (rule.name === 'maxLength') {
    setUpperBound(target, 'maxLength', rule.value as number);
  } else if (rule.name === 'pattern') {
    patterns.push(rule.value as string);
    if (rule.detail !== undefined && rule.detail !== '') {
      pushUnique(extensions, `pattern-flags:${rule.detail}`);
    }
  } else if (rule.name === 'minimum') {
    setLowerBound(target, 'minimum', rule.value as number);
  } else if (rule.name === 'maximum') {
    setUpperBound(target, 'maximum', rule.value as number);
  } else if (rule.name === 'integer') {
    target['type'] = 'integer';
  } else if (rule.name === 'exclusiveMinimum') {
    setLowerBound(target, 'exclusiveMinimum', rule.value as number);
  } else if (rule.name === 'minItems') {
    setLowerBound(target, 'minItems', rule.value as number);
  } else if (rule.name === 'maxItems') {
    setUpperBound(target, 'maxItems', rule.value as number);
  } else if (rule.name === 'const') {
    target['const'] = rule.value as Object;
  } else if (rule.name === 'format') {
    target['format'] = rule.value as Object;
  } else {
    pushUnique(extensions, rule.detail === undefined || rule.detail === '' ? rule.name : `${rule.name}:${rule.detail}`);
  }
}

function applyPatterns(target: Record<string, Object>, patterns: Array<string>): void {
  if (patterns.length === 1) {
    target['pattern'] = patterns[0];
    return;
  }
  if (patterns.length > 1) {
    const allOf: Array<Object> = [];
    for (const pattern of patterns) {
      const item: Record<string, Object> = {};
      item['pattern'] = pattern;
      allOf.push(item);
    }
    target['allOf'] = allOf;
  }
}

class JSONConversionContext {
  mode: string;
  root: SchemaDescriptor;
  active: Array<SchemaDescriptor> = [];
  definitionIds: Array<string> = [];
  definitionFingerprints: Array<string> = [];
  definitions: Record<string, Object> = {};

  constructor(mode: string, root: SchemaDescriptor) {
    this.mode = mode;
    this.root = root;
  }

  definitionKey(id: string, source: SchemaDescriptor): string {
    const existing = this.definitionIds.indexOf(id);
    let fingerprint = '';
    try {
      fingerprint = JSON.stringify(source);
    } catch (_error) {
      // 循环 descriptor 无法直接 stringify；循环本身由 active/root 检测处理。
    }
    if (existing !== -1) {
      const previous = this.definitionFingerprints[existing];
      if (previous !== '' && fingerprint !== '' && previous !== fingerprint) {
        throw new Error(`Duplicate schema metadata.id has conflicting definitions: ${id}`);
      }
      return `schema${existing + 1}`;
    }
    this.definitionIds.push(id);
    this.definitionFingerprints.push(fingerprint);
    return `schema${this.definitionIds.length}`;
  }
}

function referenceJSON(reference: string): Record<string, Object> {
  const result: Record<string, Object> = {};
  result['$ref'] = reference;
  return result;
}

function discriminatorConstraint(field: string, key: string): Record<string, Object> {
  const tagSchema: Record<string, Object> = {};
  const numeric = Number(key);
  if (Number.isFinite(numeric) && `${numeric}` === key) {
    const values: Array<Object> = [];
    const stringValue: Record<string, Object> = {};
    stringValue['const'] = key;
    values.push(stringValue);
    const numberValue: Record<string, Object> = {};
    numberValue['const'] = numeric;
    values.push(numberValue);
    tagSchema['anyOf'] = values;
  } else {
    tagSchema['const'] = key;
  }
  const properties: Record<string, Object> = {};
  properties[field] = tagSchema;
  const constraint: Record<string, Object> = {};
  constraint['type'] = 'object';
  constraint['properties'] = properties;
  constraint['required'] = [field];
  return constraint;
}

function descriptorToJSON(source: SchemaDescriptor, context: JSONConversionContext,
  rootCall?: boolean): Record<string, Object> {
  const isRoot = rootCall ?? false;
  if (!isRoot && source === context.root) {
    if (source.metadata?.id === undefined) {
      throw new Error('Circular schema descriptor requires metadata.id');
    }
    return referenceJSON('#');
  }
  if (context.active.indexOf(source) !== -1) {
    if (source.metadata?.id === undefined) {
      throw new Error('Circular schema descriptor requires metadata.id');
    }
    const key = context.definitionKey(source.metadata.id, source);
    return referenceJSON(`#/$defs/${key}`);
  }
  if (!isRoot && source.metadata?.id !== undefined) {
    const existing = context.definitionIds.indexOf(source.metadata.id);
    if (existing !== -1) {
      const existingKey = context.definitionKey(source.metadata.id, source);
      return referenceJSON(`#/$defs/${existingKey}`);
    }
    const key = context.definitionKey(source.metadata.id, source);
    const placeholder: Record<string, Object> = {};
    context.definitions[key] = placeholder;
    context.active.push(source);
    const definition = descriptorToJSONBody(source, context);
    context.active.pop();
    context.definitions[key] = definition;
    return referenceJSON(`#/$defs/${key}`);
  }
  context.active.push(source);
  const result = descriptorToJSONBody(source, context);
  context.active.pop();
  return result;
}

function descriptorToJSONBody(source: SchemaDescriptor, context: JSONConversionContext): Record<string, Object> {
  const mode = context.mode;
  let target: Record<string, Object> = {};
  const extensions: Array<string> = source.unrepresentable.slice();
  const patterns: Array<string> = [];

  if (source.kind === 'string') {
    target['type'] = 'string';
  } else if (source.kind === 'number') {
    target['type'] = 'number';
  } else if (source.kind === 'boolean') {
    target['type'] = 'boolean';
  } else if (source.kind === 'date') {
    let strict = false;
    for (const rule of source.rules) {
      strict = strict || rule.name === 'strict-date';
    }
    const stringSchema: Record<string, Object> = {};
    stringSchema['type'] = 'string';
    if (strict) {
      stringSchema['x-hmkit-format'] = 'date-or-date-time';
    }
    const numberSchema: Record<string, Object> = {};
    numberSchema['type'] = 'number';
    const anyOf: Array<Object> = [];
    anyOf.push(stringSchema);
    anyOf.push(numberSchema);
    target['anyOf'] = anyOf;
    target['x-hmkit-input-types'] = ['Date', 'number', 'string'];
  } else if (source.kind === 'enum') {
    const values: Array<Object> = [];
    for (const rule of source.rules) {
      if (rule.name === 'enum' && rule.value !== undefined) {
        values.push(rule.value);
      }
    }
    target['enum'] = values;
  } else if (source.kind === 'literal') {
    target['const'] = source.value as Object;
  } else if (source.kind === 'array') {
    target['type'] = 'array';
    if (source.items !== undefined) {
      target['items'] = descriptorToJSON(source.items, context);
    }
  } else if (source.kind === 'record') {
    target['type'] = 'object';
    if (source.items !== undefined) {
      target['additionalProperties'] = descriptorToJSON(source.items, context);
    }
  } else if (source.kind === 'tuple') {
    target['type'] = 'array';
    const prefixItems: Array<Object> = [];
    for (const item of source.tupleItems) {
      prefixItems.push(descriptorToJSON(item, context));
    }
    target['prefixItems'] = prefixItems;
    target['minItems'] = source.tupleItems.length;
    target['maxItems'] = source.tupleItems.length;
  } else if (source.kind === 'object') {
    target['type'] = 'object';
    const properties: Record<string, Object> = {};
    const required: Array<Object> = [];
    if (source.properties !== undefined) {
      for (const key of Object.keys(source.properties)) {
        const child = source.properties[key];
        properties[key] = descriptorToJSON(child, context);
        if (child.required) {
          required.push(key);
        }
        if (child.conditionallyRequired) {
          extensions.push(`conditional-required:${key}`);
        }
      }
    }
    target['properties'] = properties;
    if (required.length > 0) {
      target['required'] = required;
    }
    if (source.unknownKeys === 'strict') {
      target['additionalProperties'] = false;
    } else if (source.unknownKeys === 'strip') {
      extensions.push('strip-unknown-keys');
    }
  } else if (source.kind === 'union') {
    const anyOf: Array<Object> = [];
    for (const option of source.options) {
      anyOf.push(descriptorToJSON(option, context));
    }
    target['anyOf'] = anyOf;
  } else if (source.kind === 'discriminated-union') {
    const oneOf: Array<Object> = [];
    if (source.variants !== undefined) {
      for (const key of Object.keys(source.variants)) {
        const variant = descriptorToJSON(source.variants[key], context);
        if (source.discriminator === undefined) {
          oneOf.push(variant);
        } else {
          const branch: Record<string, Object> = {};
          const allOf: Array<Object> = [];
          allOf.push(variant);
          allOf.push(discriminatorConstraint(source.discriminator, key));
          branch['allOf'] = allOf;
          oneOf.push(branch);
        }
      }
    }
    target['oneOf'] = oneOf;
    if (source.discriminator !== undefined) {
      const discriminator: Record<string, Object> = {};
      discriminator['propertyName'] = source.discriminator;
      target['discriminator'] = discriminator;
    }
  } else if (source.kind === 'nullable') {
    if (source.inner !== undefined) {
      const anyOf: Array<Object> = [];
      anyOf.push(descriptorToJSON(source.inner, context));
      anyOf.push(new NullJsonSchema());
      target['anyOf'] = anyOf;
    }
  } else if (source.kind === 'default') {
    if (source.inner !== undefined) {
      target = descriptorToJSON(source.inner, context);
    }
    if (source.defaultValue !== undefined) {
      target['default'] = source.defaultValue;
    }
  } else if (source.kind === 'transform') {
    if (source.inner !== undefined) {
      target = descriptorToJSON(source.inner, context);
    }
  } else if (source.kind === 'preprocess') {
    if (source.inner !== undefined) {
      target = descriptorToJSON(source.inner, context);
    }
  } else {
    extensions.push(source.kind);
  }

  for (const rule of source.rules) {
    if (source.kind !== 'enum') {
      ruleToJSON(target, rule, extensions, patterns);
    }
  }
  applyPatterns(target, patterns);
  applyMetadata(target, source.metadata);
  if (source.label !== undefined) {
    target['x-hmkit-label'] = source.label;
  }
  addUnrepresentable(target, extensions, mode);
  return target;
}

/** 转为 JSON Schema Draft 2020-12 风格对象。mode: extension(默认) / throw / ignore。 */
export function toJSONSchema<T>(schema: AnySchema<T>, mode?: string): Record<string, Object> {
  const selectedMode = mode ?? 'extension';
  if (selectedMode !== 'extension' && selectedMode !== 'throw' && selectedMode !== 'ignore') {
    throw new Error(`Unsupported JSON Schema mode: ${selectedMode}`);
  }
  const descriptor = schemaToDescriptor(schema);
  const context = new JSONConversionContext(selectedMode, descriptor);
  const target = descriptorToJSON(descriptor, context, true);
  target['$schema'] = 'https://json-schema.org/draft/2020-12/schema';
  if (Object.keys(context.definitions).length > 0) target['$defs'] = context.definitions;
  return target;
}

function assertSerializableDescriptor(source: SchemaDescriptor, active: Array<SchemaDescriptor>): void {
  if (active.indexOf(source) !== -1) {
    throw new Error('Circular schema descriptor cannot be serialized; use toJSONSchema() with metadata.id references');
  }
  active.push(source);
  if (source.properties !== undefined) {
    for (const key of Object.keys(source.properties)) assertSerializableDescriptor(source.properties[key], active);
  }
  if (source.items !== undefined) assertSerializableDescriptor(source.items, active);
  for (const item of source.tupleItems) assertSerializableDescriptor(item, active);
  for (const option of source.options) assertSerializableDescriptor(option, active);
  if (source.variants !== undefined) {
    for (const key of Object.keys(source.variants)) assertSerializableDescriptor(source.variants[key], active);
  }
  if (source.inner !== undefined) assertSerializableDescriptor(source.inner, active);
  active.pop();
}

/** 稳定序列化结构描述；用于缓存、审计或跨进程传递，不承诺恢复运行时函数。 */
export function serializeSchema<T>(schema: AnySchema<T>, space?: number): string {
  const descriptor = schemaToDescriptor(schema);
  assertSerializableDescriptor(descriptor, []);
  return JSON.stringify(descriptor, null, space ?? 0);
}

/** 生成带格式名和版本号的 1.0 Schema 文档。 */
export function schemaToDocument<T>(schema: AnySchema<T>): SchemaDocument {
  return new SchemaDocument(schemaToDescriptor(schema));
}

/** 推荐的版本化序列化入口；用于未来格式迁移。 */
export function serializeSchemaDocument<T>(schema: AnySchema<T>, space?: number): string {
  const document = schemaToDocument(schema);
  assertSerializableDescriptor(document.schema, []);
  return JSON.stringify(document, null, space ?? 0);
}
