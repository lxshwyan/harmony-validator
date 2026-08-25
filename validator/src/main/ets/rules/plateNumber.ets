import { ErrorCode } from '../core/i18n';
import { BasicStringRulePlugin, StringRulePlugin } from '../plugins/StringRulePlugin';

export function isPlateNumber(value: string): boolean {
  const normal = /^[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼使领][A-HJ-NP-Z][A-HJ-NP-Z0-9]{4}[A-HJ-NP-Z0-9挂学警港澳]$/;
  const newEnergy = /^[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼][A-HJ-NP-Z](([0-9]{5}[DABCEFGHJK])|([DABCEFGHJK][A-HJ-NP-Z0-9][0-9]{4}))$/;
  return normal.test(value) || newEnergy.test(value);
}

export const plateNumberRule: StringRulePlugin = new BasicStringRulePlugin(
  'plateNumber', ErrorCode.PLATE_NUMBER, '请输入正确的车牌号', isPlateNumber,
  { 'en-US': 'Invalid plate number' }
);
