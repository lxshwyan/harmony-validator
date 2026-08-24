import { AnySchema, ValidateError, ValidateResult } from '../core/types';
import { RequiredState } from '../core/required';

export type DateLike = Date | number | string;
type DateRule = (ms: number) => string | null;

/** 把 Date / 时间戳 / 日期字符串统一转成毫秒时间戳；无法解析返回 NaN。 */
function toMillis(value: Object): number {
  if (value instanceof Date) {
    const ms = (value as Date).getTime();
    return Number.isFinite(ms) ? ms : NaN;
  }
  if (typeof value === 'number') {
    const ms = value as number;
    return Number.isFinite(ms) ? ms : NaN;
  }
  if (typeof value === 'string') {
    return Date.parse(value as string);
  }
  return NaN;
}

function isCalendarDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const year = parseInt(value.substring(0, 4), 10);
  const month = parseInt(value.substring(5, 7), 10);
  const day = parseInt(value.substring(8, 10), 10);
  if (year < 1 || month < 1 || month > 12 || day < 1) {
    return false;
  }
  const leap = (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
  const days: number[] = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return day <= days[month - 1];
}

/** 严格 ISO：YYYY-MM-DD，或带 Z / ±HH:mm 时区的日期时间。 */
function isStrictIso(value: string): boolean {
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return isCalendarDate(value);
  }
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/.test(value)) {
    return false;
  }
  if (!isCalendarDate(value.substring(0, 10))) {
    return false;
  }
  const hour = parseInt(value.substring(11, 13), 10);
  const minute = parseInt(value.substring(14, 16), 10);
  const second = parseInt(value.substring(17, 19), 10);
  if (hour > 23 || minute > 59 || second > 59) {
    return false;
  }
  if (!value.endsWith('Z')) {
    const zone = value.substring(value.length - 6);
    const zoneHour = parseInt(zone.substring(1, 3), 10);
    const zoneMinute = parseInt(zone.substring(4, 6), 10);
    if (zoneHour > 14 || zoneMinute > 59 || (zoneHour === 14 && zoneMinute !== 0)) {
      return false;
    }
  }
  return Number.isFinite(Date.parse(value));
}

/**
 * 日期校验器。接受 `Date` 对象、毫秒时间戳或可解析的日期字符串。
 * 支持 `min`(不早于) / `max`(不晚于)。
 */
export class DateSchema implements AnySchema<DateLike> {
  readonly __schemaType: DateLike | null = null;
  private rules: DateRule[] = [];
  private req: RequiredState = new RequiredState();
  private strictMode: boolean = false;
  private strictMessage: string = '请输入严格 ISO 日期';

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

  /**
   * 严格日期字符串模式：接受 YYYY-MM-DD，或带 Z / ±HH:mm 时区的 ISO 日期时间。
   * Date 对象和有限毫秒时间戳仍可使用；该模式只收紧字符串解析。
   */
  strict(message?: string): DateSchema {
    this.strictMode = true;
    this.strictMessage = message ?? '请输入严格 ISO 日期';
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
    if (this.strictMode && typeof value === 'string' && !isStrictIso(value as string)) {
      return { valid: false, errors: [{ path: '', message: this.strictMessage }] };
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
