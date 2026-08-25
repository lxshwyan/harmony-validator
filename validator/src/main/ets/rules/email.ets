import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

export function isEmail(value: string): boolean {
  return /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(value);
}

export const emailRule: StringRulePlugin = new BasicStringRulePlugin(
  'email', ErrorCode.EMAIL, '请输入正确的邮箱地址', isEmail,
  { 'en-US': 'Invalid email address' }
);
