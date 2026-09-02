import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { AnySchema, SchemaDescriptor } from '../main/ets/core/types';
import { serializeSchemaDocument } from '../main/ets/core/schema';
import {
  SchemaRegistry, deserializeSchemaDocument, fromJSONSchema, schemaFromDescriptor
} from '../main/ets/core/interop';

function record(value?: Record<string, Object>): Record<string, Object> { return value ?? {}; }
function array(values: Array<Object>): Array<Object> { return values; }

function expectThrow(fn: () => void): boolean {
  try { fn(); } catch (_error) { return true; }
  return false;
}

export default function v110InteropTest(): void {
  describe('1.1 schema document restoration', (): void => {
    it('round trips object rules, optional properties and unknown-key policy', 0, (): void => {
      const source = v.object({
        'name': v.string().required().min(2).max(8),
        'age': v.number().required().min(18).max(100).integer(),
        'tags': v.array(v.string().min(1)).min(1).max(3),
      }).partial(['tags']).strict();
      const restored = deserializeSchemaDocument(serializeSchemaDocument(source));
      expect(restored.validate(record({ 'name': 'hmkit', 'age': 20 })).valid).assertTrue();
      expect(restored.validate(record({ 'name': 'x', 'age': 20 })).valid).assertFalse();
      expect(restored.validate(record({ 'name': 'hmkit', 'age': 20, 'extra': true })).errors[0].code)
        .assertEqual('unknown_key');
    });

    it('restores primitive, enum, literal and date descriptors', 0, (): void => {
      expect(schemaFromDescriptor(v.boolean().required().isTrue().describeSchema()).validate(false).valid).assertFalse();
      expect(schemaFromDescriptor(v.date().required().strict().min('2020-01-01').max('2030-01-01')
        .describeSchema()).validate('2025-01-01').valid).assertTrue();
      expect(schemaFromDescriptor(v.enumOf<Object>(['a', 'b']).describeSchema()).validate('b').valid).assertTrue();
      expect(schemaFromDescriptor(v.literal<Object>('fixed').describeSchema()).validate('fixed').valid).assertTrue();
      expect(schemaFromDescriptor(v.any().describeSchema()).validate(null).valid).assertTrue();
      expect(schemaFromDescriptor(v.unknown().describeSchema()).validate('x').valid).assertTrue();
      expect(schemaFromDescriptor(v.never().describeSchema()).validate('x').valid).assertFalse();
      expect(schemaFromDescriptor(v.null().describeSchema()).validate(null).valid).assertTrue();
    });

    it('restores record, tuple, union, intersection and wrappers', 0, (): void => {
      expect(schemaFromDescriptor(v.record(v.string().min(2)).describeSchema())
        .validate(record({ 'a': 'ok' })).valid).assertTrue();
      expect(schemaFromDescriptor(v.tuple([v.string(), v.number()]).describeSchema())
        .validate(['x', 1]).valid).assertTrue();
      expect(schemaFromDescriptor(v.union<Object>([v.string(), v.number()]).describeSchema())
        .validate(1).valid).assertTrue();
      expect(schemaFromDescriptor(v.intersection<Record<string, Object>>(
        v.object({ 'a': v.string().required() }), v.object({ 'b': v.number().required() })
      ).describeSchema()).validate(record({ 'a': 'x', 'b': 1 })).valid).assertTrue();
      expect(schemaFromDescriptor(v.string().nullable().describeSchema()).validate(null).valid).assertTrue();
      expect(schemaFromDescriptor(v.string().default('x').describeSchema()).validate(undefined).valid).assertTrue();
    });

    it('restores discriminated unions and non-recursive lazy schemas', 0, (): void => {
      const variants: Record<string, AnySchema<Record<string, Object>>> = {};
      variants['a'] = v.object({ 'type': v.literal('a'), 'value': v.string() });
      variants['b'] = v.object({ 'type': v.literal('b'), 'value': v.number() });
      const union = v.discriminatedUnion('type', variants);
      expect(schemaFromDescriptor(union.describeSchema()).validate(record({ 'type': 'b', 'value': 1 })).valid)
        .assertTrue();
      const lazy = v.lazy<string>((): AnySchema<string> => v.string().min(2));
      expect(schemaFromDescriptor(lazy.describeSchema()).validate('ok').valid).assertTrue();
    });

    it('supports custom kind factories and deterministic document errors', 0, (): void => {
      const registry = new SchemaRegistry();
      registry.register('business-id', (_descriptor: SchemaDescriptor,
        _registry: SchemaRegistry): AnySchema<Object> => v.string().min(3) as AnySchema<Object>);
      expect(registry.create(new SchemaDescriptor('business-id')).validate('abc').valid).assertTrue();
      expect(registry.unregister('business-id')).assertTrue();
      expect(expectThrow((): void => { registry.create(new SchemaDescriptor('business-id')); })).assertTrue();
      expect(expectThrow((): void => { deserializeSchemaDocument('{"format":"bad","version":"1.0","schema":{}}'); }))
        .assertTrue();
      expect(expectThrow((): void => { deserializeSchemaDocument('{"format":"hmkit-schema","version":"2.0","schema":{}}'); }))
        .assertTrue();
      expect(expectThrow((): void => { deserializeSchemaDocument('{"format":"hmkit-schema","version":"1.0"}'); }))
        .assertTrue();
      expect(expectThrow((): void => { schemaFromDescriptor(v.string().transform<string>(
        (value: string): string => value).describeSchema()); })).assertTrue();
    });

    it('preserves nullable parse values and required-property parse behavior', 0, async (): Promise<void> => {
      const nullable = schemaFromDescriptor(v.string().nullable().describeSchema());
      expect(nullable.parse?.(null).success).assertTrue();
      expect((await nullable.parseAsync?.(null))?.success).assertTrue();
      const document = serializeSchemaDocument(v.object({ 'name': v.string().required() }));
      const restored = deserializeSchemaDocument(document);
      expect(restored.parse?.(record()).success).assertFalse();
      expect((await restored.parseAsync?.(record({ 'name': 'ok' })))?.success).assertTrue();

    });
  });

  describe('1.1 JSON Schema import', (): void => {
    it('imports object properties, required fields and strict unknown keys', 0, (): void => {
      const name = record({ 'type': 'string', 'minLength': 2, 'maxLength': 8, 'pattern': '^[a-z]+$' });
      const age = record({ 'type': 'integer', 'minimum': 18, 'maximum': 100 });
      const properties = record({ 'name': name, 'age': age });
      const json = record({ 'type': 'object', 'properties': properties, 'required': array(['name']),
        'additionalProperties': false });
      const schema = fromJSONSchema(json);
      expect(schema.validate(record({ 'name': 'hmkit' })).valid).assertTrue();
      expect(schema.validate(record({ 'age': 20 })).valid).assertFalse();
      expect(schema.validate(record({ 'name': 'HM', 'extra': true })).valid).assertFalse();
      const nullName = JSON.parse('{"name":null}') as Record<string, Object>;
      expect(schema.validate(nullName).valid).assertFalse();
      expect(schema.parse?.(nullName).success).assertFalse();
      expect(schema.validate(null).valid).assertFalse();
    });

    it('imports arrays, enums, constants and null', 0, (): void => {
      const items = record({ 'enum': array(['a', 'b']) });
      const schema = fromJSONSchema(record({ 'type': 'array', 'items': items, 'minItems': 1, 'maxItems': 2 }));
      expect(schema.validate(['a']).valid).assertTrue();
      expect(schema.validate([]).valid).assertFalse();
      expect(fromJSONSchema(record({ 'const': 'fixed' })).validate('fixed').valid).assertTrue();
      expect(fromJSONSchema(record({ 'type': 'null' })).validate(null).valid).assertTrue();
      const nullConst = JSON.parse('{"const":null}') as Record<string, Object>;
      expect(fromJSONSchema(nullConst).validate(null).valid).assertTrue();
      expect(fromJSONSchema(record({ 'const': 'fixed' })).validate(null).valid).assertFalse();
      expect(fromJSONSchema(record({ 'type': 'boolean' })).validate(null).valid).assertFalse();
      expect(fromJSONSchema(record({ 'type': 'array' })).validate(null).valid).assertFalse();
      expect(fromJSONSchema(record()).validate(record()).valid).assertTrue();
      expect(fromJSONSchema(record({ 'type': 'array' })).validate([record()]).valid).assertTrue();
      expect(fromJSONSchema(record({ 'type': 'boolean' })).validate(true).valid).assertTrue();
      expect(fromJSONSchema(record({ 'type': 'string', 'format': 'not-registered' })).validate('x').valid)
        .assertTrue();
    });

    it('imports anyOf, oneOf and allOf composition', 0, (): void => {
      const text = record({ 'type': 'string', 'minLength': 2 });
      const number = record({ 'type': 'number', 'minimum': 1 });
      expect(fromJSONSchema(record({ 'anyOf': array([text, number]) })).validate('ok').valid).assertTrue();
      expect(fromJSONSchema(record({ 'oneOf': array([text, number]) })).validate(2).valid).assertTrue();
      const a = record({ 'type': 'object', 'properties': record({ 'a': record({ 'type': 'string' }) }),
        'required': array(['a']) });
      const b = record({ 'type': 'object', 'properties': record({ 'b': record({ 'type': 'number' }) }),
        'required': array(['b']) });
      expect(fromJSONSchema(record({ 'allOf': array([a, b]) })).validate(record({ 'a': 'x', 'b': 1 })).valid)
        .assertTrue();
      expect(fromJSONSchema(record({ 'allOf': array([]) })).validate('anything').valid).assertTrue();
    });

    it('imports records, registered formats and local references', 0, (): void => {
      const recordSchema = fromJSONSchema(record({ 'type': 'object',
        'additionalProperties': record({ 'type': 'string', 'format': 'email' }) }));
      expect(recordSchema.validate(record({ 'mail': 'a@example.com' })).valid).assertTrue();
      expect(recordSchema.validate(record({ 'mail': 'bad' })).valid).assertFalse();

      const defs = record({ 'Name': record({ 'type': 'string', 'minLength': 2 }) });
      const root = record({ '$defs': defs, '$ref': '#/$defs/Name' });
      expect(fromJSONSchema(root).validate('ok').valid).assertTrue();
      expect(expectThrow((): void => { fromJSONSchema(record({ '$ref': '#/bad' })).validate('x'); })).assertTrue();
      expect(expectThrow((): void => { fromJSONSchema(record({ '$defs': record(), '$ref': '#/$defs/Missing' }))
        .validate('x'); })).assertTrue();
    });
  });
}
