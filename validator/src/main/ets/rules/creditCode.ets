import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

const CREDIT_CHARSET: string = '0123456789ABCDEFGHJKLMNPQRTUWXY';
const CREDIT_WEIGHTS: number[] = [1, 3, 9, 27, 19, 26, 16, 17, 20, 29, 25, 13, 8, 24, 10, 30, 28];

/** 统一社会信用代码：18 位格式 + GB 32100 校验位。 */
export function isCreditCode(value: string): boolean {
  if (!/^[0-9A-HJ-NPQRTUWXY]{2}\d{6}[0-9A-HJ-NPQRTUWXY]{10}$/.test(value)) {
    return false;
  }
  let sum = 0;
  for (let i = 0; i < 17; i++) {
    const index = CREDIT_CHARSET.indexOf(value.charAt(i));
    if (index === -1) {
      return false;
    }
    sum += index * CREDIT_WEIGHTS[i];
  }
  const check = (31 - (sum % 31)) % 31;
  return CREDIT_CHARSET.charAt(check) === value.charAt(17);
}

export const creditCodeRule: StringRulePlugin = new BasicStringRulePlugin(
  'creditCode', ErrorCode.CREDIT_CODE, '请输入正确的统一社会信用代码', isCreditCode,
  { 'en-US': 'Invalid unified social credit code' }
);
