import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { toJSONSchema } from '../main/ets/core/schema';

export default function v100EffectsTest(): void {
  describe('1.0 preprocess', (): void => {
    it('runs before validation and parse in sync and async flows', 0, async (): Promise<void> => {
      const schema = v.preprocess<string>((value: Object | null | undefined): Object | null | undefined =>
        typeof value === 'string' ? value.trim() : value, v.string().required().min(2));
      expect(schema.validate('  ok  ').valid).assertTrue();
      expect(schema.parse('  ok  ').value).assertEqual('ok');
      expect((await schema.validateAsync(' x ')).valid).assertFalse();
      expect((await schema.parseAsync(' hello ')).value).assertEqual('hello');
    });

    it('converts callback exceptions to stable localized errors', 0, (): void => {
      const schema = v.preprocess<string>((_value: Object | null | undefined): Object => {
        throw new Error('private implementation detail');
      }, v.string(), '清洗失败').label('姓名');
      const result = schema.parse('Alice');
      expect(result.success).assertFalse();
      expect(result.errors[0].code).assertEqual('preprocess');
      expect(result.errors[0].message).assertEqual('姓名：清洗失败');
      expect(schema.validate('Alice').valid).assertFalse();
    });

    it('supports metadata, wrappers and explicit JSON Schema limitations', 0, (): void => {
      const schema = v.preprocess<string>((value: Object | null | undefined): Object | null | undefined => value,
        v.string().required()).meta({ title: '预处理值' }).describe('运行前清洗').label('值');
      expect(schema.describeSchema().kind).assertEqual('preprocess');
      expect(schema.describeSchema().inner?.kind).assertEqual('string');
      expect(schema.describeSchema().metadata?.description).assertEqual('运行前清洗');
      expect((toJSONSchema(schema)['x-hmkit-unrepresentable'] as Array<Object>)[0])
        .assertEqual('runtime-preprocess');
      expect(schema.nullable().validate(null).valid).assertTrue();
      expect(schema.default('fallback').parse(undefined).value).assertEqual('fallback');
      expect(schema.transform<number>((value: string): number => value.length).parse('abc').value).assertEqual(3);
    });
  });

  describe('1.0 safe coercion', (): void => {
    it('coerces primitive values to strings without stringifying objects', 0, (): void => {
      expect(v.coerceString().parse(123).value).assertEqual('123');
      expect(v.coerceString().parse(true).value).assertEqual('true');
      expect(v.coerceString().parse('text').value).assertEqual('text');
      const objectValue: Record<string, Object> = {};
      expect(v.coerceString().parse(objectValue).errors[0].code).assertEqual('coerce');
    });

    it('coerces non-empty finite numeric strings only', 0, async (): Promise<void> => {
      expect(v.coerceNumber().parse(' 12.5 ').value).assertEqual(12.5);
      expect(v.coerceNumber().parse(3).value).assertEqual(3);
      expect(v.coerceNumber().parse('').success).assertFalse();
      expect(v.coerceNumber().parse('Infinity').success).assertFalse();
      expect(v.coerceNumber().parse(true).success).assertFalse();
      expect((await v.coerceNumber().parseAsync('8')).value).assertEqual(8);
    });

    it('coerces explicit boolean representations only', 0, (): void => {
      expect(v.coerceBoolean().parse('true').value).assertTrue();
      expect(v.coerceBoolean().parse('false').value).assertFalse();
      expect(v.coerceBoolean().parse(1).value).assertTrue();
      expect(v.coerceBoolean().parse(0).value).assertFalse();
      expect(v.coerceBoolean().parse('yes').success).assertFalse();
    });

    it('coerces supported date inputs to independent Date objects', 0, (): void => {
      const original = new Date('2026-01-02T00:00:00.000Z');
      const dateResult = v.coerceDate().parse(original);
      expect(dateResult.success).assertTrue();
      expect(dateResult.value instanceof Date).assertTrue();
      expect(dateResult.value === original).assertFalse();
      expect(v.coerceDate().parse('2026-01-02').success).assertTrue();
      expect(v.coerceDate().parse(0).success).assertTrue();
      expect(v.coerceDate().parse('not-date').success).assertFalse();
      const objectValue: Record<string, Object> = {};
      expect(v.coerceDate('日期转换失败').parse(objectValue).errors[0].message).assertEqual('日期转换失败');
    });

    it('keeps coercion visible in descriptors', 0, (): void => {
      const descriptor = v.coerceNumber().describeSchema();
      expect(descriptor.kind).assertEqual('preprocess');
      expect(descriptor.unrepresentable[0]).assertEqual('coerce:number');
      expect(descriptor.inner?.kind).assertEqual('number');
    });
  });
}
