import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { toJSONSchema } from '../main/ets/core/schema';
import { validateValue, validateValueAsync } from '../main/ets/core/errors';
import { uuidRule } from '../main/ets/rules/uuid';
import { ipv6Rule } from '../main/ets/rules/ipv6';
import { base64Rule } from '../main/ets/rules/base64';
import { hostnameRule } from '../main/ets/rules/hostname';

function record(value?: Record<string, Object>): Record<string, Object> { return value ?? {}; }

export default function v110FormatsTest(): void {
  describe('1.1 modular standard formats', (): void => {
    it('validates UUID in main and independently imported modes', 0, (): void => {
      const good = '550e8400-e29b-41d4-a716-446655440000';
      expect(v.string().uuid().validate(good).valid).assertTrue();
      expect(v.string().uuid().validate('not-uuid').valid).assertFalse();
      expect(v.string().use(uuidRule).validate(good).valid).assertTrue();
      expect(toJSONSchema(v.string().uuid())['format']).assertEqual('uuid');
    });

    it('validates compressed and full IPv6 addresses', 0, (): void => {
      expect(v.string().ipv6().validate('2001:db8::1').valid).assertTrue();
      expect(v.string().use(ipv6Rule).validate('2001:db8:0:0:0:0:0:1').valid).assertTrue();
      expect(v.string().ipv6().validate('2001:::1').valid).assertFalse();
      expect(v.string().ipv6().validate('2001:db8:0:0:0:0:0:0:1').valid).assertFalse();
    });

    it('validates Base64 padding and host labels', 0, (): void => {
      expect(v.string().base64().validate('aG1raXQ=').valid).assertTrue();
      expect(v.string().use(base64Rule).validate('YWJj').valid).assertTrue();
      expect(v.string().base64().validate('abc=').valid).assertTrue();
      expect(v.string().base64().validate('a===').valid).assertFalse();
      expect(v.string().hostname().validate('api.example.com').valid).assertTrue();
      expect(v.string().use(hostnameRule).validate('-bad.example').valid).assertFalse();
      expect(v.string().hostname().validate('bad..example').valid).assertFalse();
    });
  });

  describe('1.1 validation context extension', (): void => {
    it('uses typed caller context through unified execution options', 0, async (): Promise<void> => {
      const schema = v.context<Record<string, Object>>(v.object({ 'amount': v.number().required() }),
        (value: Record<string, Object>, context: Record<string, Object>): boolean =>
          (value['amount'] as number) <= (context['limit'] as number), '超过业务额度');
      expect(validateValue(schema, record({ 'amount': 80 }), { context: record({ 'limit': 100 }) }).valid)
        .assertTrue();
      expect(validateValue(schema, record({ 'amount': 120 }), { context: record({ 'limit': 100 }) })
        .errors[0].message).assertEqual('超过业务额度');
      expect((await validateValueAsync(schema, record({ 'amount': 80 }),
        { context: record({ 'limit': 100 }) })).valid).assertTrue();
      expect(schema.parseWithContext(record({ 'amount': 80 }), record({ 'limit': 100 })).success).assertTrue();
      expect((await schema.parseAsyncWithContext(record({ 'amount': 120 }), record({ 'limit': 100 }))).success)
        .assertFalse();
    });

    it('maps predicate exceptions and documents runtime customization honestly', 0, (): void => {
      const schema = v.context<string>(v.string(), (_value: string,
        _context: Record<string, Object>): boolean => { throw new Error('business'); });
      expect(schema.validate('x').errors[0].code).assertEqual('context');
      expect(schema.describeSchema().unrepresentable[0]).assertEqual('runtime-context-predicate');
      expect((toJSONSchema(schema)['x-hmkit-unrepresentable'] as Array<Object>).length).assertEqual(1);
    });

    it('keeps context schemas composable with standard effect wrappers', 0, async (): Promise<void> => {
      const schema = v.context<string>(v.string().min(1), (value: string,
        context: Record<string, Object>): boolean => context['prefix'] === value.substring(0, 1))
        .meta({ title: '上下文字符串' }).describe('上下文规则').label('值');
      expect(schema.parseWithContext('abc', record({ 'prefix': 'a' })).success).assertTrue();
      expect(schema.parse('abc').success).assertFalse();
      expect((await schema.parseAsync('abc')).success).assertFalse();
      expect(schema.nullable().validate(null).valid).assertTrue();
      expect(schema.default('abc').parse(undefined).value).assertEqual('abc');
      expect(schema.transform<number>((value: string): number => value.length).parse('abc').success).assertFalse();
    });
  });
}
