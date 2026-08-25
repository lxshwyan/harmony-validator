import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { AnySchema, ParseResult, ValidateResult } from '../main/ets/core/types';
import { ErrorCode, ValidatorI18n } from '../main/ets/core/i18n';
import { TransformSchema } from '../main/ets/schemas/EffectSchemas';

class LegacyStringSchema implements AnySchema<string> {
  readonly __schemaType: string | null = null;

  validate(value: Object | null | undefined): ValidateResult {
    return typeof value === 'string' ? { valid: true, errors: [] }
      : { valid: false, errors: [{ path: '', message: 'legacy' }] };
  }

  async validateAsync(value: Object | null | undefined): Promise<ValidateResult> {
    return this.validate(value);
  }
}

export default function v050Test(): void {
  describe('0.5 error codes and locales', (): void => {
    it('adds stable codes and explicit labels', 0, (): void => {
      v.setLocale('zh-CN');
      const result = v.string().label('姓名').required().validate('');
      expect(result.errors[0].code).assertEqual(ErrorCode.REQUIRED);
      expect(result.errors[0].message).assertEqual('姓名：该字段为必填项');
    });

    it('switches existing schemas at validation time', 0, (): void => {
      const schema = v.string().label('Email').email();
      v.setLocale('en-US');
      expect(schema.validate('bad').errors[0].message).assertEqual('Email: Invalid email address');
      expect(v.getLocale()).assertEqual('en-US');
      v.setLocale('zh-CN');
      expect(schema.validate('bad').errors[0].message).assertEqual('Email：请输入正确的邮箱地址');
    });

    it('registers and incrementally overrides a custom locale', 0, (): void => {
      v.addLocale('test', { 'required': 'REQ', 'string_min': 'MIN {min}' });
      v.addLocale('test', { 'required': 'REQUIRED' });
      v.setLocale('test');
      expect(v.string().required().validate('').errors[0].message).assertEqual('REQUIRED');
      expect(v.string().min(3).validate('a').errors[0].message).assertEqual('MIN 3');
      // 自定义语言缺词条时回退中文。
      expect(v.number().positive().validate(0).errors[0].message).assertEqual('必须为正数');
      v.setLocale('zh-CN');
    });

    it('keeps custom messages ahead of locale messages', 0, (): void => {
      v.setLocale('en-US');
      expect(v.string().label('Name').min(3, '{label} too short').validate('a').errors[0].message)
        .assertEqual('Name too short');
      expect(v.number().label('Age').min(18, 'too young').validate(10).errors[0].message)
        .assertEqual('Age: too young');
      v.setLocale('zh-CN');
    });

    it('propagates nested error codes', 0, (): void => {
      const objectResult = v.object({ 'items': v.array(v.string().email()) })
        .validate({ 'items': ['bad'] } as Record<string, Object>);
      expect(objectResult.errors[0].path).assertEqual('items.0');
      expect(objectResult.errors[0].code).assertEqual(ErrorCode.EMAIL);
    });

    it('codes built-in type and range failures', 0, (): void => {
      expect(v.string().validate(1).errors[0].code).assertEqual(ErrorCode.TYPE_STRING);
      expect(v.number().validate(NaN).errors[0].code).assertEqual(ErrorCode.INVALID_NUMBER);
      expect(v.boolean().validate('true').errors[0].code).assertEqual(ErrorCode.TYPE_BOOLEAN);
      expect(v.array(v.string()).validate('x').errors[0].code).assertEqual(ErrorCode.TYPE_ARRAY);
      expect(v.object({}).validate([]).errors[0].code).assertEqual(ErrorCode.TYPE_OBJECT);
      expect(v.date().validate('bad').errors[0].code).assertEqual(ErrorCode.INVALID_DATE);
    });
  });

  describe('0.5 literal and union schemas', (): void => {
    it('validates literal values with code and label', 0, (): void => {
      const schema = v.literal('ready').label('状态');
      expect(schema.validate('ready').valid).assertTrue();
      const result = schema.validate('done');
      expect(result.errors[0].code).assertEqual(ErrorCode.LITERAL);
      expect(result.errors[0].message).assertEqual('状态：取值必须为 ready');
    });

    it('supports literal required optional and custom messages', 0, (): void => {
      expect(v.literal('yes').required('请选择').validate(undefined).errors[0].message).assertEqual('请选择');
      expect(v.literal('yes').required().optional().validate(undefined).valid).assertTrue();
      expect(v.literal('yes', '只能选 yes').validate('no').errors[0].message).assertEqual('只能选 yes');
    });

    it('parses literal values synchronously and asynchronously', 0, async (): Promise<void> => {
      const schema = v.literal('ok');
      expect(schema.parse('ok').value).assertEqual('ok');
      expect((await schema.parseAsync('bad')).success).assertFalse();
      expect((await schema.validateAsync('ok')).valid).assertTrue();
    });

    it('accepts any matching union member', 0, (): void => {
      const schema = v.union<string>([v.literal('draft'), v.literal('done')]);
      expect(schema.validate('draft').valid).assertTrue();
      expect(schema.validate('done').valid).assertTrue();
      const result = schema.validate('other');
      expect(result.errors.length).assertEqual(1);
      expect(result.errors[0].code).assertEqual(ErrorCode.UNION);
    });

    it('supports union labels custom messages and empty candidates', 0, (): void => {
      expect(v.union<string>([v.literal('a')], 'unsupported').label('Mode').validate('b').errors[0].message)
        .assertEqual('Mode：unsupported');
      expect(v.union<Object>([]).validate('anything').valid).assertFalse();
    });

    it('parses the first successful union member', 0, async (): Promise<void> => {
      const schema = v.union<string>([
        v.literal('a'),
        v.string().min(2),
      ]);
      expect(schema.parse('ab').value).assertEqual('ab');
      expect((await schema.parseAsync('a')).value).assertEqual('a');
      expect((await schema.validateAsync('x')).valid).assertFalse();
    });
  });

  describe('0.5 nullable default and transform', (): void => {
    it('nullable accepts only explicit null in addition to the inner schema', 0, async (): Promise<void> => {
      const schema = v.string().required().nullable();
      expect(schema.validate(null).valid).assertTrue();
      expect(schema.validate(undefined).valid).assertFalse();
      expect(schema.parse(null).value).assertNull();
      expect((await schema.parseAsync(null)).success).assertTrue();
      expect((await schema.validateAsync(undefined)).valid).assertFalse();
    });

    it('default replaces undefined but not null', 0, async (): Promise<void> => {
      const schema = v.string().required().default('guest');
      expect(schema.validate(undefined).valid).assertTrue();
      expect(schema.parse(undefined).value).assertEqual('guest');
      expect(schema.validate(null).valid).assertFalse();
      expect((await schema.parseAsync(undefined)).value).assertEqual('guest');
      expect((await schema.validateAsync(undefined)).valid).assertTrue();
    });

    it('transform returns typed output from parse', 0, async (): Promise<void> => {
      const schema = v.string().required().transform<number>((value: string): number => value.length);
      const parsed: ParseResult<number> = schema.parse('abcd');
      expect(parsed.success).assertTrue();
      expect(parsed.value).assertEqual(4);
      expect((await schema.parseAsync('xy')).value).assertEqual(2);
      expect(schema.validate('abc').valid).assertTrue();
      expect((await schema.validateAsync('abc')).valid).assertTrue();
    });

    it('transform converts exceptions to a stable error', 0, (): void => {
      const schema = v.string().transform<number>((_value: string): number => {
        throw new Error('failed');
      }, '无法转换').label('编号');
      const result = schema.parse('x');
      expect(result.success).assertFalse();
      expect(result.errors[0].code).assertEqual(ErrorCode.TRANSFORM);
      expect(result.errors[0].message).assertEqual('编号：无法转换');
    });

    it('does not transform an absent optional value', 0, (): void => {
      const result = v.string().transform<number>((value: string): number => value.length).parse(undefined);
      expect(result.success).assertTrue();
      expect(result.value).assertUndefined();
    });

    it('supports effect chaining', 0, (): void => {
      const schema = v.string()
        .nullable()
        .default('fallback')
        .transform<number>((value: string | null): number => value === null ? 0 : value.length)
        .transform<string>((value: number): string => `${value}`)
        .nullable()
        .default('1')
        .label('结果');
      // 最外层 default 处理最终缺失值，因此不会再执行内层转换链。
      expect(schema.parse(undefined).value).assertEqual('1');
      expect(schema.parse(null).value).assertNull();
    });

    it('supports labels on nullable and default wrappers', 0, (): void => {
      expect(v.string().required().nullable().label('昵称').validate(undefined).errors[0].message)
        .assertEqual('昵称：该字段为必填项');
      expect(v.number().required().default(1).label('数量').validate('bad').errors[0].message)
        .assertEqual('数量：类型错误，期望数字');
    });

    it('parses transformed array elements', 0, async (): Promise<void> => {
      const schema = v.array(v.string().transform<number>((value: string): number => value.length));
      expect(schema.parse(['a', 'abcd']).value?.[1]).assertEqual(4);
      expect((await schema.parseAsync(['abc'])).value?.[0]).assertEqual(3);
    });

    it('parses object defaults and child transforms', 0, async (): Promise<void> => {
      const schema = v.object({
        'name': v.string().default('guest'),
        'age': v.string().transform<number>((value: string): number => parseInt(value, 10)),
      });
      const parsed = schema.parse({ 'age': '18' } as Record<string, Object>);
      const value = parsed.value as Record<string, Object>;
      expect(value['name']).assertEqual('guest');
      expect(value['age']).assertEqual(18);
      expect((await schema.parseAsync({ 'age': '20' } as Record<string, Object>)).success).assertTrue();
    });

    it('falls back for legacy third-party schemas without parse', 0, async (): Promise<void> => {
      const schema = new TransformSchema<string, number>(new LegacyStringSchema(),
        (value: string): number => value.length);
      expect(schema.parse('abc').value).assertEqual(3);
      expect((await schema.parseAsync('abcd')).value).assertEqual(4);
      expect(schema.validate(1).valid).assertFalse();
    });
  });

  describe('0.5 parsable built-in schemas', (): void => {
    it('creates effects from every built-in schema', 0, (): void => {
      expect(v.boolean().label('同意').nullable().parse(null).success).assertTrue();
      expect(v.boolean().default(true).parse(undefined).value).assertTrue();
      expect(v.boolean().transform<string>((value: boolean): string => `${value}`).parse(false).value)
        .assertEqual('false');

      expect(v.enumOf(['a']).label('枚举').nullable().parse(null).success).assertTrue();
      expect(v.enumOf(['a']).default('a').parse(undefined).value).assertEqual('a');
      expect(v.enumOf(['a']).transform<number>((value: string): number => value.length).parse('a').value)
        .assertEqual(1);

      expect(v.date().label('日期').nullable().parse(null).success).assertTrue();
      expect(v.date().default('2024-01-01').parse(undefined).value).assertEqual('2024-01-01');
      expect(v.date().transform<string>((value): string => `${value}`).parse('2024-01-01').success).assertTrue();

      expect(v.array(v.string()).label('列表').nullable().parse(null).success).assertTrue();
      expect(v.array(v.string()).default(['a']).parse(undefined).value?.length).assertEqual(1);
      expect(v.array(v.string()).transform<number>((value: Array<string>): number => value.length)
        .parse(['a', 'b']).value).assertEqual(2);

      expect(v.object({}).label('对象').nullable().parse(null).success).assertTrue();
      expect(v.object({}).default({ 'ok': true } as Record<string, Object>).parse(undefined).success).assertTrue();
      expect(v.object({}).transform<number>((value: Record<string, Object>): number => Object.keys(value).length)
        .parse({} as Record<string, Object>).value).assertEqual(0);
    });

    it('creates effects from literal and union schemas', 0, (): void => {
      expect(v.literal('a').nullable().parse(null).success).assertTrue();
      expect(v.literal('a').default('a').parse(undefined).value).assertEqual('a');
      expect(v.literal('a').transform<number>((value: string): number => value.length).parse('a').value)
        .assertEqual(1);

      const union = v.union<string>([v.literal('a')]);
      expect(union.nullable().parse(null).success).assertTrue();
      expect(union.default('a').parse(undefined).value).assertEqual('a');
      expect(union.transform<number>((value: string): number => value.length).parse('a').value).assertEqual(1);
    });

    it('covers wrapper variants and locale-aware wrapper labels', 0, async (): Promise<void> => {
      const nullable = v.string().nullable();
      expect(nullable.nullable().parse('ok').value).assertEqual('ok');
      expect(nullable.transform<number>((value: string | null): number => value === null ? 0 : value.length)
        .parse('abc').value).assertEqual(3);

      const withDefault = v.string().default('a');
      expect(withDefault.nullable().parse(null).success).assertTrue();
      expect(withDefault.default('b').parse(undefined).value).assertEqual('b');

      const transformed = v.string().transform<number>((value: string): number => value.length);
      expect(transformed.default(2).parse(undefined).value).assertEqual(2);

      v.setLocale('en-US');
      expect(v.string().required().nullable().label('Name').validate(undefined).errors[0].message)
        .assertEqual('Name: This field is required');
      v.setLocale('zh-CN');
      expect((await withDefault.nullable().validateAsync(null)).valid).assertTrue();
    });

    it('covers remaining parse and rule branches', 0, async (): Promise<void> => {
      expect(v.string().max(2).validate('abc').errors[0].code).assertEqual(ErrorCode.STRING_MAX);
      expect(v.number().nullable().parse(null).success).assertTrue();
      expect(v.number().transform<string>((value: number): string => `${value}`).parse(2).value).assertEqual('2');
      expect(v.array(v.string()).parse(undefined).success).assertTrue();
      expect((await v.array(v.string()).parseAsync(undefined)).success).assertTrue();
      expect(v.object({}).optional().parse(null).success).assertTrue();
      expect((await v.object({}).optional().parseAsync(undefined)).success).assertTrue();
      expect((await v.union<string>([v.literal('a')]).parseAsync('x')).success).assertFalse();
    });

    it('parses primitive schemas', 0, async (): Promise<void> => {
      expect(v.string().parse('x').value).assertEqual('x');
      expect(v.number().parse(2).value).assertEqual(2);
      expect(v.boolean().parse(true).value).assertTrue();
      expect(v.enumOf(['a', 'b']).parse('b').value).assertEqual('b');
      expect(v.date().parse('2024-01-01').success).assertTrue();
      expect((await v.string().parseAsync('x')).success).assertTrue();
      expect((await v.number().parseAsync(2)).success).assertTrue();
      expect((await v.boolean().parseAsync(true)).success).assertTrue();
      expect((await v.enumOf(['a']).parseAsync('a')).success).assertTrue();
      expect((await v.date().parseAsync('2024-01-01')).success).assertTrue();
    });

    it('returns parse errors without values', 0, (): void => {
      expect(v.string().required().parse('').success).assertFalse();
      expect(v.number().parse('x').success).assertFalse();
      expect(v.boolean().parse('x').success).assertFalse();
      expect(v.enumOf(['a']).parse('x').success).assertFalse();
      expect(v.date().parse('x').success).assertFalse();
      expect(v.array(v.string()).parse('x').success).assertFalse();
      expect(v.object({}).parse([]).success).assertFalse();
    });
  });
}
