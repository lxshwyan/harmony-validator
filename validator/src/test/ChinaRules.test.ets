import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';

export default function chinaRulesTest(): void {
  describe('China-localized and common string rules', (): void => {
    it('email accepts common addresses and rejects malformed input', 0, (): void => {
      expect(v.string().email().validate('dev@example.com').valid).assertTrue();
      expect(v.string().email().validate('dev@localhost').valid).assertFalse();
    });

    it('plate supports standard and new-energy formats', 0, (): void => {
      expect(v.string().plateNumber().validate('京A12345').valid).assertTrue();
      expect(v.string().plateNumber().validate('粤AD12345').valid).assertTrue();
      expect(v.string().plateNumber().validate('A12345').valid).assertFalse();
    });

    it('postal code validates six non-zero-leading digits', 0, (): void => {
      expect(v.string().postalCode().validate('100000').valid).assertTrue();
      expect(v.string().postalCode().validate('000000').valid).assertFalse();
    });

    it('landline accepts optional separators', 0, (): void => {
      expect(v.string().landline().validate('010-82345678').valid).assertTrue();
      expect(v.string().landline().validate('02012345678').valid).assertTrue();
      expect(v.string().landline().validate('82345678').valid).assertFalse();
    });

    it('Chinese names support middle dots without invalid placement', 0, (): void => {
      expect(v.string().chineseName().validate('张三').valid).assertTrue();
      expect(v.string().chineseName().validate('阿·依莎').valid).assertTrue();
      expect(v.string().chineseName().validate('·张三').valid).assertFalse();
    });

    it('QQ validates length and leading digit', 0, (): void => {
      expect(v.string().qq().validate('12345').valid).assertTrue();
      expect(v.string().qq().validate('01234').valid).assertFalse();
    });

    it('WeChat ids enforce leading letters and length', 0, (): void => {
      expect(v.string().wechat().validate('abc_123').valid).assertTrue();
      expect(v.string().wechat().validate('1abcde').valid).assertFalse();
    });

    it('URL accepts HTTP protocols only', 0, (): void => {
      expect(v.string().url().validate('https://ohpm.openharmony.cn').valid).assertTrue();
      expect(v.string().url().validate('ftp://example.com').valid).assertFalse();
    });

    it('ID card rejects invalid format and calendar boundaries', 0, (): void => {
      expect(v.string().idCard().validate('123').valid).assertFalse();
      expect(v.string().idCard().validate('11010518991231002X').valid).assertFalse();
      expect(v.string().idCard().validate('11010519491331002X').valid).assertFalse();
      expect(v.string().idCard().validate('11010519490230002X').valid).assertFalse();
    });

    it('bank card rejects invalid lengths and check digits', 0, (): void => {
      expect(v.string().bankCard().validate('123').valid).assertFalse();
      expect(v.string().bankCard().validate('6259650871772099').valid).assertFalse();
    });

    it('credit code rejects malformed characters and check digits', 0, (): void => {
      expect(v.string().creditCode().validate('123').valid).assertFalse();
      expect(v.string().creditCode().validate('91350211I000100Y46').valid).assertFalse();
      expect(v.string().creditCode().validate('91350211M000100Y47').valid).assertFalse();
    });

    it('VIN rejects forbidden letters and checksum format errors', 0, (): void => {
      expect(v.string().vin().validate('1M8GDM9AIKP042788').valid).assertFalse();
      expect(v.string().vinChecksum().validate('short').valid).assertFalse();
    });

    it('IPv4 validates bounds and canonical octets', 0, (): void => {
      expect(v.string().ipv4().validate('0.0.0.0').valid).assertTrue();
      expect(v.string().ipv4().validate('255.255.255.255').valid).assertTrue();
      expect(v.string().ipv4().validate('192.168.01.1').valid).assertFalse();
    });
  });
}
