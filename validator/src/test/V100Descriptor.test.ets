import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { AnySchema, SchemaDescriptor, ValidateResult } from '../main/ets/core/types';
import { schemaToDocument, serializeSchema, serializeSchemaDocument, toJSONSchema } from '../main/ets/core/schema';

class CyclicDescriptorSchema implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private named: boolean;
  constructor(named: boolean) { this.named = named; }
  validate(_value: Object | null | undefined): ValidateResult { return { valid: true, errors: [] }; }
  async validateAsync(_value: Object | null | undefined): Promise<ValidateResult> {
    return { valid: true, errors: [] };
  }
  describeSchema(): SchemaDescriptor {
    const root = new SchemaDescriptor('array');
    if (this.named) root.metadata = { id: 'recursive-node' };
    root.items = root;
    return root;
  }
}

export default function v100DescriptorTest(): void {
  describe('1.0 versioned schema documents', (): void => {
    it('adds a stable format envelope without changing legacy serialization', 0, (): void => {
      const schema = v.object({ 'name': v.string().required() });
      const document = schemaToDocument(schema);
      expect(document.format).assertEqual('hmkit-schema');
      expect(document.version).assertEqual('1.0');
      expect(document.schema.kind).assertEqual('object');
      const serialized = serializeSchemaDocument(schema);
      expect(serialized.includes('"format":"hmkit-schema"')).assertTrue();
      expect(serialized.includes('"version":"1.0"')).assertTrue();
      expect(serializeSchemaDocument(schema, 2).includes('\n')).assertTrue();
      expect(serializeSchema(schema).includes('"kind":"object"')).assertTrue();
    });
  });

  describe('1.0 JSON Schema references and cycle detection', (): void => {
    it('deduplicates named nested schemas into defs and refs', 0, (): void => {
      const address = v.object({ 'city': v.string().required() }).meta({ id: 'Address' });
      const root = v.object({ 'home': address, 'work': address });
      const json = toJSONSchema(root);
      const properties = json['properties'] as Record<string, Object>;
      expect((properties['home'] as Record<string, Object>)['$ref']).assertEqual('#/$defs/schema1');
      expect((properties['work'] as Record<string, Object>)['$ref']).assertEqual('#/$defs/schema1');
      const definitions = json['$defs'] as Record<string, Object>;
      const definition = definitions['schema1'] as Record<string, Object>;
      expect(definition['type']).assertEqual('object');
      expect(definition['$id']).assertEqual('Address');
    });

    it('rejects conflicting definitions that reuse the same metadata id', 0, (): void => {
      const root = v.object({
        'text': v.string().meta({ id: 'Shared' }),
        'count': v.number().meta({ id: 'Shared' }),
      });
      let thrown = false;
      try {
        toJSONSchema(root);
      } catch (error) {
        thrown = `${error}`.includes('conflicting definitions: Shared');
      }
      expect(thrown).assertTrue();
    });

    it('keeps runtime discriminator selection explicit in every JSON Schema branch', 0, (): void => {
      const variants: Record<string, AnySchema<Record<string, Object>>> = {};
      variants['text'] = v.object({ 'value': v.string() });
      variants['1'] = v.object({ 'value': v.number() });
      const json = toJSONSchema(v.discriminatedUnion('type', variants));
      const branches = json['oneOf'] as Array<Object>;
      // JavaScript/ArkTS 会先枚举整数样式的 key，因此 "1" 分支位于 text 之前。
      const numberAllOf = (branches[0] as Record<string, Object>)['allOf'] as Array<Object>;
      const numberConstraint = numberAllOf[1] as Record<string, Object>;
      const numberProperties = numberConstraint['properties'] as Record<string, Object>;
      expect(((numberProperties['type'] as Record<string, Object>)['anyOf'] as Array<Object>).length)
        .assertEqual(2);
      const textAllOf = (branches[1] as Record<string, Object>)['allOf'] as Array<Object>;
      const textConstraint = textAllOf[1] as Record<string, Object>;
      const textProperties = textConstraint['properties'] as Record<string, Object>;
      expect((textProperties['type'] as Record<string, Object>)['const']).assertEqual('text');
      expect((textConstraint['required'] as Array<Object>)[0]).assertEqual('type');
    });

    it('uses a root reference for a named recursive descriptor', 0, (): void => {
      const json = toJSONSchema(new CyclicDescriptorSchema(true));
      expect((json['items'] as Record<string, Object>)['$ref']).assertEqual('#');
    });

    it('fails fast for an unnamed recursive descriptor', 0, (): void => {
      let thrown = false;
      try {
        toJSONSchema(new CyclicDescriptorSchema(false));
      } catch (error) {
        thrown = `${error}`.includes('Circular schema descriptor');
      }
      expect(thrown).assertTrue();
    });

    it('gives an explicit migration hint when serializing cycles', 0, (): void => {
      let thrown = false;
      try {
        serializeSchemaDocument(new CyclicDescriptorSchema(true));
      } catch (error) {
        thrown = `${error}`.includes('use toJSONSchema()');
      }
      expect(thrown).assertTrue();
    });
  });
}
