import { registerStringRule } from '../plugins/StringRulePlugin';
import { mobileRule } from './mobile';
import { emailRule } from './email';
import { idCardRule } from './idCard';
import { bankCardRule } from './bankCard';
import { plateNumberRule } from './plateNumber';
import { creditCodeRule } from './creditCode';
import { postalCodeRule } from './postalCode';
import { landlineRule } from './landline';
import { ipv4Rule } from './ipv4';
import { chineseNameRule } from './chineseName';
import { qqRule } from './qq';
import { wechatRule } from './wechat';
import { urlRule } from './url';
import { vinRule, vinChecksumRule } from './vin';

let registered: boolean = false;

/** 主入口调用一次，维持所有历史链式规则开箱即用。 */
export function registerAllStringRules(): void {
  if (registered) {
    return;
  }
  registerStringRule(mobileRule);
  registerStringRule(emailRule);
  registerStringRule(idCardRule);
  registerStringRule(bankCardRule);
  registerStringRule(plateNumberRule);
  registerStringRule(creditCodeRule);
  registerStringRule(postalCodeRule);
  registerStringRule(landlineRule);
  registerStringRule(vinRule);
  registerStringRule(vinChecksumRule);
  registerStringRule(ipv4Rule);
  registerStringRule(chineseNameRule);
  registerStringRule(qqRule);
  registerStringRule(wechatRule);
  registerStringRule(urlRule);
  registered = true;
}
