import { AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateResult } from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, parseSchema, parseSchemaAsync, TransformSchema } from './EffectSchemas';

/** 多候选 Schema：任一候选通过即通过，全部失败时只返回一个稳定 union 错误。 */
export class UnionSchema<T extends Object = Object> implements ParsableSchema<T> {
  readonly __schemaType: T | null = null;
  private schemas: Array<AnySchema<T>>;
  private customMessage?: string;
  private fieldLabel: string = '';
  private docs: SchemaDocs = new SchemaDocs();

  constructor(schemas: Array<AnySchema<T>>, message?: string) {
    this.schemas = schemas;
    this.customMessage = message;
  }

  meta(value: SchemaMetadata): UnionSchema<T> { this.docs.meta(value); return this; }
  describe(description: string): UnionSchema<T> { this.docs.describe(description); return this; }
  describeSchema(): SchemaDescriptor {
    const result = this.docs.build('union');
    let allRequired = this.schemas.length > 0;
    let anyConditional = false;
    for (const schema of this.schemas) {
      const option = schemaToDescriptor(schema);
      result.options.push(option);
      allRequired = allRequired && option.required;
      anyConditional = anyConditional || option.conditionallyRequired;
    }
    result.required = allRequired;
    result.conditionallyRequired = !allRequired && anyConditional;
    return result;
  }

  label(name: string): UnionSchema<T> {
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

  private failure(): ValidateResult {
    return {
      valid: false,
      errors: [validationError(issue(ErrorCode.UNION, this.customMessage), this.fieldLabel)],
    };
  }

  validate(value: Object | null | undefined, siblings?: Record<string, Object>): ValidateResult {
    for (const schema of this.schemas) {
      const result = schema.validate(value, siblings);
      if (result.valid) {
        return result;
      }
    }
    return this.failure();
  }

  async validateAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ValidateResult> {
    for (const schema of this.schemas) {
      const result = await schema.validateAsync(value, siblings);
      if (result.valid) {
        return result;
      }
    }
    return this.failure();
  }

  parse(value: Object | null | undefined, siblings?: Record<string, Object>): ParseResult<T> {
    for (const schema of this.schemas) {
      const result = parseSchema<T>(schema, value, siblings);
      if (result.success) {
        return result;
      }
    }
    return { success: false, errors: this.failure().errors };
  }

  async parseAsync(value: Object | null | undefined,
    siblings?: Record<string, Object>): Promise<ParseResult<T>> {
    for (const schema of this.schemas) {
      const result = await parseSchemaAsync<T>(schema, value, siblings);
      if (result.success) {
        return result;
      }
    }
    return { success: false, errors: this.failure().errors };
  }
}
