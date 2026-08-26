import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import {
  AnySchema, SchemaDescriptor, SchemaMetadata, ValidateResult
} from '../main/ets/core/types';
import { schemaToDescriptor, serializeSchema, toJSONSchema } from '../main/ets/core/schema';
import { BasicStringRulePlugin } from '../main/ets/plugins/StringRulePlugin';

class ThirdPartySchema implements AnySchema<string> {
  readonly __schemaType: string | null = null;

  validate(_value: Object | null | undefined): ValidateResult {
    return { valid: true, errors: [] };
  }

  async validateAsync(_value: Object | null | undefined): Promise<ValidateResult> {
    return { valid: true, errors: [] };
  }
}

function record(value: Object): Record<string, Object> {
  return value as Record<string, Object>;
}

export default function v080Test(): void {
  describe('0.8 schema metadata and descriptors', (): void => {
    it('describes string metadata, label, required state and standard rules', 0, (): void => {
      const metadata: SchemaMetadata = {
        id: 'user-name', title: '用户名', description: '初始说明', examples: ['alice'], deprecated: false,
      };
      const schema = v.string().meta(metadata);
      metadata.title = '调用方后来修改的标题';
      metadata.examples?.push('bob');
      const descriptor = schema.describe('登录用户名').label('用户名')
        .required().min(2).max(20).pattern(/^[a-z]+$/i).describeSchema();
      expect(descriptor.kind).assertEqual('string');
      expect(descriptor.required).assertTrue();
      expect(descriptor.label).assertEqual('用户名');
      expect(descriptor.metadata?.description).assertEqual('登录用户名');
      expect(descriptor.metadata?.title).assertEqual('用户名');
      expect(descriptor.metadata?.examples?.length).assertEqual(1);
      expect(descriptor.rules.length).assertEqual(3);
      if (descriptor.metadata !== undefined) {
        descriptor.metadata.title = '外部修改描述快照';
      }
      descriptor.rules[0].name = 'external-change';
      const fresh = schema.describeSchema();
      expect(fresh.metadata?.title).assertEqual('用户名');
      expect(fresh.rules[0].name).assertEqual('minLength');
    });

    it('tracks optional and conditional required state without changing validation', 0, (): void => {
      const conditional = v.number().requiredWhen('enabled', (value: Object | null | undefined): boolean =>
        value === true).describeSchema();
      expect(conditional.required).assertFalse();
      expect(conditional.conditionallyRequired).assertTrue();
      expect(v.number().required().optional().describeSchema().required).assertFalse();
      expect(v.boolean().required().describeSchema().required).assertTrue();
      const lastConditional = v.string().required().requiredWhen('enabled',
        (value: Object | null | undefined): boolean => value === true);
      expect(lastConditional.describeSchema().required).assertFalse();
      expect(lastConditional.describeSchema().conditionallyRequired).assertTrue();
      expect(lastConditional.validate(undefined, { 'enabled': false }).valid).assertTrue();
      expect(lastConditional.validate(undefined, { 'enabled': true }).valid).assertFalse();
    });

    it('describes every primitive rule family', 0, (): void => {
      expect(v.number().meta({ title: '年龄' }).describe('年龄说明').label('年龄')
        .min(1).max(120).integer().positive().describeSchema().rules.length).assertEqual(4);
      expect(v.boolean().meta({ title: '同意' }).describe('协议').label('协议')
        .isTrue().isFalse().describeSchema().rules.length).assertEqual(1);
      expect(v.date().meta({ title: '日期' }).describe('日期说明').label('日期').strict()
        .min('2024-01-01').max('2025-01-01').describeSchema().rules.length).assertEqual(3);
      expect(v.enumOf(['draft', 'done']).meta({ title: '状态' }).describe('状态说明')
        .label('状态').describeSchema().rules.length).assertEqual(2);
      expect(v.literal('ready').meta({ title: '常量' }).describe('常量说明')
        .label('常量').describeSchema().value).assertEqual('ready');
    });

    it('describes nested objects, arrays and unions recursively', 0, (): void => {
      const schema = v.object({
        'name': v.string().required(),
        'tags': v.array(v.string()).min(1).max(3).nonEmpty(),
        'mode': v.union<string>([v.literal('a').required(), v.literal('b').required()]),
      }).meta({ title: '配置' }).describe('配置对象').label('配置')
        .refine((_value: Record<string, Object>): boolean => true, '对象规则');
      const descriptor = schema.describeSchema();
      const properties = descriptor.properties as Record<string, SchemaDescriptor>;
      expect(descriptor.kind).assertEqual('object');
      expect(descriptor.required).assertTrue();
      expect(properties['tags'].items?.kind).assertEqual('string');
      expect(properties['mode'].options.length).assertEqual(2);
      expect(properties['mode'].required).assertTrue();
      expect(descriptor.rules[0].standard).assertFalse();
      expect(v.object({}).optional().describeSchema().required).assertFalse();
    });

    it('describes nullable, default and transform wrapper chains', 0, (): void => {
      const schema = v.string().required().nullable().meta({ title: '可空值' }).describe('允许 null')
        .label('值').default('fallback').meta({ title: '默认值' }).describe('有默认值')
        .label('结果').transform<number>((value: string | null): number => value === null ? 0 : value.length)
        .meta({ title: '转换值' }).describe('运行时转换').label('长度');
      const descriptor = schema.describeSchema();
      expect(descriptor.kind).assertEqual('transform');
      expect(descriptor.inner?.kind).assertEqual('default');
      expect(descriptor.inner?.inner?.kind).assertEqual('nullable');
      expect(descriptor.unrepresentable[0]).assertEqual('runtime-transform');
      expect(descriptor.required).assertFalse();
    });

    it('marks custom, async, plugin and missing-plugin rules as extensions', 0, (): void => {
      const plugin = new BasicStringRulePlugin('startsA', 'starts_a', 'A',
        (value: string): boolean => value.startsWith('A'));
      const descriptor = v.string()
        .custom((_value: string): boolean => true, 'ok')
        .customAsync((_value: string): Promise<boolean> => Promise.resolve(true), 'ok')
        .use(plugin).useRegistered('descriptor-missing').describeSchema();
      expect(descriptor.rules.length).assertEqual(4);
      expect(descriptor.rules[0].standard).assertFalse();
      expect(descriptor.rules[1].async).assertTrue();
    });

    it('uses an explicit placeholder for third-party schemas', 0, (): void => {
      const descriptor = schemaToDescriptor(new ThirdPartySchema());
      expect(descriptor.kind).assertEqual('custom');
      expect(descriptor.unrepresentable[0]).assertEqual('third-party-schema');
    });
  });

  describe('0.8 JSON Schema conversion and serialization', (): void => {
    it('converts a nested object to draft 2020-12 JSON Schema', 0, (): void => {
      const schema = v.object({
        'name': v.string().required().min(5).min(2).max(10).max(20)
          .pattern(/^[a-z]+$/).pattern(/^.{2,}$/),
        'age': v.number().min(0).max(150).integer(),
        'active': v.boolean().isTrue(),
        'roles': v.array(v.enumOf(['admin', 'user'])).min(1),
      }).meta({ id: 'https://example.com/user', title: 'User', description: 'User schema' });
      const json = toJSONSchema(schema);
      const properties = record(json['properties']);
      const name = record(properties['name']);
      const age = record(properties['age']);
      expect(json['$schema']).assertEqual('https://json-schema.org/draft/2020-12/schema');
      expect(json['$id']).assertEqual('https://example.com/user');
      expect(json['title']).assertEqual('User');
      expect((json['required'] as Array<Object>)[0]).assertEqual('name');
      expect(name['minLength']).assertEqual(5);
      expect(name['maxLength']).assertEqual(10);
      expect((name['allOf'] as Array<Object>).length).assertEqual(2);
      expect(age['type']).assertEqual('integer');
      expect(age['maximum']).assertEqual(150);
    });

    it('maps formats, literals, enums, unions, nullable and defaults', 0, (): void => {
      expect(toJSONSchema(v.string().email())['format']).assertEqual('email');
      expect(toJSONSchema(v.string().url())['format']).assertEqual('uri');
      expect(toJSONSchema(v.string().ipv4())['format']).assertEqual('ipv4');
      expect(toJSONSchema(v.literal('ok'))['const']).assertEqual('ok');
      expect((toJSONSchema(v.enumOf([1, 2]))['enum'] as Array<Object>).length).assertEqual(2);
      expect((toJSONSchema(v.union<string>([v.literal('a'), v.literal('b')]))['anyOf'] as Array<Object>).length)
        .assertEqual(2);
      expect((toJSONSchema(v.string().nullable())['anyOf'] as Array<Object>).length).assertEqual(2);
      expect(toJSONSchema(v.string().default('guest'))['default']).assertEqual('guest');
    });

    it('emits date and non-standard rule extensions', 0, (): void => {
      const date = toJSONSchema(v.date().strict().min('2024-01-01'));
      expect((date['anyOf'] as Array<Object>).length).assertEqual(2);
      expect((date['x-hmkit-input-types'] as Array<Object>).length).assertEqual(3);
      expect((date['x-hmkit-unrepresentable'] as Array<Object>).length).assertEqual(2);
      const plugin = toJSONSchema(v.string().phone().label('手机'));
      expect(plugin['x-hmkit-label']).assertEqual('手机');
      expect((plugin['x-hmkit-unrepresentable'] as Array<Object>)[0]).assertEqual('plugin:phone');
    });

    it('supports extension, ignore and throw policies', 0, (): void => {
      const transformed = v.string().transform<number>((value: string): number => value.length);
      // 内层 descriptor 已携带 runtime-transform，默认扩展模式应明确标出；ignore 则移除。
      const extension = toJSONSchema(transformed, 'extension');
      expect((extension['x-hmkit-unrepresentable'] as Array<Object>).length).assertEqual(1);
      expect(toJSONSchema(transformed, 'ignore')['x-hmkit-unrepresentable']).assertUndefined();
      let thrown = false;
      try {
        toJSONSchema(transformed, 'throw');
      } catch (_error) {
        thrown = true;
      }
      expect(thrown).assertTrue();
      let invalidMode = false;
      try {
        toJSONSchema(v.string(), 'invalid');
      } catch (_error) {
        invalidMode = true;
      }
      expect(invalidMode).assertTrue();
      let flagsThrown = false;
      try {
        toJSONSchema(v.string().pattern(/abc/i), 'throw');
      } catch (_error) {
        flagsThrown = true;
      }
      expect(flagsThrown).assertTrue();
    });

    it('serializes descriptors deterministically without serializing functions', 0, (): void => {
      const schema = v.string().meta({ title: 'Name' }).min(2)
        .custom((_value: string): boolean => true, 'ok');
      const first = serializeSchema(schema);
      const second = serializeSchema(schema);
      expect(first).assertEqual(second);
      expect(first.includes('Name')).assertTrue();
      expect(first.includes('synchronous predicate')).assertTrue();
      expect(first.includes('function')).assertFalse();
      expect(serializeSchema(schema, 2).includes('\n')).assertTrue();
    });
  });
}
