import { AnySchema, ValidateError, ValidateResult } from './types';
import { ErrorCode, issue, validationError } from './i18n';

/** 一次校验的非破坏性执行选项。 */
export interface ValidationOptions {
  /** true 时只向调用方返回第一条错误；不会改变 Schema 自身默认行为。 */
  abortEarly?: boolean;
  /** 最多返回多少条错误；小于 1 时按 1 处理。 */
  maxErrors?: number;
  /** 供 ContextSchema 等扩展读取的业务上下文。 */
  context?: Record<string, Object>;
  /** Cooperative cancellation; onCancel lets custom rules release their own resources. */
  cancellation?: ValidationCancellationToken;
  /** Async batch worker count, default 1. Must be a positive integer. */
  concurrency?: number;
  /** Per-item deadline; notifies cooperative custom rules but cannot force an external request to stop. */
  timeoutMs?: number;
}

export interface ConfigurableSchema<T> extends AnySchema<T> {
  validateWithOptions(value: Object | null | undefined, options?: ValidationOptions): ValidateResult;
  validateAsyncWithOptions(value: Object | null | undefined, options?: ValidationOptions): Promise<ValidateResult>;
}

/** 不依赖系统 AbortSignal，可在 ArkTS、Worker 与测试环境复用。 */
export class ValidationCancellationToken {
  private cancelledValue: boolean = false;
  private listeners: Array<() => void> = [];
  cancel(): void {
    if (this.cancelledValue) return;
    this.cancelledValue = true;
    const listeners = this.listeners.slice();
    this.listeners = [];
    for (const listener of listeners) {
      try { listener(); } catch (_error) { /* One resource cleanup must not prevent others. */ }
    }
  }
  /** Returns an idempotent unsubscribe function; late subscribers are notified immediately. */
  onCancel(listener: () => void): () => void {
    if (this.cancelledValue) {
      try { listener(); } catch (_error) { /* Same isolation as cancel(). */ }
      return (): void => {};
    }
    this.listeners.push(listener);
    return (): void => {
      const index = this.listeners.indexOf(listener);
      if (index !== -1) this.listeners.splice(index, 1);
    };
  }
  isCancelled(): boolean { return this.cancelledValue; }
}

/** 把 `a.0.b` 路径解析成稳定的结构化片段。 */
export function parseErrorPath(path: string): Array<string> {
  return path === '' ? [] : path.split('.');
}

/** 适合 ArkUI 表单直接消费的 path -> messages 映射。 */
export function flattenErrors(errors: ValidateError[]): Record<string, Array<string>> {
  const result: Record<string, Array<string>> = {};
  for (const error of errors) {
    const key = error.path;
    const messages = result[key] ?? [];
    messages.push(error.message);
    result[key] = messages;
  }
  return result;
}

/** 保留错误码与结构化路径，适合日志、埋点和自定义 UI。 */
export class FormattedError {
  path: Array<string>;
  message: string;
  code?: string;

  constructor(error: ValidateError) {
    this.path = parseErrorPath(error.path);
    this.message = error.message;
    this.code = error.code;
  }
}

export function formatErrors(errors: ValidateError[]): Array<FormattedError> {
  const result: Array<FormattedError> = [];
  for (const error of errors) result.push(new FormattedError(error));
  return result;
}

function cancelledResult(): ValidateResult {
  return { valid: false, errors: [validationError(issue(ErrorCode.CANCELLED))] };
}

/** 根据执行选项裁剪错误，不修改 Schema 返回的原数组。 */
export function applyValidationOptions(result: ValidateResult, options?: ValidationOptions): ValidateResult {
  if (options?.cancellation?.isCancelled() === true) return cancelledResult();
  if (result.valid) return { valid: true, errors: [] };
  let limit = result.errors.length;
  if (options?.abortEarly === true) limit = 1;
  if (options?.maxErrors !== undefined && Number.isFinite(options.maxErrors)) {
    limit = Math.min(limit, Math.max(1, Math.floor(options.maxErrors)));
  }
  return { valid: false, errors: result.errors.slice(0, limit) };
}

