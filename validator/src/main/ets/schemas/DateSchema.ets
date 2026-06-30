import { AnySchema, ValidateError, ValidateResult } from '../core/types';
import { RequiredState } from '../core/required';

type DateLike = Date | number | string;
type DateRule = (ms: number) => string | null;

/** 把 Date / 时间戳 / 日期字符串统一转成毫秒时间戳；无法解析返回 NaN。 */
function toMillis(value: Object): number {
  if (value instanceof Date) {
    return (value as Date).getTime();
  }
  if (typeof value === 'number') {
    return value as number;
  }
  if (typeof value === 'string') {
    return Date.parse(value as string);
  }
  return NaN;
}

/**
 * 日期校验器。接受 `Date` 对象、毫秒时间戳或可解析的日期字符串。
 * 支持 `min`(不早于) / `max`(不晚于)。
 */
export class DateSchema implements AnySchema {
  private rules: DateRule[] = [];
  private req: RequiredState = new RequiredState();

  /** 必填。 */
  required(message?: string): DateSchema {
    this.req.markRequired(message);
    return this;
  }

  /** 显式可选。 */
  optional(): DateSchema {
    this.req.markOptional();
    return this;
  }

  /** 条件必填：当同级字段满足 predicate 时本字段必填（仅 v.object 中生效）。 */
  requiredWhen(field: string, predicate: (other: Object | null | undefined) => boolean,
    message?: string): DateSchema {
    this.req.addWhen(field, predicate, message);
    return this;
  }

  /** 不能早于 `min`。若边界无法解析（NaN）则跳过该规则，避免静默全量拒绝。 */
  min(min: DateLike, message?: string): DateSchema {
    const bound = toMillis(min);
    this.rules.push((ms: number): string | null =>
      Number.isNaN(bound) || ms >= bound ? null : (message ?? '日期不能早于限定值'));
    return this;
  }

  /** 不能晚于 `max`。若边界无法解析（NaN）则跳过该规则。 */
  max(max: DateLike, message?: string): DateSchema {
    const bound = toMillis(max);
    this.rules.push((ms: number): string | null =>
      Number.isNaN(bound) || ms <= bound ? null : (message ?? '日期不能晚于限定值'));
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined || value === '') {
      const reqMsg = this.req.message(siblings);
      if (reqMsg !== null) {
        errors.push({ path: '', message: reqMsg });
      }
      return { valid: errors.length === 0, errors };
    }
    const ms = toMillis(value);
    if (Number.isNaN(ms)) {
      return { valid: false, errors: [{ path: '', message: '不是有效的日期' }] };
    }
    for (const rule of this.rules) {
      const msg = rule(ms);
      if (msg !== null) {
        errors.push({ path: '', message: msg });
      }
    }
    return { valid: errors.length === 0, errors };
  }

  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    return this.validate(value, siblings);
  }
}
