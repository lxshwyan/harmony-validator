import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { AnySchema, ParseResult, SchemaMetadata, ValidateResult } from '../main/ets/core/types';
import { toJSONSchema } from '../main/ets/core/schema';

function objectRecord(value?: Record<string, Object>): Record<string, Object> {
  return value ?? {};
}

export default function v100SchemasTest(): void {
  describe('1.0 record schema', (): void => {
    it('validates every property and keeps stable nested paths', 0, (): void => {
      const schema = v.record(v.object({ 'name': v.string().required().min(2) }));
      const good = objectRecord();
      good['first'] = objectRecord({ 'name': 'Alice' });
      expect(schema.validate(good).valid).assertTrue();
      const bad = objectRecord();
      bad['first'] = objectRecord({ 'name': 'A' });
      bad['second'] = objectRecord();
      const result = schema.validate(bad);
      expect(result.valid).assertFalse();
      expect(result.errors[0].path).assertEqual('first.name');
      expect(result.errors[1].path).assertEqual('second.name');
    });

    it('handles required, optional and invalid object inputs', 0, (): void => {
      expect(v.record(v.string()).validate(undefined).valid).assertFalse();
      expect(v.record(v.string()).optional().validate(undefined).valid).assertTrue();
      expect(v.record(v.string()).optional().required('必须填写').validate(undefined).errors[0].message)
        .assertEqual('必须填写');
      expect(v.record(v.string()).validate([]).errors[0].code).assertEqual('type_object');
      expect(v.record(v.string()).validate(new Date()).errors[0].code).assertEqual('type_object');
    });

    it('parses transformed values synchronously and asynchronously', 0, async (): Promise<void> => {
      const schema = v.record(v.string().transform<number>((value: string): number => value.length));
      const input = objectRecord({ 'a': 'hi', 'b': 'hello' });
      const parsed = schema.parse(input);
      expect(parsed.success).assertTrue();
      expect((parsed.value as Record<string, number>)['a']).assertEqual(2);
      const asyncParsed = await schema.parseAsync(input);
      expect((asyncParsed.value as Record<string, number>)['b']).assertEqual(5);
      expect((await schema.validateAsync(input)).valid).assertTrue();
      expect((await schema.validateAsync(objectRecord({ 'a': 1 }))).errors[0].path).assertEqual('a');
    });

    it('supports metadata, wrappers and JSON Schema additionalProperties', 0, (): void => {
      const metadata: SchemaMetadata = { title: '字典' };
      const schema = v.record(v.number()).meta(metadata).describe('数字字典').label('配置');
      expect(schema.describeSchema().metadata?.description).assertEqual('数字字典');
      expect(schema.describeSchema().label).assertEqual('配置');
      expect((toJSONSchema(schema)['additionalProperties'] as Record<string, Object>)['type']).assertEqual('number');
      expect(schema.nullable().validate(null).valid).assertTrue();
      const emptyNumbers: Record<string, number> = {};
      expect(schema.default(emptyNumbers).parse(undefined).success).assertTrue();
      expect(schema.transform<number>((value: Record<string, number>): number => Object.keys(value).length)
        .parse(objectRecord({ 'a': 1 })).value).assertEqual(1);
    });
  });

  describe('1.0 tuple schema', (): void => {
    it('validates fixed length and positional paths', 0, (): void => {
      const schema = v.tuple([v.string().required(), v.number().min(1)]);
      expect(schema.validate(['ok', 2]).valid).assertTrue();
      expect(schema.validate(['ok']).errors[0].code).assertEqual('tuple_length');
      expect(schema.validate(['ok', 0]).errors[0].path).assertEqual('1');
      expect(schema.validate('not-array').errors[0].code).assertEqual('type_array');
    });

    it('supports optional, required, parse and async parse', 0, async (): Promise<void> => {
      const optional = v.tuple([]).optional();
      expect(optional.validate(undefined).valid).assertTrue();
      expect(optional.required('元组必填').validate(undefined).errors[0].message).assertEqual('元组必填');
      const schema = v.tuple([
        v.string().transform<number>((value: string): number => value.length),
        v.number().customAsync((value: number): Promise<boolean> => Promise.resolve(value > 0), '必须大于0'),
      ]);
      expect(schema.parse(['abc', 1]).value?.[0]).assertEqual(3);
      expect((await schema.parseAsync(['abc', 1])).success).assertTrue();
      expect((await schema.validateAsync(['abc', -1])).errors[0].path).assertEqual('1');
    });

    it('describes tuple positions and maps prefixItems', 0, (): void => {
      const schema = v.tuple([v.string(), v.number()]).meta({ title: '坐标' }).describe('二维坐标').label('坐标');
      expect(schema.describeSchema().tupleItems.length).assertEqual(2);
      const json = toJSONSchema(schema);
      expect((json['prefixItems'] as Array<Object>).length).assertEqual(2);
      expect(json['minItems']).assertEqual(2);
      expect(json['maxItems']).assertEqual(2);
      expect(schema.nullable().validate(null).valid).assertTrue();
      expect(schema.default(['x', 1]).parse(undefined).success).assertTrue();
      expect(schema.transform<number>((value: Array<Object>): number => value.length).parse(['x', 1]).value)
        .assertEqual(2);
    });
  });

  describe('1.0 discriminated union schema', (): void => {
    it('selects a matching object schema without trying other variants', 0, (): void => {
      const variants: Record<string, AnySchema<Record<string, Object>>> = {};
      variants['text'] = v.object({ 'type': v.literal('text').required(), 'value': v.string().required() });
      variants['count'] = v.object({ 'type': v.literal('count').required(), 'value': v.number().required() });
      const schema = v.discriminatedUnion('type', variants);
      expect(schema.validate(objectRecord({ 'type': 'text', 'value': 'ok' })).valid).assertTrue();
      expect(schema.validate(objectRecord({ 'type': 'count', 'value': 'bad' })).errors[0].path)
        .assertEqual('value');
    });

    it('returns stable discriminator and object errors', 0, (): void => {
      const variants: Record<string, AnySchema<Record<string, Object>>> = {};
      variants['a'] = v.object({ 'type': v.literal('a') });
      const schema = v.discriminatedUnion('type', variants, '类型不支持').label('事件');
      expect(schema.validate(objectRecord({ 'type': 'missing' })).errors[0].path).assertEqual('type');
      expect(schema.validate(objectRecord({ 'type': 'missing' })).errors[0].message).assertEqual('事件：类型不支持');
      expect(schema.validate('bad').errors[0].code).assertEqual('type_object');
      expect(schema.validate(null).errors[0].code).assertEqual('discriminator');
    });

    it('supports async selection, parse, wrappers and descriptors', 0, async (): Promise<void> => {
      const variants: Record<string, AnySchema<Record<string, Object>>> = {};
      variants['job'] = v.object({
        'type': v.literal('job'),
        'name': v.string().customAsync((value: string): Promise<boolean> => Promise.resolve(value === 'ok'), 'bad'),
      });
      const schema = v.discriminatedUnion('type', variants).meta({ title: '事件' }).describe('事件联合');
      const good = objectRecord({ 'type': 'job', 'name': 'ok' });
      expect((await schema.validateAsync(good)).valid).assertTrue();
      expect(schema.parse(good).success).assertTrue();
      expect((await schema.parseAsync(good)).success).assertTrue();
      expect(schema.describeSchema().variants?.['job'].kind).assertEqual('object');
      const json = toJSONSchema(schema);
      expect((json['oneOf'] as Array<Object>).length).assertEqual(1);
      expect((json['discriminator'] as Record<string, Object>)['propertyName']).assertEqual('type');
      expect(schema.nullable().validate(null).valid).assertTrue();
      expect(schema.default(good).parse(undefined).success).assertTrue();
      expect(schema.transform<string>((value: Record<string, Object>): string => value['type'] as string)
        .parse(good).value).assertEqual('job');
    });
  });
}
