/**
 * 单条校验错误。
 * - path: 出错的字段路径，顶层字段为字段名，嵌套用 "a.b" 表示；单值校验时为空串。
 * - message: 给用户看的错误提示。
 */
export interface ValidateError {
  path: string;
  message: string;
  /** 稳定的机器可读错误码；0.5.0 起内置规则都会提供。 */
  code?: string;
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

/** 带类型的解析结果。default/transform 等会通过 value 返回处理后的值。 */
export interface ParseResult<T> {
  success: boolean;
  value?: T;
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
export interface AnySchema<T = Object> {
  /**
   * 仅用于在 ArkTS 泛型中保留 Schema 的值类型；运行时始终为 null。
   * ArkTS 不支持 TypeScript 的 conditional type / infer，因此使用显式类型标记。
   */
  readonly __schemaType: T | null;
  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult;
  validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult>;
  /** 内置 Schema 提供的可选解析入口；保持第三方 AnySchema 实现向后兼容。 */
  parse?(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T>;
  parseAsync?(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ParseResult<T>>;
}

/** 内置 Schema 的完整接口：校验之外还可取得默认值或转换后的结果。 */
export interface ParsableSchema<T = Object> extends AnySchema<T> {
  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T>;
  parseAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ParseResult<T>>;
}
