import { AnySchema, ValidateError, ValidateResult } from '../core/types';
import { RequiredState } from '../core/required';

/**
 * 枚举校验器：值必须是给定集合中的一个（用 === 比较）。
 * 适用于字符串/数字枚举，如 `v.enumOf(['male', 'female'])`、`v.enumOf([1, 2, 3])`。
 */
export class EnumSchema implements AnySchema {
  private values: Array<Object>;
  private req: RequiredState = new RequiredState();
  private message: string;

  constructor(values: Array<Object>, message?: string) {
    this.values = values;
    this.message = message ?? `取值必须是：${values.join(' / ')}`;
  }

  /** 必填。 */
  required(message?: string): EnumSchema {
    this.req.markRequired(message);
    return this;
  }

  /** 显式可选。 */
  optional(): EnumSchema {
    this.req.markOptional();
    return this;
  }

  /** 条件必填：当同级字段满足 predicate 时本字段必填（仅 v.object 中生效）。 */
  requiredWhen(field: string, predicate: (other: Object | null | undefined) => boolean,
    message?: string): EnumSchema {
    this.req.addWhen(field, predicate, message);
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    // null/undefined 一定是空值；'' 仅当它不是合法枚举值时才当空值
    // （这样 '' 本身是合法选项时按成员校验通过，否则 required 能正常报「必填」）
    const isEmpty = value === null || value === undefined
      || (value === '' && this.values.indexOf('') === -1);
    if (isEmpty) {
      const reqMsg = this.req.message(siblings);
      if (reqMsg !== null) {
        errors.push({ path: '', message: reqMsg });
      }
      return { valid: errors.length === 0, errors };
    }
    if (this.values.indexOf(value) === -1) {
      errors.push({ path: '', message: this.message });
    }
    return { valid: errors.length === 0, errors };
  }

  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    return this.validate(value, siblings);
  }
}
