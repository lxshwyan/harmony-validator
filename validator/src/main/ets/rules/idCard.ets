import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

const ID_WEIGHTS: number[] = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
const ID_CHECK_CODES: string[] = ['1', '0', 'X', '9', '8', '7', '6', '5', '4', '3', '2'];

function isRealDate(year: number, month: number, day: number): boolean {
  if (year < 1900 || year > 2100 || month < 1 || month > 12 || day < 1) {
    return false;
  }
  const leap = (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
  const days: number[] = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (day > days[month - 1]) {
    return false;
  }
  const today = new Date();
  const currentYear = today.getFullYear();
  const currentMonth = today.getMonth() + 1;
  const currentDay = today.getDate();
  return year < currentYear
    || (year === currentYear && month < currentMonth)
    || (year === currentYear && month === currentMonth && day <= currentDay);
}

/** 18 位居民身份证号：格式、出生日期与 GB 11643 校验位。 */
export function isIdCard(value: string): boolean {
  const id = value.toUpperCase();
  if (!/^\d{17}[\dX]$/.test(id)) {
    return false;
  }
  const year = parseInt(id.substring(6, 10), 10);
  const month = parseInt(id.substring(10, 12), 10);
  const day = parseInt(id.substring(12, 14), 10);
  if (!isRealDate(year, month, day)) {
    return false;
  }
  let sum = 0;
  for (let i = 0; i < 17; i++) {
    sum += parseInt(id.charAt(i), 10) * ID_WEIGHTS[i];
  }
  return ID_CHECK_CODES[sum % 11] === id.charAt(17);
}

export const idCardRule: StringRulePlugin = new BasicStringRulePlugin(
  'idCard', ErrorCode.ID_CARD, '请输入正确的身份证号', isIdCard,
  { 'en-US': 'Invalid ID card number' }
);
