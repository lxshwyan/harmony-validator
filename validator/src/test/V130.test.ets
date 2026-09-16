import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { AnySchema, ValidateResult } from '../main/ets/core/types';
import { ValidationOptions, ValidationCancellationToken } from '../main/ets/core/errors';
import { FormValidator } from '../main/ets/form/FormValidator';
import { fromJSONSchema } from '../main/ets/core/interop';
import { inspectJSONSchema } from '../main/ets/core/JSONImportDiagnostics';
import { guarded, inspectInput, InputLimits } from '../main/ets/core/inputSafety';
import { uniqueBy } from '../main/ets/core/collections';

function json(source: string): AnySchema<Object> {
  return fromJSONSchema(JSON.parse(source) as Record<string, Object>, { strict: true });
}

class WaitingRule implements AnySchema<Object> {
  readonly __schemaType: Object | null = null;
  cancelled: number = 0;
  calls: number = 0;
  validate(_value: Object | null | undefined): ValidateResult { return { valid: true, errors: [] }; }
  validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>, options?: ValidationOptions): Promise<ValidateResult> {
    this.calls++;
    if (value === 'ok') return Promise.resolve(this.validate(value));
    return new Promise<ValidateResult>((_resolve): void => {
      options?.cancellation?.onCancel((): void => { this.cancelled++; });
    });
  }
}

class ThrowingRule extends WaitingRule {
  validateAsync(_value: Object | null | undefined): Promise<ValidateResult> {
    return Promise.reject(new Error('network failed'));
  }
}

