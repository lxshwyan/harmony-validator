/**
 * 中国本地化校验规则（纯函数）。
 * 这些是本库相对其它校验库的核心差异点：开箱即用、覆盖国内高频场景。
 */

/** 手机号：1 开头，第二位 3-9，共 11 位。 */
export function isMobile(value: string): boolean {
  return /^1[3-9]\d{9}$/.test(value);
}

/** 邮箱（常规校验，覆盖绝大多数真实邮箱）。 */
export function isEmail(value: string): boolean {
  return /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(value);
}

// 18 位身份证加权因子与校验码表（GB 11643-1999）
const ID_WEIGHTS: number[] = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
const ID_CHECK_CODES: string[] = ['1', '0', 'X', '9', '8', '7', '6', '5', '4', '3', '2'];

/** 18 位居民身份证号：格式 + 校验位（最后一位）。 */
export function isIdCard(value: string): boolean {
  const id = value.toUpperCase();
  if (!/^\d{17}[\dX]$/.test(id)) {
    return false;
  }
  let sum = 0;
  for (let i = 0; i < 17; i++) {
    sum += parseInt(id.charAt(i), 10) * ID_WEIGHTS[i];
  }
  return ID_CHECK_CODES[sum % 11] === id.charAt(17);
}

/** 银行卡号：12-19 位数字，且通过 Luhn 校验。 */
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

/** 车牌号：普通燃油车（蓝牌）与新能源车牌均支持。 */
export function isPlateNumber(value: string): boolean {
  const normal = /^[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼使领][A-HJ-NP-Z][A-HJ-NP-Z0-9]{4}[A-HJ-NP-Z0-9挂学警港澳]$/;
  const newEnergy = /^[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼][A-HJ-NP-Z](([0-9]{5}[DABCEFGHJK])|([DABCEFGHJK][A-HJ-NP-Z0-9][0-9]{4}))$/;
  return normal.test(value) || newEnergy.test(value);
}

/** 统一社会信用代码：18 位。 */
export function isCreditCode(value: string): boolean {
  return /^[0-9A-HJ-NPQRTUWXY]{2}\d{6}[0-9A-HJ-NPQRTUWXY]{10}$/.test(value);
}

/** 邮政编码：6 位数字。 */
export function isPostalCode(value: string): boolean {
  return /^[1-9]\d{5}$/.test(value);
}

/** 固定电话/座机：区号(3-4位)可选，号码 7-8 位，区号与号码间可有「-」。 */
export function isLandline(value: string): boolean {
  return /^(0\d{2,3}-?)?\d{7,8}$/.test(value);
}

/** 车架号 VIN：17 位，由数字和大写字母组成，不含 I、O、Q。 */
export function isVIN(value: string): boolean {
  return /^[A-HJ-NPR-Z0-9]{17}$/.test(value);
}

/** IPv4 地址。 */
export function isIPv4(value: string): boolean {
  return /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/.test(value);
}

/** 中文姓名：2-16 个汉字，允许间隔号「·」(少数民族姓名)。 */
export function isChineseName(value: string): boolean {
  return /^[一-龥][一-龥·]{1,15}$/.test(value);
}

/** QQ 号：5-11 位数字，首位非 0。 */
export function isQQ(value: string): boolean {
  return /^[1-9][0-9]{4,10}$/.test(value);
}

/** 微信号：字母开头，6-20 位，可含字母、数字、下划线、减号。 */
export function isWechat(value: string): boolean {
  return /^[a-zA-Z][a-zA-Z0-9_-]{5,19}$/.test(value);
}

/** http(s) URL。 */
export function isUrl(value: string): boolean {
  return /^https?:\/\/[^\s/$.?#][^\s]*$/i.test(value);
}
