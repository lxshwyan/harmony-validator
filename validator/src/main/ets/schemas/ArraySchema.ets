import {
  AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateError, ValidateResult
} from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { RequiredState } from '../core/required';
import { ErrorCode, issue, RuleIssue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, parseSchema, parseSchemaAsync, TransformSchema } from './EffectSchemas';

/** 单条数组级规则（针对整个数组，如长度）：返回 null 通过，返回字符串为错误提示。 */
type ArrayRule = (value: Array<Object>) => RuleIssue | null;

/**
 * 数组校验器。逐元素套用 element 校验器，错误路径以下标前缀：
 *   v.array(v.string().min(2)).validate(['a'])  // 错误 path = "0"
 *   v.object({ 'items': v.array(v.object({ 'name': v.string().required() })) })
 *   // 嵌套时 path = "items.0.name"
 */
export class ArraySchema<T extends Object = Object> implements ParsableSchema<Array<T>> {
  readonly __schemaType: Array<T> | null = null;
  private element: AnySchema<T>;
  private rules: ArrayRule[] = [];
  private req: RequiredState = new RequiredState();
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  constructor(element: AnySchema<T>) {
    this.element = element;
  }

  meta(value: SchemaMetadata): ArraySchema<T> { this.docs.meta(value); return this; }
  describe(description: string): ArraySchema<T> { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    const result = this.docs.build('array', this.req.requiredForDescription(),
      this.req.conditionallyRequiredForDescription());
    result.items = schemaToDescriptor(this.element);
    return result;
  }

  label(name: string): ArraySchema<T> {
    this.fieldLabel = name;
    this.docs.label(name);
    return this;
  }

  nullable(): NullableSchema<Array<T>> {
    return new NullableSchema<Array<T>>(this);
  }

  default(value: Array<T>): DefaultSchema<Array<T>> {
    return new DefaultSchema<Array<T>>(this, value);
  }

  transform<U>(fn: (value: Array<T>) => U, message?: string): TransformSchema<Array<T>, U> {
    return new TransformSchema<Array<T>, U>(this, fn, message);
  }

  /** 标记为必填。null/undefined 会报错（空数组视为已填，用 min/nonEmpty 约束长度）。 */
  required(message?: string): ArraySchema<T> {
    this.req.markRequired(message);
    return this;
  }

  /** 显式可选。 */
  optional(): ArraySchema<T> {
    this.req.markOptional();
    return this;
  }

  /** 条件必填：当同级字段满足 predicate 时本字段必填（仅 v.object 中生效）。 */
  requiredWhen(field: string, predicate: (other: Object | null | undefined) => boolean,
    message?: string): ArraySchema<T> {
    this.req.addWhen(field, predicate, message);
    return this;
  }

  /** 最小元素个数。 */
  min(len: number, message?: string): ArraySchema<T> {
    this.docs.rule('minItems', len);
    this.rules.push((value: Array<Object>): RuleIssue | null =>
      value.length >= len ? null : issue(ErrorCode.ARRAY_MIN, message, { 'min': `${len}` }));
    return this;
  }

  /** 最大元素个数。 */
  max(len: number, message?: string): ArraySchema<T> {
    this.docs.rule('maxItems', len);
    this.rules.push((value: Array<Object>): RuleIssue | null =>
      value.length <= len ? null : issue(ErrorCode.ARRAY_MAX, message, { 'max': `${len}` }));
    return this;
  }

