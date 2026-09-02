import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';
function validGroup(value: string): boolean { return /^[0-9a-fA-F]{1,4}$/.test(value); }
export function isIPv6(value: string): boolean {
  if (value.indexOf(':::') !== -1 || value.indexOf('::') !== value.lastIndexOf('::')) return false;
  const compressed = value.indexOf('::') !== -1;
  const sides = value.split('::');
  const left = sides[0] === '' ? [] : sides[0].split(':');
  const right = sides.length < 2 || sides[1] === '' ? [] : sides[1].split(':');
  for (const item of left) if (!validGroup(item)) return false;
  for (const item of right) if (!validGroup(item)) return false;
  const count = left.length + right.length;
  return compressed ? count < 8 : count === 8;
}
export const ipv6Rule: StringRulePlugin = new BasicStringRulePlugin(
  'ipv6', 'ipv6', '请输入正确的 IPv6 地址', isIPv6, { 'en-US': 'Invalid IPv6 address' });
