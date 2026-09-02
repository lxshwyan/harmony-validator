import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';
export function isBase64(value: string): boolean {
  const padding = value.indexOf('=');
  return value.length % 4 === 0 && /^[A-Za-z0-9+/]+={0,2}$/.test(value) &&
    (padding === -1 || padding >= value.length - 2);
}
export const base64Rule: StringRulePlugin = new BasicStringRulePlugin(
  'base64', 'base64', '请输入正确的 Base64 字符串', isBase64, { 'en-US': 'Invalid Base64 string' });
