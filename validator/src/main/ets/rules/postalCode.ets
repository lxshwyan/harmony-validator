import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

export function isPostalCode(value: string): boolean {
  return /^[1-9]\d{5}$/.test(value);
}

export const postalCodeRule: StringRulePlugin = new BasicStringRulePlugin(
  'postalCode', ErrorCode.POSTAL_CODE, '请输入正确的邮政编码', isPostalCode,
  { 'en-US': 'Invalid postal code' }
);
