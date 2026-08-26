import {
  AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateError, ValidateResult
} from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, parseSchema, parseSchemaAsync, TransformSchema } from './EffectSchemas';

/** 对象形状：字段名 -> 对应字段的校验器。 */
export type SchemaShape = Record<string, AnySchema>;

/** 跨字段规则：拿到整个对象判断，返回 true 通过。 */
interface RefineRule {
  fn: (obj: Object) => boolean;
  message: string;
  path: string;
}

/** 对象校验器：按 shape 逐字段校验，并把错误路径拼成 "字段名" 或 "父.子"。 */
export class ObjectSchema<T extends Object = Record<string, Object>> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private shape: SchemaShape;
  private refines: RefineRule[] = [];
  private isOptional: boolean = false;
  private emptyMsg?: string;
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  constructor(shape: SchemaShape) {
    this.shape = shape;
  }

  meta(value: SchemaMetadata): ObjectSchema<T> { this.docs.meta(value); return this; }
  describe(description: string): ObjectSchema<T> { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    const result = this.docs.build('object', !this.isOptional, false);
    const properties: Record<string, SchemaDescriptor> = {};
    for (const key of Object.keys(this.shape)) {
      properties[key] = schemaToDescriptor(this.shape[key]);
    }
    result.properties = properties;
    return result;
  }

  label(name: string): ObjectSchema<T> {
    this.fieldLabel = name;
    this.docs.label(name);
    return this;
  }

  nullable(): NullableSchema<T> {
    return new NullableSchema<T>(this);
  }

  default(value: T): DefaultSchema<T> {
    return new DefaultSchema<T>(this, value);
  }

  transform<U>(fn: (value: T) => U, message?: string): TransformSchema<T, U> {
    return new TransformSchema<T, U>(this, fn, message);
  }

  /** 显式可选：值为 null/undefined 时直接通过（用于可空的嵌套对象字段）。 */
  optional(): ObjectSchema<T> {
    this.isOptional = true;
    return this;
  }

  /**
   * 跨字段校验。`fn` 拿到整个对象，返回 false 时报错。
   * 例：确认密码 —— `.refine(o => o['pwd'] === o['confirm'], '两次密码不一致', 'confirm')`
   * `fn` 内部应自行判空（字段可能缺失）；即便 `fn` 抛异常也会被捕获并按「未通过」处理，不会让整个校验崩溃。
   * @param path 错误归属的字段路径（默认空串，表示对象级错误）。
   */
  refine(fn: (obj: T) => boolean, message: string, path?: string): ObjectSchema<T> {
    this.docs.rule('refine', path, path ?? '', false, false);
    this.refines.push({
      fn: (obj: Object): boolean => fn(obj as T),
      message,
      path: path ?? '',
    });
    return this;
  }

  private runRefines(data: Object, errors: ValidateError[]): void {
    for (const r of this.refines) {
      let passed = false;
      try {
        passed = r.fn(data);
      } catch (e) {
        // refine 体内解引用缺失字段等抛异常时，视为未通过而非让校验崩溃
        passed = false;
      }
      if (!passed) {
        errors.push(validationError(issue(ErrorCode.REFINE, r.message), this.fieldLabel, r.path));
      }
    }
  }

  /** 空对象（null/undefined）的处理：可选则通过，否则报错。 */
  private emptyResult(): ValidateResult {
    if (this.isOptional) {
      return { valid: true, errors: [] };
    }
    return { valid: false, errors: [validationError(issue(ErrorCode.OBJECT_REQUIRED,
      this.emptyMsg), this.fieldLabel)] };
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    if (value === null || value === undefined) {
      return this.emptyResult();
    }
    if (typeof value !== 'object' || Array.isArray(value) || value instanceof Date) {
      return { valid: false, errors: [validationError(issue(ErrorCode.TYPE_OBJECT), this.fieldLabel)] };
    }
    const data = value as Record<string, Object>;
    const errors: ValidateError[] = [];
    const keys = Object.keys(this.shape);
    for (const key of keys) {
      const fieldSchema = this.shape[key];
      // 把当前对象作为 siblings 传下去，供字段的 requiredWhen 读取兄弟字段
      const result = fieldSchema.validate(data[key], data);
      if (!result.valid) {
        for (const e of result.errors) {
          const path = e.path === '' ? key : `${key}.${e.path}`;
          errors.push({ path: path, message: e.message, code: e.code });
        }
      }
    }
    this.runRefines(data, errors);
    return { valid: errors.length === 0, errors };
  }

  /** 异步逐字段校验：对每个字段调用其 validateAsync，路径拼接规则同 validate。 */
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    if (value === null || value === undefined) {
      return this.emptyResult();
    }
    if (typeof value !== 'object' || Array.isArray(value) || value instanceof Date) {
      return { valid: false, errors: [validationError(issue(ErrorCode.TYPE_OBJECT), this.fieldLabel)] };
    }
    const data = value as Record<string, Object>;
    const errors: ValidateError[] = [];
    const keys = Object.keys(this.shape);
    const tasks: Array<Promise<ValidateResult>> = [];
    for (const key of keys) {
      tasks.push(this.shape[key].validateAsync(data[key], data));
    }
    const results = await Promise.all(tasks);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const result = results[i];
      if (!result.valid) {
        for (const e of result.errors) {
          const path = e.path === '' ? key : `${key}.${e.path}`;
          errors.push({ path: path, message: e.message, code: e.code });
        }
      }
    }
    this.runRefines(data, errors);
    return { valid: errors.length === 0, errors };
  }

  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T> {
    if (value === null || value === undefined) {
      const empty = this.emptyResult();
      return empty.valid ? { success: true, errors: [] } : { success: false, errors: empty.errors };
    }
    if (typeof value !== 'object' || Array.isArray(value) || value instanceof Date) {
      return {
        success: false,
        errors: [validationError(issue(ErrorCode.TYPE_OBJECT), this.fieldLabel)],
      };
    }
    const data = value as Record<string, Object>;
    const output: Record<string, Object> = {};
    const errors: ValidateError[] = [];
    for (const key of Object.keys(data)) {
      output[key] = data[key];
    }
    for (const key of Object.keys(this.shape)) {
      const parsed = parseSchema(this.shape[key], data[key], data);
      if (!parsed.success) {
        for (const error of parsed.errors) {
          const path = error.path === '' ? key : `${key}.${error.path}`;
          errors.push({ path, message: error.message, code: error.code });
        }
      } else if (parsed.value !== undefined) {
        output[key] = parsed.value as Object;
      }
    }
    this.runRefines(data, errors);
    if (errors.length > 0) {
      return { success: false, errors };
    }
    const bridge: Object = output;
    return { success: true, value: bridge as T, errors: [] };
  }

  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<T>> {
    if (value === null || value === undefined) {
      const empty = this.emptyResult();
      return empty.valid ? { success: true, errors: [] } : { success: false, errors: empty.errors };
    }
    if (typeof value !== 'object' || Array.isArray(value) || value instanceof Date) {
      return {
        success: false,
        errors: [validationError(issue(ErrorCode.TYPE_OBJECT), this.fieldLabel)],
      };
    }
    const data = value as Record<string, Object>;
    const output: Record<string, Object> = {};
    const errors: ValidateError[] = [];
    for (const key of Object.keys(data)) {
      output[key] = data[key];
    }
    const keys = Object.keys(this.shape);
    const tasks: Array<Promise<ParseResult<Object>>> = [];
    for (const key of keys) {
      tasks.push(parseSchemaAsync<Object>(this.shape[key], data[key], data));
    }
    const results = await Promise.all(tasks);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const parsed = results[i];
      if (!parsed.success) {
        for (const error of parsed.errors) {
          const path = error.path === '' ? key : `${key}.${error.path}`;
          errors.push({ path, message: error.message, code: error.code });
        }
      } else if (parsed.value !== undefined) {
        output[key] = parsed.value as Object;
      }
    }
    this.runRefines(data, errors);
    if (errors.length > 0) {
      return { success: false, errors };
    }
    const bridge: Object = output;
    return { success: true, value: bridge as T, errors: [] };
  }
}
