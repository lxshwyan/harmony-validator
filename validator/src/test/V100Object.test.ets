import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { SchemaDescriptor } from '../main/ets/core/types';
import { toJSONSchema } from '../main/ets/core/schema';

function data(value?: Record<string, Object>): Record<string, Object> { return value ?? {}; }

export default function v100ObjectTest(): void {
  describe('1.0 object unknown-key modes', (): void => {
    it('keeps passthrough as the backward-compatible default', 0, (): void => {
      const schema = v.object({ 'name': v.string().required() });
      const input = data({ 'name': 'Alice', 'legacy': 1 });
      expect(schema.validate(input).valid).assertTrue();
      const parsed = schema.parse(input);
      expect(parsed.success).assertTrue();
      expect((parsed.value as Record<string, Object>)['legacy']).assertEqual(1);
      expect(schema.describeSchema().unknownKeys).assertEqual('passthrough');
    });

    it('strict rejects every unknown key with stable paths and code', 0, async (): Promise<void> => {
      const schema = v.object({ 'name': v.string().required() }).strict('发现未知字段').label('用户');
      const input = data({ 'name': 'Alice', 'legacy': 1, 'extra': true });
      const result = schema.validate(input);
      expect(result.errors.length).assertEqual(2);
      expect(result.errors[0].path).assertEqual('legacy');
      expect(result.errors[0].code).assertEqual('unknown_key');
      expect(result.errors[0].message).assertEqual('用户：发现未知字段');
      expect((await schema.validateAsync(input)).errors.length).assertEqual(2);
      expect(schema.parse(input).success).assertFalse();
      expect((await schema.parseAsync(input)).success).assertFalse();
      expect(toJSONSchema(schema)['additionalProperties']).assertFalse();
    });

    it('strip accepts unknown keys but removes them from parse output', 0, async (): Promise<void> => {
      const schema = v.object({
        'name': v.string().required(),
        'size': v.string().transform<number>((value: string): number => value.length),
      }).strip();
      const input = data({ 'name': 'Alice', 'size': 'abc', 'unknown': 1 });
      expect(schema.validate(input).valid).assertTrue();
      const parsed = schema.parse(input);
      expect(parsed.success).assertTrue();
      expect((parsed.value as Record<string, Object>)['unknown']).assertUndefined();
      expect((parsed.value as Record<string, Object>)['size']).assertEqual(3);
      expect((await schema.parseAsync(input)).success).assertTrue();
      expect((toJSONSchema(schema)['x-hmkit-unrepresentable'] as Array<Object>)[0])
        .assertEqual('strip-unknown-keys');
      expect(schema.passthrough().parse(input).value !== undefined).assertTrue();
    });
  });

  describe('1.0 object composition', (): void => {
    it('partial returns an independent all-optional object schema', 0, (): void => {
      const base = v.object({ 'name': v.string().required(), 'age': v.number().required() })
        .meta({ title: '用户' }).describe('基础用户').label('用户');
      const patch = base.partial();
      expect(patch.validate(data()).valid).assertTrue();
      expect(base.validate(data()).valid).assertFalse();
      const descriptor = patch.describeSchema();
      const properties = descriptor.properties as Record<string, SchemaDescriptor>;
      expect(descriptor.optionalProperties.length).assertEqual(2);
      expect(properties['name'].required).assertFalse();
      expect(descriptor.metadata?.description).assertEqual('基础用户');
      expect(descriptor.label).assertEqual('用户');
    });

    it('partial can target selected fields only', 0, async (): Promise<void> => {
      const schema = v.object({ 'name': v.string().required(), 'age': v.number().required() })
        .partial(['age']);
      expect(schema.validate(data({ 'name': 'Alice' })).valid).assertTrue();
      expect(schema.validate(data({ 'age': 20 })).errors[0].path).assertEqual('name');
      expect((await schema.validateAsync(data({ 'name': 'Alice' }))).valid).assertTrue();
      expect(schema.parse(data({ 'name': 'Alice' })).success).assertTrue();
      expect((await schema.parseAsync(data({ 'name': 'Alice' }))).success).assertTrue();
    });

    it('pick and omit retain rules but create isolated shapes', 0, (): void => {
      const base = v.object({
        'name': v.string().required(),
        'age': v.number().required(),
        'secret': v.string().required(),
      }).partial(['age']);
      const picked = base.pick(['name', 'missing']).strip();
      const omitted = base.omit(['secret', 'missing']).strict();
      expect(Object.keys(picked.describeSchema().properties as Record<string, SchemaDescriptor>).length)
        .assertEqual(1);
      expect(Object.keys(omitted.describeSchema().properties as Record<string, SchemaDescriptor>).length)
        .assertEqual(2);
      expect(omitted.describeSchema().optionalProperties[0]).assertEqual('age');
      const pickedValue = picked.parse(data({ 'name': 'Alice', 'age': 20 }));
      expect((pickedValue.value as Record<string, Object>)['age']).assertUndefined();
      expect(omitted.validate(data({ 'name': 'Alice', 'age': 20, 'secret': 'x' })).errors[0].path)
        .assertEqual('secret');
      expect(base.describeSchema().properties?.['secret'] === undefined).assertFalse();
    });

    it('preserves optional object and refine behavior across composition', 0, (): void => {
      const base = v.object({ 'name': v.string().required() }).optional()
        .refine((value: Record<string, Object>): boolean => value['name'] !== 'blocked', '已禁用', 'name');
      expect(base.pick(['name']).validate(undefined).valid).assertTrue();
      expect(base.omit([]).validate(data({ 'name': 'blocked' })).errors[0].path).assertEqual('name');
    });
  });
}
