import { AnySchema, ValidateError, ValidateResult } from '../core/types';
import { RequiredState } from '../core/required';
import { isMobile, isEmail, isIdCard, isBankCard, isPlateNumber, isCreditCode, isPostalCode,
  isLandline, isVIN, isIPv4, isChineseName, isQQ, isWechat, isUrl } from '../rules/cn';

/** 单条字符串校验规则：返回 null 表示通过，返回字符串表示错误提示。 */
type StringRule = (value: string) => string | null;
/** 单条异步字符串校验规则：返回 null 表示通过，返回字符串表示错误提示。 */
type StringAsyncRule = (value: string) => Promise<string | null>;

/** 字符串校验器，支持链式调用。 */
export class StringSchema implements AnySchema {
  private rules: StringRule[] = [];
  private asyncRules: StringAsyncRule[] = [];
  private req: RequiredState = new RequiredState();

  /** 标记为必填。空串/未填会报错。 */
  required(message?: string): StringSchema {
    this.req.markRequired(message);
    return this;
  }

  /** 显式标记为可选（默认即可选）。空值跳过所有规则、直接通过。 */
  optional(): StringSchema {
    this.req.markOptional();
    return this;
  }

  /**
   * 条件必填：当同级(兄弟)字段 `field` 的值满足 `predicate` 时，本字段必填。
   * 例：`v.string().requiredWhen('type', t => t === 'company', '企业必须填写')`
   * 仅在对象校验(v.object)中生效——需要兄弟字段上下文。
   */
  requiredWhen(field: string, predicate: (other: Object | null | undefined) => boolean,
    message?: string): StringSchema {
    this.req.addWhen(field, predicate, message);
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

  /**
   * 自定义异步规则。返回 Promise<true> 通过。
   * 典型场景：远程查重（如用户名/手机号是否已注册）。
   * 仅在调用 validateAsync 时生效；同步 validate 会忽略异步规则。
   */
  customAsync(fn: (value: string) => Promise<boolean>, message: string): StringSchema {
    this.asyncRules.push(async (value: string): Promise<string | null> =>
      (await fn(value)) ? null : message);
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

  /** 固定电话/座机。 */
  landline(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isLandline(value) ? null : (message ?? '请输入正确的固定电话'));
    return this;
  }

  /** 车架号 VIN（17 位）。 */
  vin(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isVIN(value) ? null : (message ?? '请输入正确的车架号'));
    return this;
  }

  /** IPv4 地址。 */
  ipv4(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isIPv4(value) ? null : (message ?? '请输入正确的 IPv4 地址'));
    return this;
  }

  /** 中文姓名。 */
  chineseName(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isChineseName(value) ? null : (message ?? '请输入正确的中文姓名'));
    return this;
  }

  /** QQ 号。 */
  qq(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isQQ(value) ? null : (message ?? '请输入正确的 QQ 号'));
    return this;
  }

  /** 微信号。 */
  wechat(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isWechat(value) ? null : (message ?? '请输入正确的微信号'));
    return this;
  }

  /** http(s) URL。 */
  url(message?: string): StringSchema {
    this.rules.push((value: string): string | null =>
      isUrl(value) ? null : (message ?? '请输入正确的网址'));
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    const isEmpty = value === null || value === undefined || value === '';
    if (isEmpty) {
      const reqMsg = this.req.message(siblings);
      if (reqMsg !== null) {
        errors.push({ path: '', message: reqMsg });
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

  /** 异步校验：先跑同步规则，再跑异步规则（如远程查重）。 */
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    const base = this.validate(value, siblings);
    // 同步规则未通过则短路，不浪费异步规则（如一次远程查重请求）
    if (!base.valid) {
      return base;
    }
    const errors: ValidateError[] = base.errors.slice();
    const isEmpty = value === null || value === undefined || value === '';
    // 仅在值存在、类型正确、且有异步规则时才跑异步校验
    if (!isEmpty && typeof value === 'string' && this.asyncRules.length > 0) {
      const str = value as string;
      for (const rule of this.asyncRules) {
        const msg = await rule(str);
        if (msg !== null) {
          errors.push({ path: '', message: msg });
        }
      }
    }
    return { valid: errors.length === 0, errors };
  }
}