  /** 不能为空数组。 */
  nonEmpty(message?: string): ArraySchema<T> {
    this.docs.rule('minItems', 1);
    this.rules.push((value: Array<Object>): RuleIssue | null =>
      value.length > 0 ? null : issue(ErrorCode.ARRAY_MIN, message, { 'min': '1' }));
    return this;
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined) {
      const reqError = this.req.error(siblings, this.fieldLabel);
      if (reqError !== null) {
        errors.push(reqError);
      }
      return { valid: errors.length === 0, errors };
    }
    if (!Array.isArray(value)) {
      return { valid: false, errors: [validationError(issue(ErrorCode.TYPE_ARRAY), this.fieldLabel)] };
    }
    const arr = value as Array<Object>;
    // 数组级规则（长度等）
    for (const rule of this.rules) {
      const currentIssue = rule(arr);
      if (currentIssue !== null) {
        errors.push(validationError(currentIssue, this.fieldLabel));
      }
    }
    // 逐元素校验，路径加下标前缀
    for (let i = 0; i < arr.length; i++) {
      const result = this.element.validate(arr[i]);
      if (!result.valid) {
        for (const e of result.errors) {
          const path = e.path === '' ? `${i}` : `${i}.${e.path}`;
          errors.push({ path: path, message: e.message, code: e.code });
        }
      }
    }
    return { valid: errors.length === 0, errors };
  }

  /** 异步逐元素校验：对每个元素调用其 validateAsync，路径规则同 validate。 */
  async validateAsync(value: Object | null | undefined, siblings?: Record<string, Object>): Promise<ValidateResult> {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined) {
      const reqError = this.req.error(siblings, this.fieldLabel);
      if (reqError !== null) {
        errors.push(reqError);
      }
      return { valid: errors.length === 0, errors };
    }
    if (!Array.isArray(value)) {
      return { valid: false, errors: [validationError(issue(ErrorCode.TYPE_ARRAY), this.fieldLabel)] };
    }
    const arr = value as Array<Object>;
    for (const rule of this.rules) {
      const currentIssue = rule(arr);
      if (currentIssue !== null) {
        errors.push(validationError(currentIssue, this.fieldLabel));
      }
    }
    for (let i = 0; i < arr.length; i++) {
      const result = await this.element.validateAsync(arr[i]);
      if (!result.valid) {
        for (const e of result.errors) {
          const path = e.path === '' ? `${i}` : `${i}.${e.path}`;
          errors.push({ path: path, message: e.message, code: e.code });
        }
      }
    }
    return { valid: errors.length === 0, errors };
  }

  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<Array<T>> {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined) {
      const required = this.req.error(siblings, this.fieldLabel);
      return required === null ? { success: true, errors: [] }
        : { success: false, errors: [required] };
    }
    if (!Array.isArray(value)) {
      return {
        success: false,
        errors: [validationError(issue(ErrorCode.TYPE_ARRAY), this.fieldLabel)],
      };
    }
    const source = value as Array<Object>;
    for (const rule of this.rules) {
      const currentIssue = rule(source);
      if (currentIssue !== null) {
        errors.push(validationError(currentIssue, this.fieldLabel));
      }
    }
    const output: Array<T> = [];
    for (let i = 0; i < source.length; i++) {
      const parsed = parseSchema<T>(this.element, source[i]);
      if (!parsed.success) {
        for (const error of parsed.errors) {
          const path = error.path === '' ? `${i}` : `${i}.${error.path}`;
          errors.push({ path, message: error.message, code: error.code });
        }
      } else {
        output.push(parsed.value as T);
      }
    }
    if (errors.length > 0) {
      return { success: false, errors };
    }
    return { success: true, value: output, errors: [] };
  }

  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<Array<T>>> {
    const errors: ValidateError[] = [];
    if (value === null || value === undefined) {
      const required = this.req.error(siblings, this.fieldLabel);
      return required === null ? { success: true, errors: [] }
        : { success: false, errors: [required] };
    }
    if (!Array.isArray(value)) {
      return {
        success: false,
        errors: [validationError(issue(ErrorCode.TYPE_ARRAY), this.fieldLabel)],
      };
    }
    const source = value as Array<Object>;
    for (const rule of this.rules) {
      const currentIssue = rule(source);
      if (currentIssue !== null) {
        errors.push(validationError(currentIssue, this.fieldLabel));
      }
    }
    const output: Array<T> = [];
    for (let i = 0; i < source.length; i++) {
      const parsed = await parseSchemaAsync<T>(this.element, source[i]);
      if (!parsed.success) {
        for (const error of parsed.errors) {
          const path = error.path === '' ? `${i}` : `${i}.${error.path}`;
          errors.push({ path, message: error.message, code: error.code });
        }
      } else {
        output.push(parsed.value as T);
      }
    }
    if (errors.length > 0) {
      return { success: false, errors };
    }
    return { success: true, value: output, errors: [] };
  }
}
