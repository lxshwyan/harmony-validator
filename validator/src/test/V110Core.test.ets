import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { AnySchema } from '../main/ets/core/types';
import { serializeSchema, toJSONSchema } from '../main/ets/core/schema';
import { LazySchema } from '../main/ets/schemas/CompositionSchemas';
import {
  ValidationCancellationToken, flattenErrors, formatErrors, parseErrorPath,
  validateBatch, validateBatchAsync, validateValue, validateValueAsync
} from '../main/ets/core/errors';

function record(value?: Record<string, Object>): Record<string, Object> { return value ?? {}; }

export default function v110CoreTest(): void {
  describe('1.1 foundational schemas', (): void => {
    it('supports any unknown null and never with stable descriptors', 0, (): void => {
      expect(v.any().validate(null).valid).assertTrue();
      expect(v.unknown().parse('value').value).assertEqual('value');
      expect(v.null().validate(null).valid).assertTrue();
      expect(v.null().validate('null').errors[0].code).assertEqual('type_null');
      expect(v.never().validate(undefined).errors[0].code).assertEqual('never');
      expect(v.any().describeSchema().kind).assertEqual('any');
      expect(v.unknown().describeSchema().kind).assertEqual('unknown');
      expect(toJSONSchema(v.null())['type']).assertEqual('null');
      expect((toJSONSchema(v.never())['not'] as Record<string, Object>) !== undefined).assertTrue();
    });

    it('keeps foundational wrappers composable', 0, async (): Promise<void> => {
      expect(v.any().default('fallback').parse(undefined).value).assertEqual('fallback');
      expect(v.null().transform<string>((_value: null): string => 'empty').parse(null).value).assertEqual('empty');
      expect((await v.unknown().validateAsync(record())).valid).assertTrue();
      expect((await v.never('禁止').parseAsync(1)).errors[0].message).assertEqual('禁止');
    });
  });

  describe('1.1 recursive and composition schemas', (): void => {
    it('validates recursive trees and preserves deep paths', 0, (): void => {
      let tree: LazySchema<Record<string, Object>>;
      tree = v.lazy<Record<string, Object>>((): AnySchema<Record<string, Object>> => v.object({
        'name': v.string().required(),
        'children': v.array<Record<string, Object>>(tree).optional(),
      }));
      const valid = record({ 'name': 'root', 'children': [record({ 'name': 'leaf' })] });
      expect(tree.validate(valid).valid).assertTrue();
      const invalid = record({ 'name': 'root', 'children': [record()] });
      expect(tree.validate(invalid).errors[0].path).assertEqual('children.0.name');
    });

    it('exports referenced recursive JSON Schema and rejects plain serialization', 0, (): void => {
      let tree: LazySchema<Record<string, Object>>;
      tree = v.lazy<Record<string, Object>>((): AnySchema<Record<string, Object>> => v.object({
        'children': v.array<Record<string, Object>>(tree).optional(),
      })).meta({ id: 'TreeNode' });
      const json = toJSONSchema(tree);
      expect(json['$schema']).assertEqual('https://json-schema.org/draft/2020-12/schema');
      let thrown = false;
      try { serializeSchema(tree); } catch (_error) { thrown = true; }
      expect(thrown).assertTrue();
    });

    it('intersects validation and merges parsed object output', 0, async (): Promise<void> => {
      const left = v.object({ 'name': v.string().required() }).strip();
      const right = v.object({ 'age': v.coerceNumber() }).strip();
      const schema = v.intersection<Record<string, Object>>(left, right);
      const parsed = schema.parse(record({ 'name': 'hmkit', 'age': '18' }));
      expect(parsed.success).assertTrue();
      expect((parsed.value as Record<string, Object>)['name']).assertEqual('hmkit');
      expect((parsed.value as Record<string, Object>)['age']).assertEqual(18);
      expect(schema.validate(record({ 'name': '', 'age': 'bad' })).errors.length).assertEqual(2);
      expect((await schema.validateAsync(record({ 'name': 'ok', 'age': '18' }))).valid).assertTrue();
      expect((toJSONSchema(schema)['allOf'] as Array<Object>).length).assertEqual(2);
    });

    it('selects conditional schemas from sibling values', 0, async (): Promise<void> => {
      const schema = v.object({
        'type': v.string().required(),
        'value': v.when<string>('type', (other: Object | null | undefined): boolean => other === 'text',
          v.string().required().min(2), v.string().optional().max(1)),
      });
      expect(schema.validate(record({ 'type': 'text', 'value': 'ok' })).valid).assertTrue();
      expect(schema.validate(record({ 'type': 'text', 'value': 'x' })).valid).assertFalse();
      expect(schema.validate(record({ 'type': 'short', 'value': 'x' })).valid).assertTrue();
      expect((await schema.validateAsync(record({ 'type': 'short', 'value': 'xx' }))).valid).assertFalse();
      expect(schema.describeSchema().properties?.['value'].kind).assertEqual('conditional');
    });
  });

  describe('1.1 object composition', (): void => {
    it('extends and merges without mutating source shapes', 0, (): void => {
      const base = v.object({ 'id': v.number().required() });
      const extended = base.extend({ 'name': v.string().required() });
      expect(base.validate(record({ 'id': 1 })).valid).assertTrue();
      expect(extended.validate(record({ 'id': 1 })).valid).assertFalse();
      const merged = extended.merge(v.object({ 'enabled': v.boolean().required() }).partial(['enabled']));
      expect(merged.validate(record({ 'id': 1, 'name': 'x' })).valid).assertTrue();
    });

    it('deepPartial makes nested object fields optional without mutating original', 0, (): void => {
      const original = v.object({
        'profile': v.object({ 'name': v.string().required(), 'city': v.string().required() }),
      });
      const patch = original.deepPartial();
      expect(patch.validate(record()).valid).assertTrue();
      expect(patch.validate(record({ 'profile': record() })).valid).assertTrue();
      expect(original.validate(record({ 'profile': record() })).valid).assertFalse();
    });
  });

  describe('1.1 execution and error tools', (): void => {
    it('formats flat and structured paths without losing codes', 0, (): void => {
      const result = v.object({
        'users': v.array(v.object({ 'name': v.string().required('姓名必填') })),
      }).validate(record({ 'users': [record()] }));
      expect(parseErrorPath(result.errors[0].path).join('/')).assertEqual('users/0/name');
      expect(flattenErrors(result.errors)['users.0.name'][0]).assertEqual('姓名必填');
      const formatted = formatErrors(result.errors);
      expect(formatted[0].path.length).assertEqual(3);
      expect(formatted[0].code).assertEqual('required');
    });

    it('supports abortEarly, maxErrors, batch and cancellation', 0, async (): Promise<void> => {
      const schema = v.object({ 'a': v.string().required(), 'b': v.string().required() });
      expect(validateValue(schema, record(), { abortEarly: true }).errors.length).assertEqual(1);
      expect(validateValue(schema, record(), { maxErrors: 1 }).errors.length).assertEqual(1);
      expect(validateBatch(schema, [record(), record({ 'a': 'a', 'b': 'b' })]).length).assertEqual(2);
      expect((await validateBatchAsync(schema, [record()]))[0].valid).assertFalse();
      const token = new ValidationCancellationToken();
      token.cancel();
      expect(validateValue(schema, record(), { cancellation: token }).errors[0].code).assertEqual('cancelled');
      expect((await validateValueAsync(schema, record(), { cancellation: token })).errors[0].code)
        .assertEqual('cancelled');
    });
  });

  describe('1.1 codec', (): void => {
    it('decodes, validates and encodes in both directions', 0, async (): Promise<void> => {
      const codec = v.codec<string, number>(
        v.string().required(), v.number().integer(),
        (input: string): number => Number(input),
        (output: number): string => `${output}`,
      );
      expect(codec.parse('42').value).assertEqual(42);
      expect(codec.encode(42).value).assertEqual('42');
      expect((await codec.parseAsync('7')).value).assertEqual(7);
      expect((await codec.encodeAsync(8)).value).assertEqual('8');
      expect(codec.describeSchema().kind).assertEqual('codec');
      expect((toJSONSchema(codec)['x-hmkit-unrepresentable'] as Array<Object>).length).assertEqual(1);
    });

    it('maps decode, encode and schema failures to stable results', 0, async (): Promise<void> => {
      const codec = v.codec<string, number>(
        v.string().required(), v.number(),
        (input: string): number => {
          if (input === 'boom') throw new Error('decode');
          return Number(input);
        },
        (output: number): string => {
          if (output < 0) throw new Error('encode');
          return `${output}`;
        },
      );
      expect(codec.parse(undefined).success).assertFalse();
      expect(codec.parse('boom').errors[0].code).assertEqual('codec_decode');
      expect(codec.encode(-1).errors[0].code).assertEqual('codec_encode');
      expect((await codec.parseAsync('boom')).errors[0].code).assertEqual('codec_decode');
      expect((await codec.encodeAsync(-1)).errors[0].code).assertEqual('codec_encode');
    });
  });
}
