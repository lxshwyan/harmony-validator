import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

/** 银行卡号：12-19 位数字并通过 Luhn 校验。 */
export function isBankCard(value: string): boolean {
  if (!/^\d{12,19}$/.test(value)) {
    return false;
  }
  let sum = 0;
  let double = false;
  for (let i = value.length - 1; i >= 0; i--) {
    let digit = parseInt(value.charAt(i), 10);
    if (double) {
      digit *= 2;
      if (digit > 9) {
        digit -= 9;
      }
    }
    sum += digit;
    double = !double;
  }
  return sum % 10 === 0;
}

export const bankCardRule: StringRulePlugin = new BasicStringRulePlugin(
  'bankCard', ErrorCode.BANK_CARD, '请输入正确的银行卡号', isBankCard,
  { 'en-US': 'Invalid bank card number' }
);
