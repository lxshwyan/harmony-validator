import { ValidateError } from './types';
import { ErrorCode, issue, validationError } from './i18n';

/** 条件必填：当兄弟字段满足 predicate 时该字段必填。 */
export interface RequiredWhenCond {
  field: string;
  predicate: (other: Object | null | undefined) => boolean;
  message?: string;
}

/**
 * 必填 / 可选 / 条件必填 的公共状态与判定，供各 Schema 复用，保证行为一致。
 * 各 Schema 持有一个实例，`required()`/`optional()`/`requiredWhen()` 委托到这里，
 * 并在「空值」分支调用 `message(siblings)` 决定是否报必填错误。
 */
export class RequiredState {
  private isRequired: boolean = false;
  private isOptional: boolean = false;
  private requiredMsg?: string;
  private whenConds: RequiredWhenCond[] = [];

  markRequired(message?: string): void {
    this.isRequired = true;
    this.isOptional = false;
    if (message !== undefined) {
      this.requiredMsg = message;
    }
  }

  markOptional(): void {
    this.isOptional = true;
    this.isRequired = false;
  }

  addWhen(field: string, predicate: (other: Object | null | undefined) => boolean, message?: string): void {
    this.isOptional = false;
    this.isRequired = false;
    this.whenConds.push({ field, predicate, message: message ?? this.requiredMsg });
  }

  requiredForDescription(): boolean {
    return this.isRequired && !this.isOptional;
  }

  conditionallyRequiredForDescription(): boolean {
    return !this.isOptional && !this.isRequired && this.whenConds.length > 0;
  }

  /** 空值时返回结构化必填错误；无需报错则返回 null。 */
  error(siblings?: Record<string, Object>, label?: string): ValidateError | null {
    if (this.isOptional) {
      return null;
    }
    if (this.isRequired) {
      return validationError(issue(ErrorCode.REQUIRED, this.requiredMsg), label);
    }
    for (const c of this.whenConds) {
      const other: Object | null | undefined = siblings === undefined ? undefined : siblings[c.field];
      let matched = false;
      try {
        matched = c.predicate(other);
      } catch (e) {
        // 条件函数异常时按“条件成立”处理：空字段应安全失败，而不是让整个表单崩溃。
        matched = true;
      }
      if (matched) {
        return validationError(issue(ErrorCode.REQUIRED_WHEN, c.message), label);
      }
    }
    return null;
  }
}
