import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { AnySchema, SchemaDescriptor, ValidateResult } from '../main/ets/core/types';
import { FormValidator, FormTrigger } from '../main/ets/form/FormValidator';
import { LazySchema } from '../main/ets/schemas/CompositionSchemas';
import { fromJSONSchema } from '../main/ets/core/interop';
import { inspectJSONSchema, JSONSchemaImportError, JSONSchemaDiagnostic } from '../main/ets/core/JSONImportDiagnostics';
import { ValidationOptions, ValidationCancellationToken, validateValueAsync, validateBatchAsync } from '../main/ets/core/errors';

class FailingRequestSchema implements AnySchema<string> {
  readonly __schemaType: string | null = null;
  cleaned: boolean = false;
  validate(_value: Object | null | undefined): ValidateResult { return { valid: true, errors: [] }; }
  async validateAsync(_value: Object | null | undefined, _siblings?: Record<string, Object>, options?: ValidationOptions): Promise<ValidateResult> {
    options?.cancellation?.onCancel((): void => { this.cleaned = true; });
    throw new Error('request failed');
  }
}

export default function v120ExpansionTest(): void {
  describe('1.2 complete feature scope', (): void => {
    it('notifies cleanup on third-party rejection without hiding the exception', 0, async (): Promise<void> => {
      const schema = new FailingRequestSchema();
      let message = '';
      try { await validateValueAsync(schema, 'x', { timeoutMs: 1000 }); }
      catch (error) { message = (error as Error).message; }
      expect(message).assertEqual('request failed');
      expect(schema.cleaned).assertTrue();
    });
    it('revalidates dynamic requirements and disposes pending change events', 0, async (): Promise<void> => {
      let selections = 0;
      const form = new FormValidator({ 'mode': v.string(),
        'company': v.when<string>('mode', (value: Object | null | undefined): boolean => { selections++; return value === 'business'; },
          v.string().required(), v.string()) },
        { triggers: [FormTrigger.CHANGE], debounceMs: 2, fields: { 'company': { dependencies: ['mode'] } } });
      const business: Record<string, Object> = { 'mode': 'business', 'company': '' };
      await form.onChange('mode', 'business', business);
      expect(form.getState().errors['company'] !== undefined).assertTrue();
      const personal: Record<string, Object> = { 'mode': 'personal', 'company': '' };
      await form.onChange('mode', 'personal', personal);
      expect(form.getState().errors['company'] === undefined).assertTrue();
      expect(Object.keys(await form.submit(personal)).length).assertEqual(0);
      const pending = form.onChange('mode', 'business', business);
      const beforeDispose = selections;
      form.dispose();
      await pending;
      expect(form.getState().submitting).assertFalse();
      expect(form.getFieldState('mode').validating).assertFalse();
      expect(form.getState().errors['company'] === undefined).assertTrue();
      expect(selections).assertEqual(beforeDispose);
    });
    it('converts recursive update models lazily with stable recursive descriptors', 0, async (): Promise<void> => {
      let calls = 0;
      const tree: LazySchema<Record<string, Object>> = v.lazy<Record<string, Object>>((): AnySchema<Record<string, Object>> => {
        calls++;
        return v.object({ 'name': v.string().required(), 'children': v.array(tree) });
      });
      const patch = tree.deepPartial();
      expect(calls).assertEqual(0);
      const leaf: Record<string, Object> = {};
      const branch: Record<string, Object> = { 'children': [leaf] };
      const input: Record<string, Object> = { 'children': [branch] };
      expect(patch.validate(input).valid).assertTrue();
      expect((await patch.parseAsync(input)).success).assertTrue();
      expect(tree.validate(input).valid).assertFalse();
      expect(calls).assertEqual(1);
      const descriptor = patch.describeSchema();
      const children = descriptor.inner?.properties?.['children'] as SchemaDescriptor;
      expect(children.items === descriptor).assertTrue();
      expect(tree.deepPartial() === patch).assertFalse();
    });
    it('preserves mutual recursion through wrappers', 0, (): void => {
      const first: LazySchema<Record<string, Object>> = v.lazy<Record<string, Object>>((): AnySchema<Record<string, Object>> =>
        v.object({ 'name': v.string().required(), 'next': second.transform((value: Record<string, Object>): Record<string, Object> => value) }));
      const second: LazySchema<Record<string, Object>> = v.lazy<Record<string, Object>>((): AnySchema<Record<string, Object>> =>
        v.object({ 'age': v.number().required(), 'next': first.transform((value: Record<string, Object>): Record<string, Object> => value) }));
      const leaf: Record<string, Object> = {};
      const middle: Record<string, Object> = { 'next': leaf };
      const input: Record<string, Object> = { 'next': middle };
      expect(first.deepPartial().validate(input).valid).assertTrue();
      expect(first.validate(input).valid).assertFalse();
    });
    it('requires known discriminators for partial variants and rejects inherited keys', 0, async (): Promise<void> => {
      const source = v.discriminatedUnion<Record<string, Object>>('kind', {
        'person': v.object({ 'kind': v.literal('person'), 'name': v.string().required().min(3) })
      }).label('account');
      const patch = source.deepPartial();
      const input: Record<string, Object> = { 'kind': 'person' };
      const invalid: Record<string, Object> = { 'kind': 'person', 'name': 'x' };
      const inherited: Record<string, Object> = { 'kind': 'toString' };
      expect(patch.validate(input).valid).assertTrue();
      expect((await patch.parseAsync(input)).success).assertTrue();
      expect(source.validate(input).valid).assertFalse();
      expect(patch.validate(invalid).valid).assertFalse();
      expect(patch.validate({} as Record<string, Object>).errors[0].path).assertEqual('kind');
      expect(patch.validate(inherited).valid).assertFalse();
      expect((await patch.validateAsync(inherited)).valid).assertFalse();
      expect(patch.parse(inherited).success).assertFalse();
    });
    it('reports nested unsupported keywords with escaped pointers', 0, (): void => {
      const input = JSON.parse('{"properties":{"a/b~":{"type":"number","multipleOf":2}}}') as Record<string, Object>;
      const issues = inspectJSONSchema(input);
      expect(issues.length).assertEqual(1);
      expect(issues[0].path).assertEqual('#/properties/a~1b~0/multipleOf');
      const received: JSONSchemaDiagnostic[] = [];
      fromJSONSchema(input, { onDiagnostic: (item: JSONSchemaDiagnostic): void => { received.push(item); } });
      expect(received.length).assertEqual(1);
      let rejected = false;
      try { fromJSONSchema(input, { strict: true }); }
      catch (error) { rejected = error instanceof JSONSchemaImportError; }
      expect(rejected).assertTrue();
    });
    it('rejects non-progressing references but allows recursive property references', 0, (): void => {
      for (const source of ['{"$ref":"#"}', '{"anyOf":[{"$ref":"#"}]}',
        '{"$defs":{"a":{"$ref":"#/$defs/a"}},"$ref":"#/$defs/a"}']) {
        expect(inspectJSONSchema(JSON.parse(source) as Record<string, Object>).length > 0).assertTrue();
      }
      const tree = JSON.parse('{"type":"object","properties":{"child":{"$ref":"#"}}}') as Record<string, Object>;
      expect(inspectJSONSchema(tree).length).assertEqual(0);
      const leaf: Record<string, Object> = {};
      const input: Record<string, Object> = { 'child': leaf };
      expect(fromJSONSchema(tree, { strict: true }).validate(input).valid).assertTrue();
    });
    it('imports boolean schemas and rejects false array items', 0, (): void => {
      expect(fromJSONSchema(true, { strict: true }).validate(null).valid).assertTrue();
      expect(fromJSONSchema(false, { strict: true }).validate('x').valid).assertFalse();
      const schema = fromJSONSchema(JSON.parse('{"type":"array","items":false}') as Record<string, Object>, { strict: true });
      expect(schema.validate([]).valid).assertTrue();
      expect(schema.validate([1]).valid).assertFalse();
    });
    it('does not treat empty form input as a JSON numeric or boolean value', 0, async (): Promise<void> => {
      for (const type of ['number', 'integer', 'boolean']) {
        const source: Record<string, Object> = { 'type': type };
        const schema = fromJSONSchema(source, { strict: true });
        expect(schema.validate('').valid).assertFalse();
        expect((await schema.validateAsync('')).valid).assertFalse();
        expect(schema.parse?.('').success).assertFalse();
        expect((await schema.parseAsync?.(''))?.success).assertFalse();
      }
    });
    it('restores lazy descriptor state after a factory failure', 0, (): void => {
      let calls = 0;
      const schema = v.lazy<string>((): AnySchema<string> => {
        calls++;
        if (calls === 1) throw new Error('factory unavailable');
        return v.string();
      });
      let threw = false;
      try { schema.deepPartial().describeSchema(); } catch (_error) { threw = true; }
      expect(threw).assertTrue();
      expect(schema.describeSchema().inner?.kind).assertEqual('string');
    });
    it('keeps direct async parse cancellation and context request-local', 0, async (): Promise<void> => {
      const cancelled = new ValidationCancellationToken();
      cancelled.cancel();
      const schema = v.number().customAsync(async (value: number, options?: ValidationOptions): Promise<boolean> =>
        value === options?.context?.['expected'], 'mismatch');
      expect((await schema.parseAsync(2, undefined, { context: { 'expected': 2 } })).success).assertTrue();
      expect((await schema.parseAsync(2, undefined, { cancellation: cancelled })).errors[0].code).assertEqual('cancelled');
      expect((await schema.parseAsync(2, undefined, { context: { 'expected': 3 } })).success).assertFalse();
    });
    it('diagnoses malformed constraints and unsupported semantic combinations before conversion', 0, (): void => {
      const cases = [
        '{"type":["string","null"]}', '{"format":"not-registered"}', '{"const":{"x":1}}',
        '{"enum":[]}', '{"enum":[{}]}', '{"minLength":-1}', '{"maximum":"bad"}',
        '{"pattern":"["}', '{"pattern":1}', '{"allOf":[]}', '{"properties":[]}',
        '{"items":5}', '{"required":[1]}', '{"required":["missing"]}',
        '{"properties":{"x":{}},"additionalProperties":{"type":"string"}}',
        '{"$ref":"remote.json"}', '{"$ref":"#/$defs/missing"}'
      ];
      for (const source of cases) expect(inspectJSONSchema(JSON.parse(source) as Record<string, Object>).length > 0).assertTrue();
      const valid = JSON.parse('{"$defs":{"n":{"type":"number"}},"$ref":"#/$defs/n","maximum":4}') as Record<string, Object>;
      expect(inspectJSONSchema(valid).length).assertEqual(0);
      expect(fromJSONSchema(valid, { strict: true }).validate(5).valid).assertFalse();
    });
    it('cancellation notifications are idempotent removable and exception-isolated', 0, (): void => {
      const token = new ValidationCancellationToken();
      let calls = 0;
      const unsubscribe = token.onCancel((): void => { calls += 100; });
      unsubscribe(); unsubscribe();
      token.onCancel((): void => { throw new Error('cleanup failure'); });
      token.onCancel((): void => { calls++; });
      token.cancel(); token.cancel();
      token.onCancel((): void => { calls++; });
      expect(calls).assertEqual(2);
    });
    it('cancels a pending custom request and stops subsequent rules', 0, async (): Promise<void> => {
      const parent = new ValidationCancellationToken();
      let released = 0;
      let later = 0;
      const schema = v.string().customAsync((_value: string, options?: ValidationOptions): Promise<boolean> =>
        new Promise<boolean>((resolve): void => {
          options?.cancellation?.onCancel((): void => { released++; resolve(true); });
        }), 'remote').customAsync(async (): Promise<boolean> => { later++; return true; }, 'later');
      const task = validateValueAsync(schema, 'x', { cancellation: parent });
      parent.cancel();
      expect((await task).errors[0].code).assertEqual('cancelled');
      expect(released).assertEqual(1);
      expect(later).assertEqual(0);
    });
    it('timeout notifies the request without cancelling the caller token', 0, async (): Promise<void> => {
      const parent = new ValidationCancellationToken();
      let released = 0;
      const schema = v.number().customAsync((_value: number, options?: ValidationOptions): Promise<boolean> =>
        new Promise<boolean>((resolve): void => {
          options?.cancellation?.onCancel((): void => { released++; resolve(false); });
        }), 'remote');
      const result = await validateValueAsync(schema, 1, { cancellation: parent, timeoutMs: 5 });
      expect(result.errors[0].code).assertEqual('timeout');
      expect(released).assertEqual(1);
      expect(parent.isCancelled()).assertFalse();
    });
    it('detaches completed operations and isolates batch request signals', 0, async (): Promise<void> => {
      const parent = new ValidationCancellationToken();
      const tokens: ValidationCancellationToken[] = [];
      const schema = v.number().customAsync(async (_value: number, options?: ValidationOptions): Promise<boolean> => {
        tokens.push(options?.cancellation as ValidationCancellationToken);
        return true;
      }, 'remote');
      const results = await validateBatchAsync(schema, [1, 2], { cancellation: parent, concurrency: 2 });
      expect(results.length).assertEqual(2);
      expect(tokens[0] === tokens[1]).assertFalse();
      parent.cancel();
      expect(tokens[0].isCancelled()).assertFalse();
      expect(tokens[1].isCancelled()).assertFalse();
    });
  });
}
