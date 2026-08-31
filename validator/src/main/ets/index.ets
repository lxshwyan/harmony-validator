import { StringSchema } from './schemas/StringSchema';
import { NumberSchema } from './schemas/NumberSchema';
import { ObjectSchema, SchemaShape } from './schemas/ObjectSchema';
import { ArraySchema } from './schemas/ArraySchema';
import { BooleanSchema } from './schemas/BooleanSchema';
import { EnumSchema } from './schemas/EnumSchema';
import { DateLike, DateSchema } from './schemas/DateSchema';
import { AnySchema } from './core/types';
import { LiteralSchema } from './schemas/LiteralSchema';
import { UnionSchema } from './schemas/UnionSchema';
import { RecordSchema } from './schemas/RecordSchema';
import { TupleSchema } from './schemas/TupleSchema';
import { DiscriminatedUnionSchema } from './schemas/DiscriminatedUnionSchema';
import { PreprocessFunction, PreprocessSchema } from './schemas/PreprocessSchema';
import { TransformSchema } from './schemas/EffectSchemas';
import { ErrorCode, MessageCatalog, ValidatorI18n } from './core/i18n';
import { registerAllStringRules } from './rules/registerAll';

// 兼容主入口：自动注册全部内置字符串规则，维持 v.string().phone() 等历史 API。
registerAllStringRules();

/**
 * 校验器工厂。统一入口，用法：
 *   v.string().required().phone()
 *   v.object({ 'phone': v.string().phone(), 'age': v.number().min(18) })
 *   v.array(v.string().min(2)).min(1)
 */
export class v {
  /** 切换全局默认语言；内置支持 zh-CN / en-US。 */
  static setLocale(locale: string): void {
    ValidatorI18n.setLocale(locale);
  }

  /** 注册或增量覆盖语言包。缺失词条自动回退到 zh-CN。 */
  static addLocale(locale: string, messages: MessageCatalog): void {
    ValidatorI18n.addLocale(locale, messages);
  }

  static getLocale(): string {
    return ValidatorI18n.getLocale();
  }

  static string(): StringSchema {
    return new StringSchema();
  }

  static number(): NumberSchema {
    return new NumberSchema();
  }

  static object<T extends Object = Record<string, Object>>(shape: SchemaShape): ObjectSchema<T> {
    return new ObjectSchema<T>(shape);
  }

  /** 数组校验：逐元素套用 element 校验器。 */
  static array<T extends Object>(element: AnySchema<T>): ArraySchema<T> {
    return new ArraySchema<T>(element);
  }

  /** 布尔校验。 */
  static boolean(): BooleanSchema {
    return new BooleanSchema();
  }

  /** 枚举校验：值必须在 values 集合内（enum 为关键字，故用 enumOf）。 */
  static enumOf<T extends Object>(values: Array<T>, message?: string): EnumSchema<T> {
    return new EnumSchema<T>(values, message);
  }

  /** 日期校验：接受 Date / 时间戳 / 日期字符串。 */
  static date(): DateSchema {
    return new DateSchema();
  }

  /** 精确值校验，使用 === 比较。 */
  static literal<T extends Object>(expected: T, message?: string): LiteralSchema<T> {
    return new LiteralSchema<T>(expected, message);
  }

  /** 任一候选 Schema 通过即通过。异构候选可显式使用 v.union<Object>(...)。 */
  static union<T extends Object = Object>(schemas: Array<AnySchema<T>>, message?: string): UnionSchema<T> {
    return new UnionSchema<T>(schemas, message);
  }

  /** 字符串键对象：每个属性值使用相同 Schema。 */
  static record<T extends Object>(valueSchema: AnySchema<T>, message?: string): RecordSchema<T> {
    return new RecordSchema<T>(valueSchema, message);
  }

  /** 固定长度异构数组。ArkTS 输出类型为 Array<Object>。 */
  static tuple(items: Array<AnySchema>, message?: string): TupleSchema {
    return new TupleSchema(items, message);
  }

  /** 按 discriminator 字段直接选择候选对象 Schema。 */
  static discriminatedUnion<T extends Object = Record<string, Object>>(discriminator: string,
    variants: Record<string, AnySchema<T>>, message?: string): DiscriminatedUnionSchema<T> {
    return new DiscriminatedUnionSchema<T>(discriminator, variants, message);
  }

  /** 在内部 Schema 前执行预处理；回调异常转为 preprocess 错误。 */
  static preprocess<T>(fn: PreprocessFunction, schema: AnySchema<T>, message?: string): PreprocessSchema<T> {
    return new PreprocessSchema<T>(fn, schema, message);
  }

  /** 仅将 string/number/boolean 转成字符串；对象与数组拒绝转换。 */
  static coerceString(message?: string): PreprocessSchema<string> {
    return new PreprocessSchema<string>((value: Object | null | undefined): Object | null | undefined => {
      if (value === null || value === undefined || typeof value === 'string') return value;
      if (typeof value === 'number' || typeof value === 'boolean') return `${value}`;
      throw new Error('unsupported string coercion');
    }, new StringSchema(), message, ErrorCode.COERCE, 'coerce:string');
  }

  /** 将非空数字字符串转成有限数字；不隐式转换布尔值或空字符串。 */
  static coerceNumber(message?: string): PreprocessSchema<number> {
    return new PreprocessSchema<number>((value: Object | null | undefined): Object | null | undefined => {
      if (value === null || value === undefined || typeof value === 'number') return value;
      if (typeof value === 'string' && value.trim() !== '') {
        const parsed = Number(value);
        if (Number.isFinite(parsed)) return parsed;
      }
      throw new Error('unsupported number coercion');
    }, new NumberSchema(), message, ErrorCode.COERCE, 'coerce:number');
  }

  /** 接受 boolean、字符串 true/false 和数字 1/0。 */
  static coerceBoolean(message?: string): PreprocessSchema<boolean> {
    return new PreprocessSchema<boolean>((value: Object | null | undefined): Object | null | undefined => {
      if (value === null || value === undefined || typeof value === 'boolean') return value;
      if (value === 'true' || value === 1) return true;
      if (value === 'false' || value === 0) return false;
      throw new Error('unsupported boolean coercion');
    }, new BooleanSchema(), message, ErrorCode.COERCE, 'coerce:boolean');
  }

  /** 将有效 Date/时间戳/日期字符串解析为新的 Date 实例。 */
  static coerceDate(message?: string): TransformSchema<DateLike, Date> {
    const prepared = new PreprocessSchema<DateLike>((value: Object | null | undefined): Object | null | undefined => {
      if (value === null || value === undefined || value instanceof Date ||
        typeof value === 'number' || typeof value === 'string') return value;
      throw new Error('unsupported date coercion');
    }, new DateSchema(), message, ErrorCode.COERCE, 'coerce:date');
    return prepared.transform<Date>((value: DateLike): Date => new Date(value));
  }
}
