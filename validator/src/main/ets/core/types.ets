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

/** 所有 Schema 的公共接口：接收任意值，返回校验结果。 */
export interface AnySchema {
  validate(value: Object | null | undefined): ValidateResult;
}
