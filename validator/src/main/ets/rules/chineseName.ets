import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

export function isChineseName(value: string): boolean {
  return /^[一-龥](·?[一-龥]){1,15}$/.test(value);
}

export const chineseNameRule: StringRulePlugin = new BasicStringRulePlugin(
  'chineseName', ErrorCode.CHINESE_NAME, '请输入正确的中文姓名', isChineseName,
  { 'en-US': 'Invalid Chinese name' }
);
