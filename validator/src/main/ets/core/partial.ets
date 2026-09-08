import { AnySchema } from './types';

/** Optional extension point; third-party schemas without this capability stay unchanged. */
export interface DeepPartialSchema<T> extends AnySchema<T> {
  deepPartial(context?: DeepPartialContext): AnySchema<T>;
}

/** One conversion graph. Do not reuse across independent update models. */
export class DeepPartialContext {
  private copies: Map<Object, Object> = new Map<Object, Object>();

  remember<T>(source: AnySchema<T>, target: AnySchema<T>): void { this.copies.set(source, target); }

  convert<T>(schema: AnySchema<T>): AnySchema<T> {
    const existing = this.copies.get(schema);
    if (existing !== undefined) return existing as AnySchema<T>;
    const capable = schema as DeepPartialSchema<T>;
    const result = capable.deepPartial === undefined ? schema : capable.deepPartial(this);
    this.remember(schema, result);
    return result;
  }
}

export function deepPartialSchema<T>(schema: AnySchema<T>, context?: DeepPartialContext): AnySchema<T> {
  return (context ?? new DeepPartialContext()).convert(schema);
}
