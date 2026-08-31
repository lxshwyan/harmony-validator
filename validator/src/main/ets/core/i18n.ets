import { ValidateError } from './types';

/** 内置稳定错误码。业务层可据此埋点、翻译或映射 UI。 */
export class ErrorCode {
  static readonly REQUIRED: string = 'required';
  static readonly REQUIRED_WHEN: string = 'required_when';
  static readonly TYPE_STRING: string = 'type_string';
  static readonly TYPE_NUMBER: string = 'type_number';
  static readonly TYPE_BOOLEAN: string = 'type_boolean';
  static readonly TYPE_ARRAY: string = 'type_array';
  static readonly TYPE_OBJECT: string = 'type_object';
  static readonly TUPLE_LENGTH: string = 'tuple_length';
  static readonly DISCRIMINATOR: string = 'discriminator';
  static readonly UNKNOWN_KEY: string = 'unknown_key';
  static readonly PREPROCESS: string = 'preprocess';
  static readonly COERCE: string = 'coerce';
  static readonly INVALID_NUMBER: string = 'invalid_number';
  static readonly INVALID_DATE: string = 'invalid_date';
  static readonly STRICT_DATE: string = 'strict_date';
  static readonly STRING_MIN: string = 'string_min';
  static readonly STRING_MAX: string = 'string_max';
  static readonly PATTERN: string = 'pattern';
  static readonly CUSTOM: string = 'custom';
  static readonly EMAIL: string = 'email';
  static readonly PHONE: string = 'phone';
  static readonly ID_CARD: string = 'id_card';
  static readonly BANK_CARD: string = 'bank_card';
  static readonly PLATE_NUMBER: string = 'plate_number';
  static readonly CREDIT_CODE: string = 'credit_code';
  static readonly POSTAL_CODE: string = 'postal_code';
  static readonly LANDLINE: string = 'landline';
  static readonly VIN: string = 'vin';
  static readonly VIN_CHECKSUM: string = 'vin_checksum';
  static readonly IPV4: string = 'ipv4';
  static readonly CHINESE_NAME: string = 'chinese_name';
  static readonly QQ: string = 'qq';
  static readonly WECHAT: string = 'wechat';
  static readonly URL: string = 'url';
  static readonly NUMBER_MIN: string = 'number_min';
  static readonly NUMBER_MAX: string = 'number_max';
  static readonly INTEGER: string = 'integer';
  static readonly POSITIVE: string = 'positive';
  static readonly BOOLEAN_TRUE: string = 'boolean_true';
  static readonly BOOLEAN_FALSE: string = 'boolean_false';
  static readonly ENUM: string = 'enum';
  static readonly DATE_MIN: string = 'date_min';
  static readonly DATE_MAX: string = 'date_max';
  static readonly ARRAY_MIN: string = 'array_min';
  static readonly ARRAY_MAX: string = 'array_max';
  static readonly OBJECT_REQUIRED: string = 'object_required';
  static readonly REFINE: string = 'refine';
  static readonly LITERAL: string = 'literal';
  static readonly UNION: string = 'union';
  static readonly TRANSFORM: string = 'transform';
  static readonly PLUGIN_MISSING: string = 'plugin_missing';
}

export type MessageCatalog = Record<string, string>;
export type MessageParams = Record<string, string>;

export interface RuleIssue {
  code: string;
  customMessage?: string;
  params?: MessageParams;
}

const ZH_CN: MessageCatalog = {
  'required': '该字段为必填项',
  'required_when': '该字段为必填项',
  'type_string': '类型错误，期望字符串',
  'type_number': '类型错误，期望数字',
  'type_boolean': '类型错误，期望布尔值',
  'type_array': '类型错误，期望数组',
  'type_object': '类型错误，期望对象',
  'tuple_length': '数组长度必须为 {length}',
  'discriminator': '无法根据字段 {field} 匹配候选类型',
  'unknown_key': '不允许未知字段：{key}',
  'preprocess': '值预处理失败',
  'coerce': '无法转换为目标类型',
  'invalid_number': '不是有效的数字',
  'invalid_date': '不是有效的日期',
  'strict_date': '请输入严格 ISO 日期',
  'string_min': '长度不能少于 {min} 个字符',
  'string_max': '长度不能超过 {max} 个字符',
  'pattern': '格式不正确',
  'custom': '自定义校验未通过',
  'email': '请输入正确的邮箱地址',
  'phone': '请输入正确的手机号',
  'id_card': '请输入正确的身份证号',
  'bank_card': '请输入正确的银行卡号',
  'plate_number': '请输入正确的车牌号',
  'credit_code': '请输入正确的统一社会信用代码',
  'postal_code': '请输入正确的邮政编码',
  'landline': '请输入正确的固定电话',
  'vin': '请输入正确的车架号',
  'vin_checksum': '请输入校验位正确的车架号',
  'ipv4': '请输入正确的 IPv4 地址',
  'chinese_name': '请输入正确的中文姓名',
  'qq': '请输入正确的 QQ 号',
  'wechat': '请输入正确的微信号',
  'url': '请输入正确的网址',
  'number_min': '不能小于 {min}',
  'number_max': '不能大于 {max}',
  'integer': '必须为整数',
  'positive': '必须为正数',
  'boolean_true': '必须为是',
  'boolean_false': '必须为否',
  'enum': '取值必须是：{values}',
  'date_min': '日期不能早于限定值',
  'date_max': '日期不能晚于限定值',
  'array_min': '至少需要 {min} 项',
  'array_max': '最多 {max} 项',
  'object_required': '对象不能为空',
  'refine': '对象校验未通过',
  'literal': '取值必须为 {expected}',
  'union': '取值不符合任一候选类型',
  'transform': '值转换失败',
  'plugin_missing': '字符串规则插件未注册：{name}',
};

