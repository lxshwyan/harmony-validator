import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

const VIN_LETTERS: string = 'ABCDEFGHJKLMNPRSTUVWXYZ';
const VIN_VALUES: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 7, 9, 2, 3, 4, 5, 6, 7, 8, 9];
const VIN_WEIGHTS: number[] = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2];

export function isVIN(value: string): boolean {
  return /^[A-HJ-NPR-Z0-9]{17}$/.test(value);
}

export function isVINChecksum(value: string): boolean {
  if (!isVIN(value)) {
    return false;
  }
  let sum = 0;
  for (let i = 0; i < value.length; i++) {
    const char = value.charAt(i);
    let number = 0;
    if (/^\d$/.test(char)) {
      number = parseInt(char, 10);
    } else {
      const index = VIN_LETTERS.indexOf(char);
      if (index === -1) {
        return false;
      }
      number = VIN_VALUES[index];
    }
    sum += number * VIN_WEIGHTS[i];
  }
  const remainder = sum % 11;
  const expected = remainder === 10 ? 'X' : `${remainder}`;
  return value.charAt(8) === expected;
}

export const vinRule: StringRulePlugin = new BasicStringRulePlugin(
  'vin', ErrorCode.VIN, '请输入正确的车架号', isVIN,
  { 'en-US': 'Invalid VIN' }
);
export const vinChecksumRule: StringRulePlugin = new BasicStringRulePlugin(
  'vinChecksum', ErrorCode.VIN_CHECKSUM, '请输入校验位正确的车架号', isVINChecksum,
  { 'en-US': 'Invalid VIN checksum' }
);
