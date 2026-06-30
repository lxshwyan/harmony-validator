/** 条件必填：当兄弟字段满足 predicate 时该字段必填。 */
export interface RequiredWhenCond {
  field: string;
  predicate: (other: Object | null | undefined) => boolean;
  message: string;
}

/**
 * 必填 / 可选 / 条件必填 的公共状态与判定，供各 Schema 复用，保证行为一致。
 * 各 Schema 持有一个实例，`required()`/`optional()`/`requiredWhen()` 委托到这里，
 * 并在「空值」分支调用 `message(siblings)` 决定是否报必填错误。
 */
export class RequiredState {
  private isRequired: boolean = false;
  private isOptional: boolean = false;
  private requiredMsg: string = '该字段为必填项';
  private whenConds: RequiredWhenCond[] = [];

  markRequired(message?: string): void {
    this.isRequired = true;
    if (message !== undefined) {
      this.requiredMsg = message;
    }
  }

  markOptional(): void {
    this.isOptional = true;
    this.isRequired = false;
  }

  addWhen(field: string, predicate: (other: Object | null | undefined) => boolean, message?: string): void {
    this.whenConds.push({ field, predicate, message: message ?? this.requiredMsg });
  }

  /** 空值时返回应报的必填错误信息；无需报错则返回 null。 */
  message(siblings?: Record<string, Object>): string | null {
    if (this.isOptional) {
      return null;
    }
    if (this.isRequired) {
      return this.requiredMsg;
    }
    for (const c of this.whenConds) {
      const other: Object | null | undefined = siblings === undefined ? undefined : siblings[c.field];
      if (c.predicate(other)) {
        return c.message;
      }
    }
    return null;
  }
}
