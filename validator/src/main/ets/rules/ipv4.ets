import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

export function isIPv4(value: string): boolean {
  return /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/.test(value);
}

export const ipv4Rule: StringRulePlugin = new BasicStringRulePlugin(
  'ipv4', ErrorCode.IPV4, '请输入正确的 IPv4 地址', isIPv4,
  { 'en-US': 'Invalid IPv4 address' }
);
