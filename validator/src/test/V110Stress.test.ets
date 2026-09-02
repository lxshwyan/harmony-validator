import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { AnySchema, ValidateResult } from '../main/ets/core/types';
import { serializeSchemaDocument, toJSONSchema } from '../main/ets/core/schema';
import { deserializeSchemaDocument, fromJSONSchema } from '../main/ets/core/interop';
import {
  ValidationCancellationToken, validateBatch, validateBatchAsync, validateValue
} from '../main/ets/core/errors';
import { LazySchema } from '../main/ets/schemas/CompositionSchemas';
import { isUUID } from '../main/ets/rules/uuid';
import { isIPv6 } from '../main/ets/rules/ipv6';
import { isBase64 } from '../main/ets/rules/base64';
import { isHostname } from '../main/ets/rules/hostname';

function record(value?: Record<string, Object>): Record<string, Object> { return value ?? {}; }

class CancellingSchema implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  private token: ValidationCancellationToken;
  private calls: number = 0;
  constructor(token: ValidationCancellationToken) { this.token = token; }
  validate(_value: Object | null | undefined): ValidateResult {
    this.calls++;
    this.token.cancel();
    return { valid: true, errors: [] };
  }
  validateAsync(_value: Object | null | undefined): Promise<ValidateResult> {
    return Promise.resolve(this.validate(_value));
  }
  count(): number { return this.calls; }
}

function nestedNode(depth: number): Record<string, Object> {
  let current: Record<string, Object> = record({ 'name': 'leaf' });
  for (let i = 0; i < depth; i++) current = record({ 'name': `node-${i}`, 'children': [current] });
  return current;
}

