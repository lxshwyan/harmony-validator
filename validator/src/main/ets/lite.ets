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
 * 不自动注册中国规则的轻量工厂。
 * 配合 `liteV.string().use(rule)` 与 `@hmkit/validator/rules/*` 按需使用。
 */
export class liteV {
  static setLocale(locale: string): void {
    ValidatorI18n.setLocale(locale);
  }

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

  static array<T extends Object>(element: AnySchema<T>): ArraySchema<T> {
    return new ArraySchema<T>(element);
  }

  static boolean(): BooleanSchema {
    return new BooleanSchema();
  }

  static enumOf<T extends Object>(values: Array<T>, message?: string): EnumSchema<T> {
    return new EnumSchema<T>(values, message);
  }

  static date(): DateSchema {
    return new DateSchema();
  }

  static literal<T extends Object>(expected: T, message?: string): LiteralSchema<T> {
    return new LiteralSchema<T>(expected, message);
  }

  static union<T extends Object = Object>(schemas: Array<AnySchema<T>>, message?: string): UnionSchema<T> {
    return new UnionSchema<T>(schemas, message);
  }
}
