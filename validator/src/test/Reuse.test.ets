import { describe, expect, it } from '@ohos/hypium';
import { liteV } from '../main/ets/lite';
import { StringSchema } from '../main/ets/schemas/StringSchema';
import { ObjectSchema } from '../main/ets/schemas/ObjectSchema';
import { SchemaFactory } from '../main/ets/core/SchemaFactory';
import { LazySchema } from '../main/ets/schemas/CompositionSchemas';
import { AnySchema } from '../main/ets/core/types';
import { TransformSchema, NullableSchema } from '../main/ets/schemas/EffectSchemas';

interface NullableValue { value: string | null; }

export default function reuseTest(): void {
  describe('Schema factory construction isolation', (): void => {
    it('accepts nullable schemas inside typed object shapes', 0, async (): Promise<void> => {
      const schema = liteV.object<NullableValue>({ 'value': liteV.string().required().nullable() });
      const input: NullableValue = { value: null };
      expect(schema.parse(input).value?.value).assertEqual(null);
      expect((await schema.parseAsync(input)).value?.value).assertEqual(null);
    });
    it('replays independent scalar variants without mutating the base', 0, (): void => {
      const base = new SchemaFactory<StringSchema>((): StringSchema => liteV.string().required());
      const short = base.derive((s: StringSchema): StringSchema => s.max(2));
      const long = base.derive((s: StringSchema): StringSchema => s.max(20));
      expect(short.create().validate('long').valid).assertFalse();
      expect(long.create().validate('long').valid).assertTrue();
      expect(base.create().validate('long').valid).assertTrue();
      expect(base.derive((s: StringSchema): StringSchema => s.optional()).create().validate('').valid).assertTrue();
      expect(base.create().validate('').valid).assertFalse();
    });
    it('creates fresh nested children, arrays and union branches', 0, (): void => {
      const children: StringSchema[] = [];
      const base = new SchemaFactory<ObjectSchema<Record<string, Object>>>((): ObjectSchema<Record<string, Object>> => {
        const branch = liteV.string().min(2); children.push(branch);
        return liteV.object({ 'rows': liteV.array(liteV.object({ 'value': liteV.union([branch, liteV.string().min(3)]) })) });
      });
      const a = base.create(); const b = base.create();
      const row: Record<string, Object> = { 'value': 'ab' };
      const value: Record<string, Object> = { 'rows': [row] };
      expect(a === b).assertFalse();
      expect(a.validate(value).valid).assertTrue();
      expect(b.validate(value).valid).assertTrue();
      children[0].max(1);
      expect(a.validate(value).valid).assertFalse();
      expect(b.validate(value).valid).assertTrue();
    });
    it('preserves recursive graphs, callbacks and metadata by replaying construction', 0, (): void => {
      let calls = 0;
      const factory = new SchemaFactory<LazySchema<Record<string, Object>>>((): LazySchema<Record<string, Object>> => {
        const tree: LazySchema<Record<string, Object>> = new LazySchema<Record<string, Object>>(
          (): AnySchema<Record<string, Object>> => liteV.object({
            'name': liteV.string().required().custom((text: string): boolean => { calls++; return text !== 'bad'; }, 'bad name'),
            'children': liteV.array(tree)
          }).meta({ title: 'Tree' }));
        return tree;
      });
      const leaf: Record<string, Object> = { 'name': 'leaf' };
      const data: Record<string, Object> = { 'name': 'root', 'children': [leaf] };
      expect(factory.create().validate(data).valid).assertTrue();
      const bad: Record<string, Object> = { 'name': 'bad' };
      expect(factory.create().validate(bad).valid).assertFalse();
      expect(calls > 0).assertTrue();
    });
    it('keeps configuration lazy and propagates constructor failures', 0, (): void => {
      let builds = 0;
      const factory = new SchemaFactory<StringSchema>((): StringSchema => { builds++; return liteV.string(); });
      const child = factory.derive((s: StringSchema): StringSchema => s.min(2));
      expect(builds).assertEqual(0);
      child.create(); child.create();
      expect(builds).assertEqual(2);
      let thrown = false;
      try { new SchemaFactory<StringSchema>((): StringSchema => { throw new Error('build'); }).create(); }
      catch (_error) { thrown = true; }
      expect(thrown).assertTrue();
    });
    it('preserves changed output types and nullable factory variants', 0, (): void => {
      const base = new SchemaFactory<StringSchema>((): StringSchema => liteV.string().required());
      const lengths = base.derive((s: StringSchema): TransformSchema<string, number> => s.transform((value: string): number => value.length));
      expect(lengths.create().parse('four').value).assertEqual(4);
      expect(base.create().parse('four').value).assertEqual('four');
      const nullable = base.derive((s: StringSchema): NullableSchema<string> => s.nullable());
      expect(nullable.create().parse(null).value).assertEqual(null);
    });
  });
}
