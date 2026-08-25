import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

export function isWechat(value: string): boolean {
  return /^[a-zA-Z][a-zA-Z0-9_-]{5,19}$/.test(value);
}

export const wechatRule: StringRulePlugin = new BasicStringRulePlugin(
  'wechat', ErrorCode.WECHAT, '请输入正确的微信号', isWechat,
  { 'en-US': 'Invalid WeChat ID' }
);