/** 带统一选项的同步入口；原 `schema.validate()` 保持完全兼容。 */
export function validateValue<T>(schema: AnySchema<T>, value: Object | null | undefined,
  options?: ValidationOptions): ValidateResult {
  if (options?.cancellation?.isCancelled() === true) return cancelledResult();
  const configurable = schema as ConfigurableSchema<T>;
  const result = configurable.validateWithOptions === undefined ? schema.validate(value, undefined, options)
    : configurable.validateWithOptions(value, options);
  return applyValidationOptions(result, options);
}

/** 带错误上限与协作式取消的异步入口。 */
export async function validateValueAsync<T>(schema: AnySchema<T>, value: Object | null | undefined,
  options?: ValidationOptions, siblings?: Record<string, Object>): Promise<ValidateResult> {
  if (options?.cancellation?.isCancelled() === true) return cancelledResult();
  const timeout = options?.timeoutMs;
  if (timeout !== undefined && (!Number.isFinite(timeout) || timeout <= 0)) {
    throw new RangeError('timeoutMs must be finite and positive');
  }
  const localToken = new ValidationCancellationToken();
  const unlink = options?.cancellation?.onCancel((): void => localToken.cancel());
  const localOptions: ValidationOptions = {
    abortEarly: options?.abortEarly, maxErrors: options?.maxErrors, context: options?.context,
    cancellation: localToken, concurrency: options?.concurrency, timeoutMs: timeout
  };
  let unsubscribe: (() => void) | undefined;
  const cancelled = new Promise<ValidateResult>((resolve): void => {
    unsubscribe = localToken.onCancel((): void => resolve(cancelledResult()));
  });
  let timer: number | undefined;
  let result: ValidateResult;
  try {
    const configurable = schema as ConfigurableSchema<T>;
    const task = siblings !== undefined || configurable.validateAsyncWithOptions === undefined ? schema.validateAsync(value, siblings, localOptions)
      : configurable.validateAsyncWithOptions(value, localOptions);
    const tasks: Array<Promise<ValidateResult>> = [task, cancelled];
    if (timeout !== undefined) tasks.push(new Promise<ValidateResult>((resolve): void => {
        timer = setTimeout((): void => {
          resolve({ valid: false, errors: [validationError(issue(ErrorCode.TIMEOUT))] });
          localToken.cancel();
        }, timeout);
      }));
    result = await Promise.race(tasks);
  } catch (error) {
    localToken.cancel();
    throw error as Error;
  } finally {
    if (timer !== undefined) clearTimeout(timer);
    unsubscribe?.();
    unlink?.();
  }
  return applyValidationOptions(result, options);
}

export function validateBatch<T>(schema: AnySchema<T>, values: Array<Object>,
  options?: ValidationOptions): Array<ValidateResult> {
  const results: Array<ValidateResult> = [];
  for (const value of values) {
    results.push(validateValue(schema, value, options));
    if (options?.cancellation?.isCancelled() === true) break;
  }
  return results;
}

export async function validateBatchAsync<T>(schema: AnySchema<T>, values: Array<Object>,
  options?: ValidationOptions): Promise<Array<ValidateResult>> {
  const concurrency = options?.concurrency ?? 1;
  if (!Number.isInteger(concurrency) || concurrency < 1) {
    throw new RangeError('concurrency must be a positive integer');
  }
  const results: Array<ValidateResult> = [];
  let next = 0;
  let stopped = false;
  const worker = async (): Promise<void> => {
    while (!stopped && next < values.length) {
      const index = next++;
      let result: ValidateResult;
      try { result = await validateValueAsync(schema, values[index], options); }
      catch (error) { stopped = true; throw error as Error; }
      results[index] = result;
      // A timed-out task may still be running: do not schedule more remote work.
      if (options?.cancellation?.isCancelled() === true || result.errors.some(
        (error: ValidateError): boolean => error.code === 'timeout')) stopped = true;
    }
  };
  const workers: Array<Promise<void>> = [];
  for (let i = 0; i < Math.min(concurrency, values.length); i++) workers.push(worker());
  await Promise.all(workers);
  return results;
}
