import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { liteV } from '../main/ets/lite';
import { ErrorCode } from '../main/ets/core/i18n';
import {
  BasicStringRulePlugin, getStringRule, registerStringRule, StringRulePlugin, unregisterStringRule
} from '../main/ets/plugins/StringRulePlugin';
import { registerAllStringRules } from '../main/ets/rules/registerAll';
import { isMobile, mobileRule } from '../main/ets/rules/mobile';
import { isIdCard, idCardRule } from '../main/ets/rules/idCard';
import { isBankCard, bankCardRule } from '../main/ets/rules/bankCard';

export default function v070Test(): void {
  describe('0.7 on-demand rules', (): void => {
    it('uses mobile plugin through the lightweight factory', 0, (): void => {
      const schema = liteV.string().required().use(mobileRule);
      expect(schema.validate('13800138000').valid).assertTrue();
      const result = schema.validate('123');
      expect(result.errors[0].code).assertEqual(ErrorCode.PHONE);
      expect(result.errors[0].message).assertEqual('请输入正确的手机号');
      expect(isMobile('19912345678')).assertTrue();
    });

    it('imports ID-card and bank-card modules independently', 0, (): void => {
      expect(liteV.string().use(idCardRule).validate('11010519491231002X').valid).assertTrue();
      expect(liteV.string().use(bankCardRule).validate('6259650871772098').valid).assertTrue();
      expect(isIdCard('123')).assertFalse();
      expect(isBankCard('123')).assertFalse();
    });

    it('keeps the compatibility main entry and repeated registration stable', 0, (): void => {
      registerAllStringRules();
      registerAllStringRules();
      expect(v.string().phone().validate('13800138000').valid).assertTrue();
      expect(v.string().idCard().validate('123').valid).assertFalse();
    });

    it('lightweight factory retains non-China schema factories', 0, async (): Promise<void> => {
      liteV.setLocale('zh-CN');
      expect(liteV.getLocale()).assertEqual('zh-CN');
      liteV.addLocale('lite-test', { 'required': 'LITE REQUIRED' });
      liteV.setLocale('lite-test');
      expect(liteV.string().required().validate('').errors[0].message).assertEqual('LITE REQUIRED');
      liteV.setLocale('zh-CN');
      expect(liteV.number().min(1).validate(0).valid).assertFalse();
      expect(liteV.boolean().isTrue().validate(false).valid).assertFalse();
      expect(liteV.enumOf(['a']).validate('a').valid).assertTrue();
      expect(liteV.date().validate('2024-01-01').valid).assertTrue();
      expect(liteV.literal('ok').validate('ok').valid).assertTrue();
      expect(liteV.union<string>([liteV.literal('a')]).validate('b').valid).assertFalse();
      expect(liteV.array(liteV.string()).validate(['ok']).valid).assertTrue();
      expect(liteV.object({ 'name': liteV.string() }).validate({ 'name': 'ok' } as Record<string, Object>).valid)
        .assertTrue();
      expect((await liteV.string().validateAsync('ok')).valid).assertTrue();
    });
  });

  describe('0.7 custom string-rule plugins', (): void => {
    it('applies custom codes, labels, locale messages and explicit messages', 0, (): void => {
      const plugin: StringRulePlugin = new BasicStringRulePlugin(
        'startsWithA', 'starts_with_a', '必须以 A 开头',
        (value: string): boolean => value.startsWith('A'),
        { 'en-US': 'Must start with A' }
      );
      const schema = liteV.string().label('Code').use(plugin);
      liteV.setLocale('en-US');
      const english = schema.validate('bad');
      expect(english.errors[0].code).assertEqual('starts_with_a');
      expect(english.errors[0].message).assertEqual('Code: Must start with A');
      liteV.setLocale('zh-CN');
      expect(schema.validate('bad').errors[0].message).assertEqual('Code：必须以 A 开头');
      expect(liteV.string().use(plugin, '自定义失败').validate('bad').errors[0].message).assertEqual('自定义失败');
    });

    it('falls back to registered Chinese plugin messages for incomplete locales', 0, (): void => {
      const plugin = new BasicStringRulePlugin(
        'evenLength', 'even_length', '长度必须为偶数', (value: string): boolean => value.length % 2 === 0
      );
      liteV.setLocale('empty-plugin-locale');
      expect(liteV.string().use(plugin).validate('a').errors[0].message).assertEqual('长度必须为偶数');
      liteV.setLocale('zh-CN');
    });

    it('converts plugin exceptions to validation errors', 0, (): void => {
      const plugin = new BasicStringRulePlugin(
        'throwing', 'throwing_rule', '插件执行失败', (_value: string): boolean => {
          throw new Error('boom');
        }
      );
      const result = liteV.string().use(plugin).validate('value');
      expect(result.valid).assertFalse();
      expect(result.errors[0].code).assertEqual('throwing_rule');
      expect(result.errors[0].message).assertEqual('插件执行失败');
    });

    it('runs optional async plugin rules only in async validation', 0, async (): Promise<void> => {
      const plugin = new BasicStringRulePlugin(
        'remoteAvailable', 'remote_available', '远程规则失败', (_value: string): boolean => true,
        { 'en-US': 'Remote rule failed' },
        (value: string): Promise<boolean> => {
          if (value === 'throw') {
            return Promise.reject(new Error('network'));
          }
          return Promise.resolve(value === 'available');
        }
      );
      const schema = liteV.string().use(plugin);
      expect(schema.validate('taken').valid).assertTrue();
      expect((await schema.validateAsync('available')).valid).assertTrue();
      expect((await schema.validateAsync('taken')).errors[0].code).assertEqual('remote_available');
      expect((await schema.validateAsync('throw')).errors[0].message).assertEqual('远程规则失败');
      expect(await mobileRule.validateAsync?.('anything')).assertTrue();
    });

    it('registers, resolves, replaces and unregisters named plugins', 0, (): void => {
      const first = new BasicStringRulePlugin(
        'businessRule', 'business_first', '第一版失败', (value: string): boolean => value === 'first'
      );
      const second = new BasicStringRulePlugin(
        'businessRule', 'business_second', '第二版失败', (value: string): boolean => value === 'second'
      );
      registerStringRule(first);
      expect(getStringRule('businessRule')?.code).assertEqual('business_first');
      expect(liteV.string().useRegistered('businessRule').validate('first').valid).assertTrue();
      registerStringRule(second);
      expect(liteV.string().useRegistered('businessRule').validate('first').errors[0].code)
        .assertEqual('business_second');
      expect(unregisterStringRule('businessRule')).assertTrue();
      expect(unregisterStringRule('businessRule')).assertFalse();
      expect(getStringRule('businessRule')).assertUndefined();
    });

    it('reports missing named plugins with stable localized errors', 0, (): void => {
      liteV.setLocale('en-US');
      const english = liteV.string().useRegistered('not-installed').validate('value');
      expect(english.errors[0].code).assertEqual(ErrorCode.PLUGIN_MISSING);
      expect(english.errors[0].message).assertEqual('String rule plugin is not registered: not-installed');
      liteV.setLocale('zh-CN');
      expect(liteV.string().useRegistered('not-installed', '缺少业务规则').validate('value').errors[0].message)
        .assertEqual('缺少业务规则');
    });
  });
}
