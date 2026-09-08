import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { fromJSONSchema } from '../main/ets/core/interop';
import { validateValue, validateValueAsync, validateBatchAsync, ValidationCancellationToken } from '../main/ets/core/errors';
import { AnySchema, ValidateResult } from '../main/ets/core/types';
import { deepPartialSchema } from '../main/ets/core/partial';
import { ValidationOptions } from '../main/ets/core/errors';

class PendingSchema implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  validate(_value: Object | null | undefined): ValidateResult { return { valid: true, errors: [] }; }
  validateAsync(_value: Object | null | undefined): Promise<ValidateResult> {
    return new Promise<ValidateResult>((_resolve): void => {});
  }
}

class RejectingSchema implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  calls: number = 0;
  validate(_value: Object | null | undefined): ValidateResult { return { valid: true, errors: [] }; }
  validateAsync(_value: Object | null | undefined): Promise<ValidateResult> {
    this.calls++;
    return Promise.reject(new Error('external failure'));
  }
}

export default function v120Test(): void {
  describe('1.2 regression contracts', (): void => {
    it('deep partial composes union and intersection without changing originals', 0, async (): Promise<void> => {
      const left = v.object({ 'name': v.string().required() });
      const right = v.object({ 'age': v.number().required() });
      const union = v.union<Record<string, Object>>([left, right]).label('profile');
      const intersection = v.intersection<Record<string, Object>>(left, right);
      const empty: Record<string, Object> = {};
      expect(union.validate(empty).valid).assertFalse();
      expect(intersection.validate(empty).valid).assertFalse();
      expect(union.deepPartial().parse(empty).success).assertTrue();
      expect((await intersection.deepPartial().parseAsync(empty)).success).assertTrue();
      expect(union.deepPartial().validate(42).errors[0].message.includes('profile')).assertTrue();
      expect(left.validate(empty).valid).assertFalse();
      expect(right.validate(empty).valid).assertFalse();
    });
    it('passes execution context to conditional predicates on every path', 0, async (): Promise<void> => {
      const schema = v.when<string>('mode', (_value: Object | null | undefined,
        _siblings?: Record<string, Object>, options?: ValidationOptions): boolean => options?.context?.['strict'] === true,
        v.string().min(3), v.string());
      const options: ValidationOptions = { context: { 'strict': true } };
      expect(schema.validate('a', undefined, options).valid).assertFalse();
      expect((await schema.validateAsync('a', undefined, options)).valid).assertFalse();
      expect(schema.parse('a', undefined, options).success).assertFalse();
      expect((await schema.parseAsync('a', undefined, options)).success).assertFalse();
      expect(schema.validate('a').valid).assertTrue();
    });
    it('deep partial preserves conditional selection and nested field constraints', 0, async (): Promise<void> => {
      const original = v.when<Record<string, Object>>('mode', (value: Object | null | undefined): boolean => value === 'strict',
        v.object({ 'name': v.string().required().min(3) }), v.object({ 'age': v.number().required() }));
      const patch = original.deepPartial();
      const empty: Record<string, Object> = {};
      const siblings: Record<string, Object> = { 'mode': 'strict' };
      expect(original.validate(empty, siblings).valid).assertFalse();
      expect(patch.validate(empty, siblings).valid).assertTrue();
      expect((await patch.parseAsync(empty, siblings)).success).assertTrue();
      const shortName: Record<string, Object> = { 'name': 'a' };
      const badAge: Record<string, Object> = { 'age': 'bad' };
      expect(patch.validate(shortName, siblings).valid).assertFalse();
      expect(patch.validate(badAge, { 'mode': 'other' }).valid).assertFalse();
    });
    it('stops batch scheduling on third party rejection', 0, async (): Promise<void> => {
      const schema = new RejectingSchema();
      let rejected = false;
      try { await validateBatchAsync(schema, [1, 2, 3, 4], { concurrency: 2, timeoutMs: 100 }); }
      catch (_error) { rejected = true; }
      expect(rejected).assertTrue();
      expect(schema.calls).assertEqual(2);
    });
    it('checks empty and Unicode strings with JSON keyword semantics', 0, async (): Promise<void> => {
      const schema = fromJSONSchema(JSON.parse('{"type":"string","minLength":1,"maxLength":1}') as Record<string, Object>);
      expect(schema.validate('').valid).assertFalse();
      expect(schema.validate('😀').valid).assertTrue();
      expect((await schema.validateAsync('ab')).valid).assertFalse();
      expect(fromJSONSchema(JSON.parse('{"pattern":"^a"}') as Record<string, Object>).validate('').valid).assertFalse();
    });
    it('deep partial retains container rules and leaves originals intact', 0, async (): Promise<void> => {
      const child = v.object({ 'name': v.string().required() });
      const source = v.object({ 'rows': v.array(child).min(1), 'map': v.record(child), 'tuple': v.tuple([child]) });
      const patch = source.deepPartial();
      const empty: Record<string, Object> = {};
      const map: Record<string, Object> = { 'a': empty };
      const input: Record<string, Object> = { 'rows': [empty], 'map': map, 'tuple': [empty] };
      expect(patch.validate(input).valid).assertTrue();
      expect((await patch.parseAsync(input)).success).assertTrue();
      expect(source.validate(input).valid).assertFalse();
      expect(patch.validate({ 'rows': [] } as Record<string, Object>).valid).assertFalse();
      expect(deepPartialSchema(child.nullable()).validate(empty).valid).assertTrue();
      expect(deepPartialSchema(child.default(empty)).parse?.(undefined).success).assertTrue();
      const transform = child.transform<number>((value: Record<string, Object>): number => Object.keys(value).length);
      expect(deepPartialSchema(transform).parse?.(empty).value).assertEqual(0);
      expect(deepPartialSchema(v.string().required()).validate('').valid).assertFalse();
    });
    it('bounds async concurrency while preserving input order', 0, async (): Promise<void> => {
      let active = 0;
      let peak = 0;
      const schema = v.number().customAsync((value: number): Promise<boolean> => {
        active++;
        peak = Math.max(peak, active);
        return new Promise<boolean>((resolve): void => {
          setTimeout((): void => { active--; resolve(value % 2 === 0); }, value === 0 ? 20 : 1);
        });
      }, 'odd');
      const results = await validateBatchAsync(schema, [0, 1, 2, 3, 4], { concurrency: 2 });
      expect(peak).assertEqual(2);
      expect(active).assertEqual(0);
      expect(results.length).assertEqual(5);
      for (let i = 0; i < results.length; i++) expect(results[i].valid).assertEqual(i % 2 === 0);
    });
    it('times out hung validators and stops dispatching the rest of a batch', 0, async (): Promise<void> => {
      const schema = new PendingSchema();
      const result = await validateValueAsync(schema, 'x', { timeoutMs: 10 });
      expect(result.errors[0].code).assertEqual('timeout');
      const batch = await validateBatchAsync(schema, [1, 2, 3, 4], { concurrency: 2, timeoutMs: 10 });
      expect(batch.length).assertEqual(2);
      expect(batch[0].errors[0].code).assertEqual('timeout');
    });
    it('validates async options and clears successful deadlines', 0, async (): Promise<void> => {
      expect((await validateValueAsync(v.string(), 'ok', { timeoutMs: 1000 })).valid).assertTrue();
      let invalidConcurrency = false;
      try { await validateBatchAsync(v.string(), ['x'], { concurrency: 0 }); } catch (_error) { invalidConcurrency = true; }
      expect(invalidConcurrency).assertTrue();
      let invalidTimeout = false;
      try { await validateValueAsync(v.string(), 'x', { timeoutMs: -1 }); } catch (_error) { invalidTimeout = true; }
      expect(invalidTimeout).assertTrue();
      expect((await validateBatchAsync(v.string(), [], { concurrency: 2 })).length).assertEqual(0);
      const token = new ValidationCancellationToken();
      token.cancel();
      expect((await validateBatchAsync(v.string(), ['a', 'b'], { concurrency: 1, cancellation: token })).length).assertEqual(1);
      expect(validateValue(v.string().required(), '', { maxErrors: NaN }).errors.length).assertEqual(1);
    });
    it('isolates concurrent context calls through parse and composition', 0, async (): Promise<void> => {
      const field = v.context<number>(v.number(), (value: number, context: Record<string, Object>): boolean => value === context['expected']);
      const schema = v.object({ 'row': v.record(v.union<number>([field])) }).default({} as Record<string, Object>);
      const row: Record<string, Object> = { 'value': 3 };
      const input: Record<string, Object> = { 'row': row };
      const results = await Promise.all([
        validateValueAsync(schema, input, { context: { 'expected': 3 } }),
        validateValueAsync(schema, input, { context: { 'expected': 4 } })
      ]);
      expect(results[0].valid).assertTrue();
      expect(results[1].valid).assertFalse();
      expect(schema.parse(input, undefined, { context: { 'expected': 3 } }).success).assertTrue();
      expect((await schema.parseAsync(input, undefined, { context: { 'expected': 4 } })).success).assertFalse();
    });
    it('supports constraints beside references and untyped keywords', 0, async (): Promise<void> => {
      const schema = fromJSONSchema(JSON.parse('{"$defs":{"n":{"type":"number"}},"$ref":"#/$defs/n","maximum":5}') as Record<string, Object>);
      expect(schema.validate(6).valid).assertFalse();
      expect(schema.parse?.(4).success).assertTrue();
      expect((await schema.parseAsync?.(4))?.success).assertTrue();
      const pattern = fromJSONSchema(JSON.parse('{"pattern":"^a"}') as Record<string, Object>);
      expect(pattern.validate(4).valid).assertTrue();
      expect((await pattern.validateAsync(4)).valid).assertTrue();
      expect((await pattern.validateAsync('bad')).valid).assertFalse();
      expect(fromJSONSchema(JSON.parse('{"const":2,"minimum":3}') as Record<string, Object>).validate(2).valid).assertFalse();
      expect(fromJSONSchema(JSON.parse('{"anyOf":[]}') as Record<string, Object>).validate(2).valid).assertFalse();
    });
    it('rejects overlapping oneOf matches', 0, async (): Promise<void> => {
      const json = JSON.parse('{"oneOf":[{"type":"number"},{"type":"integer"}]}') as Record<string, Object>;
      const schema = fromJSONSchema(json);
      expect(schema.validate(1).valid).assertFalse();
      expect(schema.validate(1.5).valid).assertTrue();
      expect((await schema.validateAsync(1)).valid).assertFalse();
    });
    it('retains constraints beside anyOf and allOf', 0, (): void => {
      const schema = fromJSONSchema(JSON.parse('{"type":"string","minLength":3,"anyOf":[{"pattern":"^a"},{"pattern":"^b"}]}') as Record<string, Object>);
      expect(schema.validate('ab').valid).assertFalse();
      expect(schema.validate('cat').valid).assertFalse();
      expect(schema.validate('abc').valid).assertTrue();
    });
    it('propagates business context through object and array wrappers', 0, async (): Promise<void> => {
      const field = v.context<number>(v.number().required(), (value: number, context: Record<string, Object>): boolean => value <= (context['limit'] as number));
      const schema = v.object({ 'items': v.array(field) }).nullable();
      const input: Record<string, Object> = { 'items': [5] };
      expect(validateValue(schema, input, { context: { 'limit': 10 } }).valid).assertTrue();
      expect((await validateValueAsync(schema, input, { context: { 'limit': 10 } })).valid).assertTrue();
      expect(validateValue(schema, input, { context: { 'limit': 1 } }).errors[0].path).assertEqual('items.0');
    });
    it('replaces optionality when extending or merging a field', 0, (): void => {
      const base = v.object({ 'name': v.string().required() }).partial();
      const required = v.object({ 'name': v.string().required() });
      const empty: Record<string, Object> = {};
      expect(base.extend({ 'name': v.string().required() }).validate(empty).valid).assertFalse();
      expect(base.merge(required).validate(empty).valid).assertFalse();
      expect(base.validate(empty).valid).assertTrue();
      expect(required.merge(base).validate(empty).valid).assertTrue();
    });
  });
}
