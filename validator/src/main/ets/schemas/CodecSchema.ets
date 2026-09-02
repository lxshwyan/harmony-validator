import {
  AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata, ValidateResult
} from '../core/types';
import { SchemaDocs, schemaToDescriptor } from '../core/schema';
import { ErrorCode, issue, validationError } from '../core/i18n';
import { DefaultSchema, NullableSchema, parseSchema, parseSchemaAsync, TransformSchema } from './EffectSchemas';

export type CodecDecoder<I extends Object, O extends Object> = (input: I) => O;
export type CodecEncoder<I extends Object, O extends Object> = (output: O) => I;

/** 可逆数据管线：parse/decode 面向输入，encode 面向输出。 */
export class CodecSchema<I extends Object, O extends Object> implements ParsableSchema<O> {
  readonly __schemaType: O | null = null;
  private inputSchema: AnySchema<I>;
  private outputSchema: AnySchema<O>;
  private decoder: CodecDecoder<I, O>;
  private encoder: CodecEncoder<I, O>;
  private decodeMessage?: string;
  private encodeMessage?: string;
  private docs: SchemaDocs = new SchemaDocs();

  constructor(inputSchema: AnySchema<I>, outputSchema: AnySchema<O>, decoder: CodecDecoder<I, O>,
    encoder: CodecEncoder<I, O>, decodeMessage?: string, encodeMessage?: string) {
    this.inputSchema = inputSchema;
    this.outputSchema = outputSchema;
    this.decoder = decoder;
    this.encoder = encoder;
    this.decodeMessage = decodeMessage;
    this.encodeMessage = encodeMessage;
  }

  meta(value: SchemaMetadata): CodecSchema<I, O> { this.docs.meta(value); return this; }
  describe(value: string): CodecSchema<I, O> { this.docs.describe(value); return this; }
  label(value: string): CodecSchema<I, O> { this.docs.label(value); return this; }
  nullable(): NullableSchema<O> { return new NullableSchema<O>(this); }
  default(value: O): DefaultSchema<O> { return new DefaultSchema<O>(this, value); }
  transform<U>(fn: (value: O) => U, message?: string): TransformSchema<O, U> {
    return new TransformSchema<O, U>(this, fn, message);
  }
  describeSchema(): SchemaDescriptor {
    const result = this.docs.build('codec');
    result.options.push(schemaToDescriptor(this.inputSchema));
    result.options.push(schemaToDescriptor(this.outputSchema));
    result.unrepresentable.push('runtime-codec');
    return result;
  }

  private decode(input: ParseResult<I>): ParseResult<O> {
    if (!input.success || input.value === undefined) return { success: false, errors: input.errors };
    try {
      return parseSchema<O>(this.outputSchema, this.decoder(input.value));
    } catch (_error) {
      return { success: false, errors: [validationError(issue(ErrorCode.CODEC_DECODE, this.decodeMessage))] };
    }
  }

  validate(value: Object | null | undefined): ValidateResult {
    const result = this.parse(value);
    return { valid: result.success, errors: result.errors };
  }
  async validateAsync(value: Object | null | undefined): Promise<ValidateResult> {
    const result = await this.parseAsync(value);
    return { valid: result.success, errors: result.errors };
  }
  parse(value: Object | null | undefined): ParseResult<O> {
    return this.decode(parseSchema<I>(this.inputSchema, value));
  }
  async parseAsync(value: Object | null | undefined): Promise<ParseResult<O>> {
    const input = await parseSchemaAsync<I>(this.inputSchema, value);
    if (!input.success || input.value === undefined) return { success: false, errors: input.errors };
    try {
      return parseSchemaAsync<O>(this.outputSchema, this.decoder(input.value));
    } catch (_error) {
      return { success: false, errors: [validationError(issue(ErrorCode.CODEC_DECODE, this.decodeMessage))] };
    }
  }

  encode(value: Object | null | undefined): ParseResult<I> {
    const output = parseSchema<O>(this.outputSchema, value);
    if (!output.success || output.value === undefined) return { success: false, errors: output.errors };
    try {
      return parseSchema<I>(this.inputSchema, this.encoder(output.value));
    } catch (_error) {
      return { success: false, errors: [validationError(issue(ErrorCode.CODEC_ENCODE, this.encodeMessage))] };
    }
  }

  async encodeAsync(value: Object | null | undefined): Promise<ParseResult<I>> {
    const output = await parseSchemaAsync<O>(this.outputSchema, value);
    if (!output.success || output.value === undefined) return { success: false, errors: output.errors };
    try {
      return parseSchemaAsync<I>(this.inputSchema, this.encoder(output.value));
    } catch (_error) {
      return { success: false, errors: [validationError(issue(ErrorCode.CODEC_ENCODE, this.encodeMessage))] };
    }
  }
}
