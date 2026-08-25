import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

export function isLandline(value: string): boolean {
  return /^0\d{2,3}-?\d{7,8}$/.test(value);
}

export const landlineRule: StringRulePlugin = new BasicStringRulePlugin(
  'landline', ErrorCode.LANDLINE, '请输入正确的固定电话', isLandline,
  { 'en-US': 'Invalid landline number' }
);