export default function v130Test(): void {
  describe('1.3 bounded and extensible validation', (): void => {
    it('isolates cancellation between forms sharing one schema', 0, async (): Promise<void> => {
      const shared = new WaitingRule();
      const a = new FormValidator({ 'x': shared });
      const b = new FormValidator({ 'x': shared });
      const pendingA = a.validateFieldAsync('x', 'wait');
      const pendingB = b.validateFieldAsync('x', 'wait');
      a.dispose(); await pendingA;
      expect(shared.cancelled).assertEqual(1);
      expect(b.getFieldState('x').validating).assertTrue();
      await b.validateFieldAsync('x', 'ok'); await pendingB;
      expect(shared.cancelled).assertEqual(2);
      expect(b.getFieldState('x').error).assertEqual(null);
      b.dispose();
    });
    it('recovers after timeout without leaking old busy state', 0, async (): Promise<void> => {
      const rule = new WaitingRule();
      const form = new FormValidator({ 'x': rule }, { timeoutMs: 5 });
      expect(await form.validateFieldAsync('x', 'wait') !== null).assertTrue();
      expect(form.getFieldState('x').validating).assertFalse();
      expect(await form.validateFieldAsync('x', 'ok')).assertEqual(null);
      expect(rule.cancelled).assertEqual(1);
      form.dispose();
      expect(rule.cancelled).assertEqual(1);
    });
    it('prefixes optional wrapper errors inside objects', 0, async (): Promise<void> => {
      const numbers = uniqueBy(v.array(v.number()), (n: number): number => n);
      const schema = v.object({ 'rows': numbers, 'safe': guarded(v.number(), { maxDepth: 0 }) });
      const duplicate: Record<string, Object> = { 'rows': [2, 2], 'safe': 1 };
      expect(schema.validate(duplicate).errors[0].path).assertEqual('rows.1');
      expect((await schema.parseAsync(duplicate)).errors[0].path).assertEqual('rows.1');
      const deep: Record<string, Object> = { 'rows': [1], 'safe': { 'x': 1 } as Record<string, Object> };
      expect(schema.validate(deep).errors[0].path).assertEqual('safe.x');
    });
    it('runs all JSON entry paths consistently across numeric samples', 0, async (): Promise<void> => {
      const schema = json('{"if":{"type":"number"},"then":{"multipleOf":0.25,"exclusiveMinimum":-1,"exclusiveMaximum":2},"else":false}');
      for (let i = -20; i <= 30; i++) {
        const value = i / 10;
        const expected = i % 5 === 0 && i > -10 && i < 20;
        expect(schema.validate(value).valid).assertEqual(expected);
        expect((await schema.validateAsync(value)).valid).assertEqual(expected);
        expect(schema.parse?.(value).success).assertEqual(expected);
        expect((await schema.parseAsync?.(value))?.success).assertEqual(expected);
      }
    });
    it('keeps siblings through configurable ContextSchema in forms', 0, async (): Promise<void> => {
      const required = v.string().requiredWhen('mode', (mode: Object | null | undefined): boolean => mode === 'strict');
      const schema = v.context(required, (_value: string, _context: Record<string, Object>): boolean => true);
      const form = new FormValidator({ 'name': schema });
      expect(await form.validateFieldAsync('name', '', { 'mode': 'strict' }) !== null).assertTrue();
      expect(await form.validateFieldAsync('name', '', { 'mode': 'optional' })).assertEqual(null);
    });
    it('wrappers respect cancellation and error limits', 0, async (): Promise<void> => {
      const token = new ValidationCancellationToken(); token.cancel();
      const safe = guarded(v.string());
      expect(safe.parse('a', undefined, { cancellation: token }).errors[0].code).assertEqual('cancelled');
      expect((await safe.parseAsync('a', undefined, { cancellation: token })).success).assertFalse();
      const distinct = uniqueBy(v.array(v.number()), (n: number): number => n);
      expect(distinct.validate([1, 1, 1], undefined, { maxErrors: 1 }).errors.length).assertEqual(1);
      expect((await distinct.validateAsync([1, 1, 1], undefined, { abortEarly: true })).errors.length).assertEqual(1);
    });
    it('keeps latest submit busy while an older handler finishes', 0, async (): Promise<void> => {
      const form = new FormValidator({ 'name': v.string() });
      let releaseFirst: (() => void) | undefined;
      let releaseSecond: (() => void) | undefined;
      let enteredFirst: (() => void) | undefined;
      let enteredSecond: (() => void) | undefined;
      const firstEntered = new Promise<void>((resolve): void => { enteredFirst = resolve; });
      const secondEntered = new Promise<void>((resolve): void => { enteredSecond = resolve; });
      const first = form.submit({ 'name': 'a' }, (): Promise<void> => {
        enteredFirst?.(); return new Promise<void>((resolve): void => { releaseFirst = resolve; });
      });
      await firstEntered;
      const second = form.submit({ 'name': 'b' }, (): Promise<void> => {
        enteredSecond?.(); return new Promise<void>((resolve): void => { releaseSecond = resolve; });
      });
      await secondEntered;
      releaseFirst?.(); await first;
      expect(form.getState().submitting).assertTrue();
      releaseSecond?.(); await second;
      expect(form.getState().submitting).assertFalse();
    });
    it('cancels peers when a whole-form field throws', 0, async (): Promise<void> => {
      const waiting = new WaitingRule();
      const form = new FormValidator({ 'a': waiting, 'b': new ThrowingRule() });
      let threw = false;
      try { await form.validateAllAsync({ 'a': 'wait', 'b': 'value' }); } catch (_error) { threw = true; }
      expect(threw).assertTrue(); expect(waiting.cancelled).assertEqual(1);
      expect(form.getFieldState('a').validating).assertFalse();
    });
    it('old change does not dispatch obsolete dependent values', 0, async (): Promise<void> => {
      const source = new WaitingRule();
      let calls = 0;
      const dependent = v.string().customAsync(async (_value: string): Promise<boolean> => { calls++; return true; }, 'bad');
      const form = new FormValidator({ 'source': source, 'target': dependent },
        { fields: { 'target': { dependencies: ['source'] } } });
      const old = form.onChange('source', 'wait', { 'source': 'wait', 'target': 'old' });
      await form.onChange('source', 'ok', { 'source': 'ok', 'target': 'new' });
      await old;
      expect(calls).assertEqual(1);
    });
    it('repeat cancellations do not leave busy or error state', 0, async (): Promise<void> => {
      const rule = new WaitingRule(); const form = new FormValidator({ 'x': rule });
      for (let i = 0; i < 100; i++) {
        const task = form.validateFieldAsync('x', 'wait'); form.reset(); await task;
        expect(form.getFieldState('x').validating).assertFalse();
      }
      expect(rule.cancelled).assertEqual(100);
      expect(Object.keys(form.getState().errors).length).assertEqual(0);
    });
    it('debounce supersession and disposal settle pending calls', 0, async (): Promise<void> => {
      const rule = new WaitingRule(); const form = new FormValidator({ 'x': rule }, { debounceMs: 20 });
      const a = form.onChange('x', 'old'); const b = form.onChange('x', 'new');
      form.dispose(); await Promise.all([a, b]);
      expect(rule.calls).assertEqual(0);
      expect(form.validateField('x', 'value')).assertEqual(null);
      expect(Object.keys(form.validateAll({ 'x': 'value' })).length).assertEqual(1);
      expect(Object.keys(await form.submit({ 'x': 'value' })).length).assertEqual(1);
    });
    it('numeric property samples agree with integer arithmetic', 0, (): void => {
      let seed = 17;
      for (let i = 0; i < 200; i++) {
        seed = (seed * 48271) % 2147483647;
        const divisor = seed % 23 + 1;
        const value = seed % 2001 - 1000;
        const schema = json(`{"multipleOf":${divisor},"exclusiveMinimum":-500,"exclusiveMaximum":500}`);
        expect(schema.validate(value).valid).assertEqual(value % divisor === 0 && value > -500 && value < 500);
      }
      expect(json('{"multipleOf":5e-324}').validate(1e-323).valid).assertTrue();
      expect(json('{"multipleOf":0.01}').validate(Infinity).valid).assertFalse();
      expect(json('{"multipleOf":0.01}').validate(NaN).valid).assertFalse();
    });
    it('array equality handles different nested shapes and signed zero', 0, (): void => {
      const schema = json('{"uniqueItems":true}');
      for (const raw of ['[[],{}]', '[{"x":1},{"y":1}]', '[[1],[1,2]]', '[{"a":null},{"a":1}]', '[{"a":1},{"a":1,"b":2}]']) {
        expect(schema.validate(JSON.parse(raw) as Object[]).valid).assertTrue();
      }
      expect(schema.validate([0, -0]).valid).assertFalse();
      expect(schema.validate([null, null]).valid).assertFalse();
    });
    it('checks conditional object fields and composes sibling constraints', 0, async (): Promise<void> => {
      const schema = json('{"type":"object","properties":{"kind":{"type":"string"},"name":{"type":"string"}},"required":["kind"],"if":{"properties":{"kind":{"const":"company"}}},"then":{"properties":{"name":{"minLength":3}},"required":["name"]},"else":{"properties":{"name":{"maxLength":2}}}}');
      expect(schema.validate({ 'kind': 'company' } as Record<string, Object>).valid).assertFalse();
      expect(schema.validate({ 'kind': 'company', 'name': 'abc' } as Record<string, Object>).valid).assertTrue();
      expect((await schema.validateAsync({ 'kind': 'person', 'name': 'abc' } as Record<string, Object>)).valid).assertFalse();
      expect(schema.validate({ 'name': 'abc' } as Record<string, Object>).valid).assertFalse();
    });
    it('optional safety snapshots limits and forwards legacy parsers', 0, async (): Promise<void> => {
      const limits: InputLimits = { maxDepth: 0, maxNodes: 1 };
      const schema = guarded(new WaitingRule(), limits);
      limits.maxDepth = 100;
      expect(schema.parse(1).success).assertTrue();
      expect((await schema.parseAsync('ok')).success).assertTrue();
      expect(schema.validate({ 'x': 1 } as Record<string, Object>).valid).assertFalse();
      expect(inspectInput([], { maxDepth: 0 }).valid).assertTrue();
    });
    it('cancels superseded pending fields and settles callers', 0, async (): Promise<void> => {
      const rule = new WaitingRule();
      const form = new FormValidator({ 'name': rule });
      const old = form.validateFieldAsync('name', 'wait');
      expect(await form.validateFieldAsync('name', 'ok')).assertEqual(null);
      await old;
      expect(rule.cancelled).assertEqual(1);
      expect(form.getFieldState('name').validating).assertFalse();
      expect(form.getFieldState('name').error).assertEqual(null);
    });
    it('cancels on non-triggering change and reset dispose', 0, async (): Promise<void> => {
      const rule = new WaitingRule();
      const form = new FormValidator({ 'name': rule }, { triggers: ['blur'] });
      const first = form.onBlur('name', 'wait');
      await form.onChange('name', 'new'); await first;
      expect(rule.cancelled).assertEqual(1);
      const second = form.validateFieldAsync('name', 'wait'); form.reset(); await second;
      const third = form.validateFieldAsync('name', 'wait'); form.dispose(); await third;
      expect(rule.cancelled).assertEqual(3);
      await form.validateFieldAsync('name', 'wait');
      expect(rule.calls).assertEqual(3);
      expect(Object.keys(await form.validateAllAsync({ 'name': 'ok' })).length).assertEqual(1);
    });
    it('times out fields and prevents cancelled submit handlers', 0, async (): Promise<void> => {
      const rule = new WaitingRule();
      const form = new FormValidator({ 'name': rule }, { timeoutMs: 1000, fields: { 'name': { timeoutMs: 5 } } });
      const errors = await form.validateAllAsync({ 'name': 'wait' });
      expect(errors['name'].length > 0).assertTrue();
      expect(rule.cancelled).assertEqual(1);
      let submitted = false;
      const task = form.submit({ 'name': 'wait' }, async (): Promise<void> => { submitted = true; });
      form.reset(); await task;
      expect(submitted).assertFalse();
      expect(form.getState().submitting).assertFalse();
    });
    it('preserves sibling requiredWhen through async execution', 0, async (): Promise<void> => {
      const form = new FormValidator({ 'name': v.string().requiredWhen('mode', (mode: Object | null | undefined): boolean => mode === 'strict') });
      expect(await form.validateFieldAsync('name', '', { 'mode': 'strict' }) !== null).assertTrue();
    });
    it('rejects invalid timeout and clears state', 0, async (): Promise<void> => {
      const form = new FormValidator({ 'name': v.string() }, { timeoutMs: 0 });
      let threw = false;
      try { await form.validateFieldAsync('name', 'ok'); } catch (_error) { threw = true; }
      expect(threw).assertTrue(); expect(form.getFieldState('name').validating).assertFalse();
    });
    it('bounds depth nodes and accepts shared subtrees', 0, (): void => {
      const child: Record<string, Object> = { 'x': 1 };
      const data: Record<string, Object> = { 'a': child, 'b': child };
      expect(inspectInput(data, { maxDepth: 2, maxNodes: 5 }).valid).assertTrue();
      expect(inspectInput(data, { maxDepth: 1 }).errors[0].code).assertEqual('input_depth');
      expect(inspectInput(data, { maxNodes: 4 }).errors[0].code).assertEqual('input_nodes');
      child['cycle'] = child;
      expect(inspectInput(child).errors[0].path).assertEqual('cycle');
      expect(inspectInput(child).errors[0].code).assertEqual('input_cycle');
    });
    it('walks deep input iteratively and rejects invalid limits', 0, (): void => {
      const root: Record<string, Object> = {}; let current = root;
      for (let i = 0; i < 1000; i++) { const next: Record<string, Object> = {}; current['next'] = next; current = next; }
      expect(inspectInput(root).valid).assertFalse();
      expect(inspectInput(root, { maxDepth: 1000 }).valid).assertTrue();
      for (const n of [-1, 0.5, Infinity]) {
        let threw = false; try { inspectInput(1, { maxDepth: n }); } catch (_error) { threw = true; }
        expect(threw).assertTrue();
      }
      let threw = false; try { inspectInput(1, { maxNodes: 0 }); } catch (_error) { threw = true; }
      expect(threw).assertTrue();
    });
    it('guards all four paths while preserving transforms', 0, async (): Promise<void> => {
      const schema = guarded(v.string().transform<number>((value: string): number => value.length));
      expect(schema.parse('abc').value).assertEqual(3);
      expect((await schema.parseAsync('ab')).value).assertEqual(2);
      expect(schema.validate('a').valid).assertTrue();
      expect((await schema.validateAsync('a')).valid).assertTrue();
      const cycle: Record<string, Object> = {}; cycle['self'] = cycle;
      expect(schema.validate(cycle).errors[0].code).assertEqual('input_cycle');
      expect((await schema.validateAsync(cycle)).valid).assertFalse();
      expect(schema.parse(cycle).success).assertFalse();
      expect((await schema.parseAsync(cycle)).success).assertFalse();
      expect(schema.describeSchema?.().unrepresentable[0]).assertEqual('guarded');
    });
    it('reports duplicate parsed keys at indexed paths', 0, async (): Promise<void> => {
      const schema = uniqueBy(v.array(v.object<Record<string, Object>>({ 'sku': v.string().required() })),
        (row: Record<string, Object>): string => row['sku'] as string, { path: 'sku', message: 'duplicate sku' });
      const rows: Record<string, Object>[] = [{ 'sku': 'a' }, { 'sku': 'b' }, { 'sku': 'a' }];
      expect(schema.validate(rows).errors[0].path).assertEqual('2.sku');
      expect((await schema.validateAsync(rows)).errors[0].message).assertEqual('duplicate sku');
      expect(schema.parse(rows).success).assertFalse();
      expect((await schema.parseAsync(rows.slice(0, 2))).success).assertTrue();
      expect(schema.validate([null]).valid).assertFalse();
      expect(schema.validate('bad').valid).assertFalse();
      expect(schema.describeSchema?.().unrepresentable[0]).assertEqual('uniqueBy');
    });
    it('checks uniqueness after transforms and distinguishes primitive types', 0, async (): Promise<void> => {
      const schema = uniqueBy(v.array(v.string().transform<string>((text: string): string => text.toLowerCase())),
        (text: string): string => text);
      expect(schema.validate(['A', 'a']).valid).assertFalse();
      expect((await schema.parseAsync(['A', 'B'])).value?.[0]).assertEqual('a');
      const numbers = uniqueBy(v.array(v.number()), (n: number): number => n);
      expect(numbers.validate([0, -0]).errors[0].code).assertEqual('unique_by');
      expect(numbers.validate([1, 2]).valid).assertTrue();
    });
    it('imports exact decimal steps and exclusive limits', 0, async (): Promise<void> => {
      const schema = json('{"type":"number","multipleOf":0.01,"exclusiveMinimum":0,"exclusiveMaximum":5}');
      expect(schema.validate(4.02).valid).assertTrue();
      expect(schema.validate(4.021).valid).assertFalse();
      expect(schema.validate(0).valid).assertFalse();
      expect((await schema.parseAsync?.(5))?.success).assertFalse();
      expect(json('{"multipleOf":0.1}').validate(0.3).valid).assertTrue();
      expect(json('{"multipleOf":0.1}').validate(0.1 + 0.2).valid).assertFalse();
      expect(json('{"multipleOf":2}').validate(-6).valid).assertTrue();
      expect(json('{"multipleOf":1e-7}').validate(3e-7).valid).assertTrue();
      expect(json('{"multipleOf":1e20}').validate(2e20).valid).assertTrue();
      expect(json('{"multipleOf":2}').validate('anything').valid).assertTrue();
    });
    it('uses structural array equality and preserves item constraints', 0, async (): Promise<void> => {
      const schema = json('{"uniqueItems":true}');
      const duplicate = JSON.parse('[{"a":1,"b":[2]},{"b":[2],"a":1}]') as Object[];
      expect(schema.validate(duplicate).errors[0].path).assertEqual('1');
      expect((await schema.parseAsync?.(duplicate))?.success).assertFalse();
      expect(schema.validate(JSON.parse('[1,"1",true,null,[],{}]') as Object[]).valid).assertTrue();
      expect(schema.validate([]).valid).assertTrue();
      expect(json('{"uniqueItems":false}').validate([1, 1]).valid).assertTrue();
      expect(json('{"type":"array","items":{"type":"number"},"uniqueItems":true}').validate(['a']).valid).assertFalse();
    });
    it('counts contains matches including zero and absent contains', 0, async (): Promise<void> => {
      const schema = json('{"contains":{"type":"number"},"minContains":1,"maxContains":2}');
      expect(schema.validate(['x', 1]).valid).assertTrue();
      expect(schema.validate([]).valid).assertFalse();
      expect((await schema.validateAsync([1, 2, 3])).valid).assertFalse();
      expect(json('{"contains":false,"minContains":0,"maxContains":0}').validate([1]).valid).assertTrue();
      expect(json('{"minContains":8,"maxContains":0}').validate([1]).valid).assertTrue();
      expect(json('{"contains":true}').validate([]).valid).assertFalse();
      expect(schema.validate('not an array').valid).assertTrue();
    });
    it('selects conditional branches without leaking predicate errors', 0, async (): Promise<void> => {
      const schema = json('{"type":"number","if":{"minimum":10},"then":{"multipleOf":2},"else":{"minimum":0}}');
      expect(schema.validate(12).valid).assertTrue();
      expect(schema.validate(11).errors[0].code).assertEqual('multiple_of');
      expect(schema.parse?.(-1).success).assertFalse();
      expect((await schema.validateAsync(3)).valid).assertTrue();
      expect((await schema.parseAsync?.(11))?.success).assertFalse();
      expect(json('{"then":false,"else":false}').validate(1).valid).assertTrue();
      expect(json('{"if":false,"then":false}').validate(1).valid).assertTrue();
      expect(json('{"if":true,"else":false}').validate(1).valid).assertTrue();
      expect(json('{"if":false,"else":false}').validate(1).valid).assertFalse();
    });
    it('diagnoses malformed extended keywords and nested unsupported rules', 0, (): void => {
      const invalid = JSON.parse('{"multipleOf":0,"exclusiveMinimum":true,"exclusiveMaximum":"x","minContains":-1,"uniqueItems":1,"contains":{"unknown":true},"if":{"$ref":"#"}}') as Record<string, Object>;
      expect(inspectJSONSchema(invalid).length >= 7).assertTrue();
      let threw = false; try { fromJSONSchema(invalid, { strict: true }); } catch (_error) { threw = true; }
      expect(threw).assertTrue();
      threw = false; try { fromJSONSchema(JSON.parse('{"multipleOf":0}') as Record<string, Object>); } catch (_error) { threw = true; }
      expect(threw).assertTrue();
    });
  });
}
