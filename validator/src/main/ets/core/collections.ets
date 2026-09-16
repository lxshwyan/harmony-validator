import { AnySchema, ParsableSchema, ValidateError, ValidateResult } from './types';
import { CheckedSchema } from './CheckedSchema';
import { issue, validationError } from './i18n';

export type UniqueKey = string | number | boolean | null | undefined;
export interface UniqueByOptions {
  /** Optional suffix for indexed errors, e.g. sku -> 2.sku. */
  path?: string;
  message?: string;
}

/** Check parsed array keys (including transforms). Missing keys compare equal. */
export function uniqueBy<T>(schema: AnySchema<Array<T>>, selector: (value: T) => UniqueKey,
  options?: UniqueByOptions): ParsableSchema<Array<T>> {
  const path = options?.path ?? '';
  const message = options?.message;
  return new CheckedSchema<Array<T>>(schema, (value: Object | null | undefined): ValidateResult => {
    const errors: ValidateError[] = [];
    if (!Array.isArray(value)) return { valid: true, errors };
    const keys: Map<UniqueKey, number> = new Map<UniqueKey, number>();
    const items = value as Array<T>;
    for (let i = 0; i < items.length; i++) {
      const key = selector(items[i]);
      if (key !== null && key !== undefined && typeof key !== 'string' && typeof key !== 'number' && typeof key !== 'boolean') {
        throw new TypeError('uniqueBy selector must return a primitive key');
      }
      if (keys.has(key)) {
        const error = validationError(issue('unique_by', message));
        error.path = path === '' ? `${i}` : `${i}.${path}`;
        errors.push(error);
      } else keys.set(key, i);
    }
    return { valid: errors.length === 0, errors };
  }, 'uniqueBy', true);
}
