import { AnySchema, ValidateError, ValidateResult } from '../core/types';

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
  private isRequired: boolean = false;
  private requiredMsg: string = '该字段为必填项';

  /** 必填。 */
  required(message?: string): DateSchema {
    this.isRequired = true;
    if (message !== undefined) {
      this.requiredMsg = message;
    }
    return this;
  }

  /** 不能早于 `min`。 */
  min(min: DateLike, message?: string): DateSchema {
    const bound = toMillis(min);
    this.rules.push((ms: number): string | null =>
      ms >= bound ? null : (message ?? '日期不能早于限定值'));
    return this;
  }

  /** 不能晚于 `max`。 */
  max(max: DateLike, message?: string): DateSchema {
    const bound = toMillis(max);
    this.rules.push((ms: number): string | null =>
      ms <= bound ? null : (message ?? '日期不能晚于限定值'));
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined || value === '') {
      if (this.isRequired) {
        errors.push({ path: '', message: this.requiredMsg });
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
