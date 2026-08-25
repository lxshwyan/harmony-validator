import { StringSchema } from './schemas/StringSchema';
import { NumberSchema } from './schemas/NumberSchema';
import { ObjectSchema, SchemaShape } from './schemas/ObjectSchema';
import { ArraySchema } from './schemas/ArraySchema';
import { BooleanSchema } from './schemas/BooleanSchema';
import { EnumSchema } from './schemas/EnumSchema';
import { DateSchema } from './schemas/DateSchema';
import { AnySchema } from './core/types';
import { LiteralSchema } from './schemas/LiteralSchema';
import { UnionSchema } from './schemas/UnionSchema';
import { MessageCatalog, ValidatorI18n } from './core/i18n';

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
}
