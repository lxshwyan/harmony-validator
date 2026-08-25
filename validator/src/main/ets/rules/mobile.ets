import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

/** 中国大陆手机号：1 开头，第二位 3-9，共 11 位。 */
export function isMobile(value: string): boolean {
  return /^1[3-9]\d{9}$/.test(value);
}

export const mobileRule: StringRulePlugin = new BasicStringRulePlugin(
  'phone', ErrorCode.PHONE, '请输入正确的手机号', isMobile,
  { 'en-US': 'Invalid mobile number' }
);
