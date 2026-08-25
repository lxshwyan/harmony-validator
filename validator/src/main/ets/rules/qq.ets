import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

export function isQQ(value: string): boolean {
  return /^[1-9][0-9]{4,10}$/.test(value);
}

export const qqRule: StringRulePlugin = new BasicStringRulePlugin(
  'qq', ErrorCode.QQ, '请输入正确的 QQ 号', isQQ,
  { 'en-US': 'Invalid QQ number' }
);
