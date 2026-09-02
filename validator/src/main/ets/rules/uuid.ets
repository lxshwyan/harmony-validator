import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';
export function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
export const uuidRule: StringRulePlugin = new BasicStringRulePlugin(
  'uuid', 'uuid', '请输入正确的 UUID', isUUID, { 'en-US': 'Invalid UUID' });
