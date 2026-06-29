/**
 * 单条校验错误。
 * - path: 出错的字段路径，顶层字段为字段名，嵌套用 "a.b" 表示；单值校验时为空串。
 * - message: 给用户看的错误提示。
 */
export interface ValidateError {
  path: string;
  message: string;
}

/**
 * 校验结果。
 * - valid: 是否全部通过。
 * - errors: 所有错误（valid 为 true 时为空数组）。
 */
export interface ValidateResult {
  valid: boolean;
  errors: ValidateError[];
}

/**
 * 所有 Schema 的公共接口：接收任意值，返回校验结果。
 * - validate: 同步校验。
 * - validateAsync: 异步校验，会同时跑同步规则和异步规则（如远程查重）。
 *   不含异步规则时，其结果与 validate 一致。
 * - siblings: 可选，当前字段所在对象（同级字段集合），供 `.requiredWhen` 等条件校验读取兄弟字段值。
 *   顶层/单值校验时为 undefined。调用方通常不需要手动传。
 */
export interface AnySchema {
  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult;
  validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult>;
}
