import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

export function isUrl(value: string): boolean {
  return /^https?:\/\/[^\s/$.?#][^\s]*$/i.test(value);
}

export const urlRule: StringRulePlugin = new BasicStringRulePlugin(
  'url', ErrorCode.URL, '请输入正确的网址', isUrl,
  { 'en-US': 'Invalid URL' }
);
