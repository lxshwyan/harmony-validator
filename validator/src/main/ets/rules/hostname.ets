import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';
export function isHostname(value: string): boolean {
  if (value.length > 253 || value.endsWith('.')) return false;
  for (const label of value.split('.')) {
    if (label.length < 1 || label.length > 63 || label.startsWith('-') || label.endsWith('-') ||
      !/^[A-Za-z0-9-]+$/.test(label)) return false;
  }
  return true;
}
export const hostnameRule: StringRulePlugin = new BasicStringRulePlugin(
  'hostname', 'hostname', '请输入正确的主机名', isHostname, { 'en-US': 'Invalid hostname' });
