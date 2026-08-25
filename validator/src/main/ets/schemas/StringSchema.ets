import { ParsableSchema, ParseResult, ValidateError, ValidateResult } from '../core/types';
import { RequiredState } from '../core/required';
import { ErrorCode, issue, RuleIssue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, TransformSchema } from './EffectSchemas';
import { isMobile, isEmail, isIdCard, isBankCard, isPlateNumber, isCreditCode, isPostalCode,
  isLandline, isVIN, isVINChecksum, isIPv4, isChineseName, isQQ, isWechat, isUrl } from '../rules/cn';

/** 单条字符串校验规则：返回 null 表示通过，返回字符串表示错误提示。 */
type StringRule = (value: string) => RuleIssue | null;
/** 单条异步字符串校验规则：返回 null 表示通过，返回字符串表示错误提示。 */
type StringAsyncRule = (value: string) => Promise<RuleIssue | null>;

/** 字符串校验器，支持链式调用。 */
export class StringSchema implements ParsableSchema<string> {
  readonly __schemaType: string | null = null;
  private rules: StringRule[] = [];
  private asyncRules: StringAsyncRule[] = [];
  private req: RequiredState = new RequiredState();
  private fieldLabel: string = '';

  /** 设置显示字段名；仅影响默认/自定义错误文案，不改变错误 path。 */
  label(name: string): StringSchema {
    this.fieldLabel = name;
    return this;
  }

  nullable(): NullableSchema<string> {
    return new NullableSchema<string>(this);
  }

  default(value: string): DefaultSchema<string> {
    return new DefaultSchema<string>(this, value);
  }

  transform<U>(fn: (value: string) => U, message?: string): TransformSchema<string, U> {
    return new TransformSchema<string, U>(this, fn, message);
  }

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
    this.rules.push((value: string): RuleIssue | null =>
      value.length >= len ? null : issue(ErrorCode.STRING_MIN, message, { 'min': `${len}` }));
    return this;
  }

  /** 最大长度。 */
  max(len: number, message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      value.length <= len ? null : issue(ErrorCode.STRING_MAX, message, { 'max': `${len}` }));
    return this;
  }

  /** 自定义正则。 */
  pattern(re: RegExp, message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null => {
      // 带 g/y 标记的 RegExp.test 会推进 lastIndex；每次校验前后复位，保证结果可重复。
      re.lastIndex = 0;
      const passed = re.test(value);
      re.lastIndex = 0;
      return passed ? null : issue(ErrorCode.PATTERN, message);
    });
    return this;
  }

  /** 自定义规则。返回 true 通过。 */
  custom(fn: (value: string) => boolean, message: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null => {
      try {
        return fn(value) ? null : issue(ErrorCode.CUSTOM, message);
      } catch (e) {
        return issue(ErrorCode.CUSTOM, message);
      }
    });
    return this;
  }

  /**
   * 自定义异步规则。返回 Promise<true> 通过。
   * 典型场景：远程查重（如用户名/手机号是否已注册）。
   * 仅在调用 validateAsync 时生效；同步 validate 会忽略异步规则。
   */
  customAsync(fn: (value: string) => Promise<boolean>, message: string): StringSchema {
    this.asyncRules.push(async (value: string): Promise<RuleIssue | null> => {
      try {
        return (await fn(value)) ? null : issue(ErrorCode.CUSTOM, message);
      } catch (e) {
        return issue(ErrorCode.CUSTOM, message);
      }
    });
    return this;
  }

  email(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isEmail(value) ? null : issue(ErrorCode.EMAIL, message));
    return this;
  }

  phone(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isMobile(value) ? null : issue(ErrorCode.PHONE, message));
    return this;
  }

  idCard(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isIdCard(value) ? null : issue(ErrorCode.ID_CARD, message));
    return this;
  }

  bankCard(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isBankCard(value) ? null : issue(ErrorCode.BANK_CARD, message));
    return this;
  }

  plateNumber(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isPlateNumber(value) ? null : issue(ErrorCode.PLATE_NUMBER, message));
    return this;
  }

  creditCode(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isCreditCode(value) ? null : issue(ErrorCode.CREDIT_CODE, message));
    return this;
  }

  postalCode(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isPostalCode(value) ? null : issue(ErrorCode.POSTAL_CODE, message));
    return this;
  }

  /** 固定电话/座机。 */
  landline(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isLandline(value) ? null : issue(ErrorCode.LANDLINE, message));
    return this;
  }

  /** 车架号 VIN（17 位）。 */
  vin(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isVIN(value) ? null : issue(ErrorCode.VIN, message));
    return this;
  }

  /** 车架号 VIN：17 位格式 + ISO 3779 第 9 位校验位。 */
  vinChecksum(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isVINChecksum(value) ? null : issue(ErrorCode.VIN_CHECKSUM, message));
    return this;
  }

  /** IPv4 地址。 */
  ipv4(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isIPv4(value) ? null : issue(ErrorCode.IPV4, message));
    return this;
  }

  /** 中文姓名。 */
  chineseName(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isChineseName(value) ? null : issue(ErrorCode.CHINESE_NAME, message));
    return this;
  }

  /** QQ 号。 */
  qq(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isQQ(value) ? null : issue(ErrorCode.QQ, message));
    return this;
  }

  /** 微信号。 */
  wechat(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isWechat(value) ? null : issue(ErrorCode.WECHAT, message));
    return this;
  }

  /** http(s) URL。 */
  url(message?: string): StringSchema {
    this.rules.push((value: string): RuleIssue | null =>
      isUrl(value) ? null : issue(ErrorCode.URL, message));
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    const isEmpty = value === null || value === undefined || value === '';
    if (isEmpty) {
      const reqError = this.req.error(siblings, this.fieldLabel);
      if (reqError !== null) {
        errors.push(reqError);
      }
      return { valid: errors.length === 0, errors };
    }
    if (typeof value !== 'string') {
      return { valid: false, errors: [validationError(issue(ErrorCode.TYPE_STRING), this.fieldLabel)] };
    }
    const str = value as string;
    for (const rule of this.rules) {
      const currentIssue = rule(str);
      if (currentIssue !== null) {
        errors.push(validationError(currentIssue, this.fieldLabel));
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
        const currentIssue = await rule(str);
        if (currentIssue !== null) {
          errors.push(validationError(currentIssue, this.fieldLabel));
        }
      }
    }
    return { valid: errors.length === 0, errors };
  }

  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<string> {
    const result = this.validate(value, siblings);
    return result.valid ? { success: true, value: value as string, errors: [] }
      : { success: false, errors: result.errors };
  }

  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<string>> {
    const result = await this.validateAsync(value, siblings);
    return result.valid ? { success: true, value: value as string, errors: [] }
      : { success: false, errors: result.errors };
  }
}