export default function v110StressTest(): void {
  describe('1.1 deterministic stress and boundaries', (): void => {
    it('keeps sync and async results equivalent across a deterministic input matrix', 0,
      async (): Promise<void> => {
        const schema = v.object({
          'code': v.string().required().min(2).max(8).pattern(/^[a-z]+$/),
          'score': v.number().required().min(0).max(100).integer(),
          'flags': v.array(v.boolean()).min(1).max(4),
        }).strict();
        for (let i = 0; i < 240; i++) {
          const valid = i % 3 === 0;
          const input = valid
            ? record({ 'code': `item`, 'score': i % 101, 'flags': [true, false] })
            : record({ 'code': `${i}`, 'score': 101 + i, 'flags': [] });
          const sync = schema.validate(input);
          const asyncResult = await schema.validateAsync(input);
          expect(sync.valid).assertEqual(asyncResult.valid);
          expect(sync.errors.length).assertEqual(asyncResult.errors.length);
          if (!sync.valid) expect(sync.errors[0].code).assertEqual(asyncResult.errors[0].code);
        }
      });

    it('validates a deep recursive structure and reports the complete failing path', 0, (): void => {
      let node: LazySchema<Record<string, Object>>;
      node = v.lazy<Record<string, Object>>((): AnySchema<Record<string, Object>> => v.object({
        'name': v.string().required(),
        'children': v.array<Record<string, Object>>(node).optional(),
      }));
      expect(node.validate(nestedNode(40)).valid).assertTrue();
      let invalid: Record<string, Object> = record();
      for (let i = 0; i < 24; i++) invalid = record({ 'name': 'ok', 'children': [invalid] });
      const result = node.validate(invalid);
      expect(result.valid).assertFalse();
      expect(result.errors[0].path.endsWith('name')).assertTrue();
      expect(result.errors[0].path.split('.').length).assertEqual(49);
    });

    it('deduplicates identical intersection errors under repeated execution', 0, (): void => {
      const shared = v.string().required('同一错误');
      const schema = v.intersection<string>(shared, shared);
      for (let i = 0; i < 100; i++) {
        const result = schema.validate('');
        expect(result.errors.length).assertEqual(1);
        expect(result.errors[0].message).assertEqual('同一错误');
      }
    });

    it('keeps caller results immutable when limiting errors', 0, (): void => {
      const schema = v.object({
        'a': v.string().required(), 'b': v.string().required(), 'c': v.string().required()
      });
      const complete = schema.validate(record());
      const limited = validateValue(schema, record(), { maxErrors: 2 });
      expect(complete.errors.length).assertEqual(3);
      expect(limited.errors.length).assertEqual(2);
      limited.errors.pop();
      expect(complete.errors.length).assertEqual(3);
    });

    it('stops sync and async batches cooperatively after cancellation', 0, async (): Promise<void> => {
      const syncToken = new ValidationCancellationToken();
      const syncSchema = new CancellingSchema(syncToken);
      expect(validateBatch(syncSchema, [1, 2, 3], { cancellation: syncToken }).length).assertEqual(1);
      expect(syncSchema.count()).assertEqual(1);
      const asyncToken = new ValidationCancellationToken();
      const asyncSchema = new CancellingSchema(asyncToken);
      expect((await validateBatchAsync(asyncSchema, [1, 2, 3], { cancellation: asyncToken })).length)
        .assertEqual(1);
      expect(asyncSchema.count()).assertEqual(1);
    });

    it('round trips codec values over a broad integer range', 0, async (): Promise<void> => {
      const codec = v.codec<string, number>(v.string().required(), v.number().integer(),
        (input: string): number => Number(input), (output: number): string => `${output}`);
      for (let i = -500; i <= 500; i += 5) {
        const decoded = codec.parse(`${i}`);
        expect(decoded.success).assertTrue();
        const encoded = codec.encode(decoded.value as number);
        expect(encoded.value).assertEqual(`${i}`);
      }
      expect((await codec.parseAsync('123')).value).assertEqual(123);
      expect((await codec.encodeAsync(123)).value).assertEqual('123');
    });
  });

  describe('1.1 interchange and format corpus', (): void => {
    it('preserves validation behavior after document restoration', 0, (): void => {
      const source = v.object({
        'id': v.string().required().uuid(),
        'count': v.number().required().integer().min(1).max(9),
        'tags': v.array(v.enumOf<Object>(['a', 'b'])).min(1).max(2),
      }).strict();
      const document = serializeSchemaDocument(source);
      const restored = deserializeSchemaDocument(document);
      const cases: Array<Record<string, Object>> = [
        record({ 'id': '550e8400-e29b-41d4-a716-446655440000', 'count': 1, 'tags': ['a'] }),
        record({ 'id': 'bad', 'count': 1, 'tags': ['a'] }),
        record({ 'id': '550e8400-e29b-41d4-a716-446655440000', 'count': 0, 'tags': [] }),
        record({ 'id': '550e8400-e29b-41d4-a716-446655440000', 'count': 2, 'tags': ['x'] }),
      ];
      for (const value of cases) {
        const before = source.validate(value);
        const after = restored.validate(value);
        expect(after.valid).assertEqual(before.valid);
        expect(after.errors.length).assertEqual(before.errors.length);
      }
      expect(serializeSchemaDocument(source)).assertEqual(document);
    });

    it('imports exported representable JSON Schema with equivalent boundaries', 0, (): void => {
      const source = v.object({
        'name': v.string().required().min(2).max(5),
        'age': v.number().required().integer().min(18).max(65),
      }).strict();
      const restored = fromJSONSchema(toJSONSchema(source));
      const cases: Array<Record<string, Object>> = [
        record({ 'name': 'Li', 'age': 18 }), record({ 'name': 'A', 'age': 18 }),
        record({ 'name': 'Valid', 'age': 65 }), record({ 'name': 'TooLong', 'age': 66 }), record(),
      ];
      for (const value of cases) {
        expect(restored.validate(value).valid).assertEqual(source.validate(value).valid);
      }
    });

    it('checks valid and invalid corpora for every new standard rule', 0, (): void => {
      const uuids = ['550e8400-e29b-41d4-a716-446655440000', '6ba7b810-9dad-11d1-80b4-00c04fd430c8'];
      const badUuids = ['', '550e8400e29b41d4a716446655440000', '550e8400-e29b-01d4-a716-446655440000'];
      for (const value of uuids) expect(isUUID(value)).assertTrue();
      for (const value of badUuids) expect(isUUID(value)).assertFalse();

      const ipv6 = ['::1', '::', '2001:db8::1', '2001:db8:0:0:0:0:0:1'];
      const badIpv6 = ['', '2001:::1', '1:2:3:4:5:6:7', '1:2:3:4:5:6:7:8:9'];
      for (const value of ipv6) expect(isIPv6(value)).assertTrue();
      for (const value of badIpv6) expect(isIPv6(value)).assertFalse();

      const base64 = ['YQ==', 'YWI=', 'YWJj', 'aG1raXQ='];
      const badBase64 = ['', 'YQ=', 'Y===', 'YWJj*'];
      for (const value of base64) expect(isBase64(value)).assertTrue();
      for (const value of badBase64) expect(isBase64(value)).assertFalse();

      const hostnames = ['localhost', 'api.example.com', 'a-b.example'];
      const badHostnames = ['', '-api.example', 'api-.example', 'bad..example', 'example.'];
      for (const value of hostnames) expect(isHostname(value)).assertTrue();
      for (const value of badHostnames) expect(isHostname(value)).assertFalse();
    });

    it('maintains a generous throughput baseline for the complete 1.1 pipeline', 0, (): void => {
      const schema = v.object({
        'host': v.string().required().hostname(),
        'id': v.string().required().uuid(),
        'values': v.array(v.number().integer().min(0).max(100)).min(1).max(8),
      }).strict();
      const input = record({
        'host': 'api.example.com', 'id': '550e8400-e29b-41d4-a716-446655440000',
        'values': [1, 2, 3, 4]
      });
      const started = Date.now();
      for (let i = 0; i < 5000; i++) expect(schema.validate(input).valid).assertTrue();
      expect(Date.now() - started < 8000).assertTrue();
    });
  });
}
