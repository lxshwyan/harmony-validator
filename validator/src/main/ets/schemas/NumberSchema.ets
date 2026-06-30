import { AnySchema, ValidateError, ValidateResult } from '../core/types';
import { RequiredState } from '../core/required';

type NumberRule = (value: number) => string | null;
type NumberAsyncRule = (value: number) => Promise<string | null>;

/** 数字校验器，支持链式调用。 */
export class NumberSchema implements AnySchema {
  private rules: NumberRule[] = [];
  private asyncRules: NumberAsyncRule[] = [];
  private req: RequiredState = new RequiredState();

  required(message?: string): NumberSchema {
    this.req.markRequired(message);
    return this;
  }

  /** 显式标记为可选（默认即可选）。 */
  optional(): NumberSchema {
    this.req.markOptional();
    return this;
  }

  /** 条件必填：当同级字段 `field` 满足 `predicate` 时本字段必填（仅 v.object 中生效）。 */
  requiredWhen(field: string, predicate: (other: Object | null | undefined) => boolean,
    message?: string): NumberSchema {
    this.req.addWhen(field, predicate, message);
    return this;
  }

  /** 最小值（含）。 */
  min(value: number, message?: string): NumberSchema {
    this.rules.push((v: number): string | null =>
      v >= value ? null : (message ?? `不能小于 ${value}`));
    return this;
  }

  /** 最大值（含）。 */
  max(value: number, message?: string): NumberSchema {
    this.rules.push((v: number): string | null =>
      v <= value ? null : (message ?? `不能大于 ${value}`));
    return this;
  }

  /** 必须为整数。 */
  integer(message?: string): NumberSchema {
    this.rules.push((v: number): string | null =>
      Number.isInteger(v) ? null : (message ?? '必须为整数'));
    return this;
  }

  /** 必须为正数。 */
  positive(message?: string): NumberSchema {
    this.rules.push((v: number): string | null =>
      v > 0 ? null : (message ?? '必须为正数'));
    return this;
  }

  custom(fn: (value: number) => boolean, message: string): NumberSchema {
    this.rules.push((v: number): string | null => fn(v) ? null : message);
    return this;
  }

  /** 自定义异步规则。返回 Promise<true> 通过。仅 validateAsync 时生效。 */
  customAsync(fn: (value: number) => Promise<boolean>, message: string): NumberSchema {
    this.asyncRules.push(async (v: number): Promise<string | null> =>
      (await fn(v)) ? null : message);
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    // 空串也视为「空值」(ArkUI 表单未填的数字输入常是 '')，与字符串保持一致
    if (value === null || value === undefined || value === '') {
      const reqMsg = this.req.message(siblings);
      if (reqMsg !== null) {
        errors.push({ path: '', message: reqMsg });
      }
      return { valid: errors.length === 0, errors };
    }
    if (typeof value !== 'number') {
      return { valid: false, errors: [{ path: '', message: '类型错误，期望数字' }] };
    }
    const num = value as number;
    if (Number.isNaN(num)) {
      return { valid: false, errors: [{ path: '', message: '不是有效的数字' }] };
    }
    for (const rule of this.rules) {
      const msg = rule(num);
      if (msg !== null) {
        errors.push({ path: '', message: msg });
      }
    }
    return { valid: errors.length === 0, errors };
  }

  /** 异步校验：先跑同步规则，再跑异步规则。 */
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    const base = this.validate(value, siblings);
    // 同步规则未通过则短路
    if (!base.valid) {
      return base;
    }
    const errors: ValidateError[] = base.errors.slice();
    if (value !== null && value !== undefined && typeof value === 'number'
      && !Number.isNaN(value as number) && this.asyncRules.length > 0) {
      const num = value as number;
      for (const rule of this.asyncRules) {
        const msg = await rule(num);
        if (msg !== null) {
          errors.push({ path: '', message: msg });
        }
      }
    }
    return { valid: errors.length === 0, errors };
  }
}
