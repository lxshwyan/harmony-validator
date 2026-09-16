import { AnySchema, ParsableSchema, ValidateResult } from './types';
import { CheckedSchema } from './CheckedSchema';
import { issue, validationError } from './i18n';

export interface InputLimits {
  /** Root depth is zero. Default 64. */
  maxDepth?: number;
  /** Counts every visited value, including repeated references. Default 10000. */
  maxNodes?: number;
}

class InputFrame {
  value: Object | null | undefined;
  path: string;
  depth: number;
  keys: string[] = [];
  index: number = -1;
  constructor(value: Object | null | undefined, path: string, depth: number) {
    this.value = value; this.path = path; this.depth = depth;
  }
}

function failure(code: string, path: string): ValidateResult {
  const error = validationError(issue(code));
  error.path = path;
  return { valid: false, errors: [error] };
}

/** Iterative own-enumerable input traversal. Shared children are allowed; ancestor cycles are rejected. */
export function inspectInput(value: Object | null | undefined, limits?: InputLimits): ValidateResult {
  const maxDepth = limits?.maxDepth ?? 64;
  const maxNodes = limits?.maxNodes ?? 10000;
  if (!Number.isInteger(maxDepth) || maxDepth < 0 || !Number.isInteger(maxNodes) || maxNodes < 1) {
    throw new RangeError('maxDepth must be a non-negative integer; maxNodes must be a positive integer');
  }
  const stack: InputFrame[] = [new InputFrame(value, '', 0)];
  const active: Set<Object> = new Set<Object>();
  let nodes = 0;
  while (stack.length > 0) {
    const frame = stack[stack.length - 1];
    if (frame.index === -1) {
      if (++nodes > maxNodes) return failure('input_nodes', frame.path);
      if (frame.depth > maxDepth) return failure('input_depth', frame.path);
      if (frame.value === null || typeof frame.value !== 'object') { stack.pop(); continue; }
      if (active.has(frame.value)) return failure('input_cycle', frame.path);
      active.add(frame.value);
      frame.keys = Object.keys(frame.value);
      frame.index = 0;
    }
    if (frame.index >= frame.keys.length) {
      active.delete(frame.value as Object); stack.pop(); continue;
    }
    const key = frame.keys[frame.index++];
    const child = (frame.value as Record<string, Object>)[key];
    stack.push(new InputFrame(child, frame.path === '' ? key : `${frame.path}.${key}`, frame.depth + 1));
  }
  return { valid: true, errors: [] };
}

/** Protect raw input before running any schema; does not sandbox callbacks or transformed output. */
export function guarded<T>(schema: AnySchema<T>, limits?: InputLimits): ParsableSchema<T> {
  const snapshot: InputLimits = { maxDepth: limits?.maxDepth ?? 64, maxNodes: limits?.maxNodes ?? 10000 };
  inspectInput(undefined, snapshot);
  return new CheckedSchema<T>(schema, (value: Object | null | undefined): ValidateResult => inspectInput(value, snapshot), 'guarded');
}
