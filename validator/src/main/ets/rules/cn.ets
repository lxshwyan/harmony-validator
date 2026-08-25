/** 兼容聚合入口；需要减小依赖图时请从独立规则模块导入。 */
export { isMobile, mobileRule } from './mobile';
export { isEmail, emailRule } from './email';
export { isIdCard, idCardRule } from './idCard';
export { isBankCard, bankCardRule } from './bankCard';
export { isPlateNumber, plateNumberRule } from './plateNumber';
export { isCreditCode, creditCodeRule } from './creditCode';
export { isPostalCode, postalCodeRule } from './postalCode';
export { isLandline, landlineRule } from './landline';
export { isIPv4, ipv4Rule } from './ipv4';
export { isChineseName, chineseNameRule } from './chineseName';
export { isQQ, qqRule } from './qq';
export { isWechat, wechatRule } from './wechat';
export { isUrl, urlRule } from './url';
export { isVIN, isVINChecksum, vinRule, vinChecksumRule } from './vin';