const EN_US: MessageCatalog = {
  'required': 'This field is required',
  'required_when': 'This field is required',
  'type_string': 'Expected a string',
  'type_number': 'Expected a number',
  'type_boolean': 'Expected a boolean',
  'type_array': 'Expected an array',
  'type_object': 'Expected an object',
  'tuple_length': 'Expected exactly {length} items',
  'discriminator': 'No variant matches discriminator {field}',
  'unknown_key': 'Unknown key is not allowed: {key}',
  'preprocess': 'Value preprocessing failed',
  'coerce': 'Value cannot be coerced to the target type',
  'invalid_number': 'Invalid number',
  'invalid_date': 'Invalid date',
  'strict_date': 'Expected a strict ISO date',
  'string_min': 'Must contain at least {min} characters',
  'string_max': 'Must contain at most {max} characters',
  'pattern': 'Invalid format',
  'custom': 'Custom validation failed',
  'email': 'Invalid email address',
  'phone': 'Invalid mobile number',
  'id_card': 'Invalid ID card number',
  'bank_card': 'Invalid bank card number',
  'plate_number': 'Invalid plate number',
  'credit_code': 'Invalid unified social credit code',
  'postal_code': 'Invalid postal code',
  'landline': 'Invalid landline number',
  'vin': 'Invalid VIN',
  'vin_checksum': 'Invalid VIN checksum',
  'ipv4': 'Invalid IPv4 address',
  'chinese_name': 'Invalid Chinese name',
  'qq': 'Invalid QQ number',
  'wechat': 'Invalid WeChat ID',
  'url': 'Invalid URL',
  'number_min': 'Must be at least {min}',
  'number_max': 'Must be at most {max}',
  'integer': 'Must be an integer',
  'positive': 'Must be positive',
  'boolean_true': 'Must be true',
  'boolean_false': 'Must be false',
  'enum': 'Must be one of: {values}',
  'date_min': 'Date is earlier than the minimum',
  'date_max': 'Date is later than the maximum',
  'array_min': 'Must contain at least {min} items',
  'array_max': 'Must contain at most {max} items',
  'object_required': 'Object is required',
  'refine': 'Object validation failed',
  'literal': 'Must equal {expected}',
  'union': 'Value does not match any union member',
  'transform': 'Value transformation failed',
  'plugin_missing': 'String rule plugin is not registered: {name}',
};

/** 全局语言配置。默认 zh-CN；缺失词条回退到 zh-CN。 */
export class ValidatorI18n {
  private static currentLocale: string = 'zh-CN';
  private static catalogs: Map<string, MessageCatalog> = new Map<string, MessageCatalog>();

  private static ensureBuiltIns(): void {
    if (!ValidatorI18n.catalogs.has('zh-CN')) {
      ValidatorI18n.catalogs.set('zh-CN', ZH_CN);
      ValidatorI18n.catalogs.set('en-US', EN_US);
    }
  }

  static setLocale(locale: string): void {
    ValidatorI18n.ensureBuiltIns();
    ValidatorI18n.currentLocale = locale;
  }

  static getLocale(): string {
    return ValidatorI18n.currentLocale;
  }

  /** 注册或增量覆盖语言包。 */
  static addLocale(locale: string, messages: MessageCatalog): void {
    ValidatorI18n.ensureBuiltIns();
    const existing = ValidatorI18n.catalogs.get(locale);
    const merged: MessageCatalog = {};
    if (existing !== undefined) {
      for (const key of Object.keys(existing)) {
        merged[key] = existing[key];
      }
    }
    for (const key of Object.keys(messages)) {
      merged[key] = messages[key];
    }
    ValidatorI18n.catalogs.set(locale, merged);
  }

  static resolve(issue: RuleIssue, label?: string): string {
    ValidatorI18n.ensureBuiltIns();
    let template = issue.customMessage;
    if (template === undefined) {
      const active = ValidatorI18n.catalogs.get(ValidatorI18n.currentLocale);
      template = active === undefined ? undefined : active[issue.code];
      if (template === undefined) {
        const fallback = ValidatorI18n.catalogs.get('zh-CN');
        template = fallback === undefined ? issue.code : (fallback[issue.code] ?? issue.code);
      }
    }
    const templateUsesLabel = template.indexOf('{label}') !== -1;
    const actualLabel = label ?? '';
    template = template.split('{label}').join(actualLabel);
    const params = issue.params;
    if (params !== undefined) {
      for (const key of Object.keys(params)) {
        template = template.split(`{${key}}`).join(params[key]);
      }
    }
    if (actualLabel !== '' && !templateUsesLabel) {
      const separator = ValidatorI18n.currentLocale === 'zh-CN' ? '：' : ': ';
      return `${actualLabel}${separator}${template}`;
    }
    return template;
  }
}

export function issue(code: string, customMessage?: string, params?: MessageParams): RuleIssue {
  return { code, customMessage, params };
}

export function validationError(value: RuleIssue, label?: string, path?: string): ValidateError {
  return {
    path: path ?? '',
    message: ValidatorI18n.resolve(value, label),
    code: value.code,
  };
}
