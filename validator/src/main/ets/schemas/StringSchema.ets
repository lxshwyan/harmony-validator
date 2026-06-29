import { AnySchema, ValidateError, ValidateResult } from '../core/types';
import { isMobile, isEmail, isIdCard, isBankCard, isPlateNumber, isCreditCode, isPostalCode } from '../rules/cn';

/** 单条字符串校验规则：返回 null 表示通过，返回字符串表示错误提示。 */
type StringRule = (value: string) => string | null;

/** 字符串校验器，支持链式调用。 */
export class StringSchema implements AnySchema {
  private rules: StringRule[] = [];
  private isRequired: boolean = false;
  private requiredMsg: string = '该字段为必填项';

  /** 标记为必填。空串/未填会报错。 */
  required(message?: string): StringSchema {
    this.isRequired = true;
    if (message !== undefined) {
      this.requiredMsg = message;
    }
    return this;
  }

  /** 最小长度。 */
  min(len: number, message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      value.length >= len ? null : (message ?? `长度不能少于 ${len} 个字符`));
    return this;
  }

  /** 最大长度。 */
  max(len: number, message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      value.length <= len ? null : (message ?? `长度不能超过 ${len} 个字符`));
    return this;
  }

  /** 自定义正则。 */
  pattern(re: RegExp, message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      re.test(value) ? null : (message ?? '格式不正确'));
    return this;
  }

  /** 自定义规则。返回 true 通过。 */
  custom(fn: (value: string) => boolean, message: string): StringSchema {
    this.rules.push((value: string): string | null => fn(value) ? null : message);
    return this;
  }

  email(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isEmail(value) ? null : (message ?? '请输入正确的邮箱地址'));
    return this;
  }

  phone(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isMobile(value) ? null : (message ?? '请输入正确的手机号'));
    return this;
  }

  idCard(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isIdCard(value) ? null : (message ?? '请输入正确的身份证号'));
    return this;
  }

  bankCard(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isBankCard(value) ? null : (message ?? '请输入正确的银行卡号'));
    return this;
  }

  plateNumber(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isPlateNumber(value) ? null : (message ?? '请输入正确的车牌号'));
    return this;
  }

  creditCode(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isCreditCode(value) ? null : (message ?? '请输入正确的统一社会信用代码'));
    return this;
  }

  postalCode(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isPostalCode(value) ? null : (message ?? '请输入正确的邮政编码'));
    return this;
  }

  validate(value: Object | null | undefined): ValidateResult {
    const errors: ValidateError[] = [];
    const isEmpty = value === null || value === undefined || value === '';
    if (isEmpty) {
      if (this.isRequired) {
        errors.push({ path: '', message: this.requiredMsg });
      }
      return { valid: errors.length === 0, errors };
    }
    if (typeof value !== 'string') {
      return { valid: false, errors: [{ path: '', message: '类型错误，期望字符串' }] };
    }
    const str = value as string;
    for (const rule of this.rules) {
      const msg = rule(str);
      if (msg !== null) {
        errors.push({ path: '', message: msg });
      }
    }
    return { valid: errors.length === 0, errors };
  }
}
