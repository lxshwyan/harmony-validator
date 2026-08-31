import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { AnySchema } from '../main/ets/core/types';
import { serializeSchemaDocument } from '../main/ets/core/schema';

function eventVariants(): Record<string, AnySchema<Record<string, Object>>> {
  const variants: Record<string, AnySchema<Record<string, Object>>> = {};
  variants['text'] = v.object({ 'type': v.literal('text').required(), 'value': v.string().required() }).strict();
  variants['count'] = v.object({ 'type': v.literal('count').required(), 'value': v.number().required() }).strict();
  return variants;
}

export default function v100StabilityTest(): void {
  describe('1.0 stability and property checks', (): void => {
    it('coerces a deterministic numeric range without drift', 0, (): void => {
      const schema = v.coerceNumber();
      for (let i = -100; i <= 100; i++) {
        const parsed = schema.parse(`${i}`);
        expect(parsed.success).assertTrue();
        expect(parsed.value).assertEqual(i);
      }
    });

    it('keeps composition results stable across repeated calls', 0, (): void => {
      const schema = v.object({
        'events': v.array(v.discriminatedUnion('type', eventVariants())).min(1),
        'metadata': v.record(v.coerceString()).optional(),
      }).partial(['metadata']).strip();
      const event: Record<string, Object> = { 'type': 'text', 'value': 'hello' };
      const input: Record<string, Object> = { 'events': [event], 'unknown': true };
      const first = schema.parse(input);
      for (let i = 0; i < 100; i++) {
        const current = schema.parse(input);
        expect(current.success).assertEqual(first.success);
        expect(current.errors.length).assertEqual(first.errors.length);
      }
      expect((first.value as Record<string, Object>)['unknown']).assertUndefined();
    });

    it('serializes the versioned descriptor deterministically', 0, (): void => {
      const schema = v.object({
        'settings': v.record(v.union<Object>([v.string(), v.number(), v.boolean()])),
      }).strict();
      const baseline = serializeSchemaDocument(schema);
      for (let i = 0; i < 100; i++) expect(serializeSchemaDocument(schema)).assertEqual(baseline);
    });

    it('keeps a generous local performance baseline for common validation', 0, (): void => {
      const schema = v.object({
        'name': v.string().required().min(2).max(50),
        'age': v.number().required().min(0).max(150),
        'tags': v.array(v.string().min(1)).max(10),
      }).strict();
      const input: Record<string, Object> = { 'name': 'Alice', 'age': 30, 'tags': ['a', 'b', 'c'] };
      const started = Date.now();
      for (let i = 0; i < 2000; i++) expect(schema.validate(input).valid).assertTrue();
      expect(Date.now() - started < 5000).assertTrue();
    });
  });
}
