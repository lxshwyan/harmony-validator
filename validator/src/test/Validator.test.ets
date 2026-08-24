import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { FormValidator } from '../main/ets/form/FormValidator';
import { AnySchema } from '../main/ets/core/types';
import { ArraySchema } from '../main/ets/schemas/ArraySchema';
import { EnumSchema } from '../main/ets/schemas/EnumSchema';
import { ObjectSchema } from '../main/ets/schemas/ObjectSchema';

class TypedProfile {
  name: string = '';
  age: number = 0;
}

export default function validatorTest(): void {
  describe('validator core regression', (): void => {
    it('generic schema types compile and preserve model callbacks', 0, (): void => {
      const stringSchema: AnySchema<string> = v.string();
      const arraySchema: ArraySchema<string> = v.array(v.string());
      const enumSchema: EnumSchema<string> = v.enumOf(['draft', 'done']);
      const objectSchema: ObjectSchema<TypedProfile> = v.object<TypedProfile>({
        'name': v.string(),
        'age': v.number(),
      }).refine((profile: TypedProfile): boolean => profile.age >= 0, '年龄无效', 'age');

      expect(stringSchema.validate('ok').valid).assertTrue();
      expect(arraySchema.validate(['a', 'b']).valid).assertTrue();
      expect(enumSchema.validate('draft').valid).assertTrue();
      expect(objectSchema.validate({ 'name': '张三', 'age': 18 } as Record<string, Object>).valid).assertTrue();
    });

    it('required overrides optional when called last', 0, (): void => {
      const result = v.string().optional().required('必填').validate('');
      expect(result.valid).assertFalse();
      expect(result.errors[0].message).assertEqual('必填');
    });

    it('optional overrides required when called last', 0, (): void => {
      expect(v.string().required().optional().validate('').valid).assertTrue();
    });

    it('requiredWhen overrides an earlier optional', 0, (): void => {
      const schema = v.object({
        'type': v.string(),
        'taxId': v.string().optional().requiredWhen('type',
          (value: Object | null | undefined): boolean => value === 'company', '企业税号必填'),
      });
      const result = schema.validate({ 'type': 'company', 'taxId': '' } as Record<string, Object>);
      expect(result.valid).assertFalse();
      expect(result.errors[0].path).assertEqual('taxId');
    });

    it('optional called last disables requiredWhen', 0, (): void => {
      const schema = v.object({
        'type': v.string(),
        'taxId': v.string().requiredWhen('type',
          (value: Object | null | undefined): boolean => value === 'company').optional(),
      });
      expect(schema.validate({ 'type': 'company', 'taxId': '' } as Record<string, Object>).valid).assertTrue();
    });

    it('requiredWhen predicate exception becomes validation error', 0, (): void => {
      const schema = v.object({
        'field': v.string().requiredWhen('other', (): boolean => {
          throw new Error('predicate failed');
        }, '条件校验失败'),
      });
      const result = schema.validate({ 'field': '' } as Record<string, Object>);
      expect(result.valid).assertFalse();
      expect(result.errors[0].message).assertEqual('条件校验失败');
    });

    it('object rejects arrays', 0, (): void => {
      expect(v.object({}).validate([]).errors[0].message).assertEqual('类型错误，期望对象');
    });

    it('object rejects strings', 0, (): void => {
      expect(v.object({}).validate('text').valid).assertFalse();
    });

    it('object rejects Date values', 0, (): void => {
      expect(v.object({}).validate(new Date()).valid).assertFalse();
    });

    it('object preserves nested error paths', 0, (): void => {
      const schema = v.object({
        'items': v.array(v.object({ 'name': v.string().required('名称必填') })),
      });
      const data: Record<string, Object> = {
        'items': [{ 'name': '' } as Record<string, Object>],
      };
      expect(schema.validate(data).errors[0].path).assertEqual('items.0.name');
    });

    it('global RegExp is repeatable', 0, (): void => {
      const schema = v.string().pattern(/^a+$/g);
      expect(schema.validate('aaa').valid).assertTrue();
      expect(schema.validate('aaa').valid).assertTrue();
    });

    it('custom exception becomes configured message', 0, (): void => {
      const result = v.string().custom((): boolean => {
        throw new Error('custom failed');
      }, '自定义校验失败').validate('value');
      expect(result.valid).assertFalse();
      expect(result.errors[0].message).assertEqual('自定义校验失败');
    });

    it('number custom exception becomes configured message', 0, (): void => {
      const result = v.number().custom((): boolean => {
        throw new Error('custom failed');
      }, '数字校验失败').validate(1);
      expect(result.errors[0].message).assertEqual('数字校验失败');
    });

    it('number rejects positive infinity', 0, (): void => {
      expect(v.number().validate(Infinity).valid).assertFalse();
    });

    it('number rejects negative infinity', 0, (): void => {
      expect(v.number().validate(-Infinity).valid).assertFalse();
    });

    it('date rejects infinite timestamp', 0, (): void => {
      expect(v.date().validate(Infinity).valid).assertFalse();
    });

    it('strict date accepts real ISO dates and zoned datetimes', 0, (): void => {
      expect(v.date().strict().validate('2024-02-29').valid).assertTrue();
      expect(v.date().strict().validate('2024-01-01T12:30:00+08:00').valid).assertTrue();
      expect(v.date().strict().validate('2024-01-01T04:30:00Z').valid).assertTrue();
    });

    it('strict date rejects rollover and ambiguous strings', 0, (): void => {
      expect(v.date().strict().validate('2023-02-29').valid).assertFalse();
      expect(v.date().strict().validate('2024-01-01 12:30:00').valid).assertFalse();
      expect(v.date().strict().validate('2024-01-01T12:30:00').valid).assertFalse();
      expect(v.date().strict().validate('2024-01-01T12:30:00+14:01').valid).assertFalse();
    });

    it('mobile rule accepts a valid number', 0, (): void => {
      expect(v.string().phone().validate('13800138000').valid).assertTrue();
    });

    it('mobile rule rejects malformed input', 0, (): void => {
      expect(v.string().phone().validate('123').valid).assertFalse();
    });

    it('id card checks checksum and date', 0, (): void => {
      expect(v.string().idCard().validate('11010519491231002X').valid).assertTrue();
      expect(v.string().idCard().validate('11010519490231002X').valid).assertFalse();
    });

    it('id card rejects a future birthday', 0, (): void => {
      expect(v.string().idCard().validate('110105209912310029').valid).assertFalse();
    });

    it('bank card applies Luhn checksum', 0, (): void => {
      expect(v.string().bankCard().validate('6259650871772098').valid).assertTrue();
      expect(v.string().bankCard().validate('6259650871772099').valid).assertFalse();
    });

    it('credit code checks GB32100 check digit', 0, (): void => {
      expect(v.string().creditCode().validate('91350211M000100Y46').valid).assertTrue();
      expect(v.string().creditCode().validate('91350211M000100Y47').valid).assertFalse();
    });

    it('IPv4 rejects out of range octets', 0, (): void => {
      expect(v.string().ipv4().validate('192.168.1.1').valid).assertTrue();
      expect(v.string().ipv4().validate('256.1.1.1').valid).assertFalse();
    });

    it('VIN checksum is opt-in and validates position nine', 0, (): void => {
      expect(v.string().vinChecksum().validate('1M8GDM9AXKP042788').valid).assertTrue();
      expect(v.string().vinChecksum().validate('1M8GDM9A1KP042788').valid).assertFalse();
      // 旧 vin() 继续只校验格式，避免 patch 版本破坏已有业务。
      expect(v.string().vin().validate('LFV2A21K9C3000000').valid).assertTrue();
      expect(v.string().vinChecksum().validate('LFV2A21K9C3000000').valid).assertFalse();
    });

    it('array validates every element', 0, (): void => {
      const result = v.array(v.string().phone()).validate(['13800138000', '123']);
      expect(result.valid).assertFalse();
      expect(result.errors[0].path).assertEqual('1');
    });

    it('refine assigns error to selected path', 0, (): void => {
      const schema = v.object({ 'pwd': v.string(), 'confirm': v.string() })
        .refine((data: Record<string, Object>): boolean => data['pwd'] === data['confirm'],
          '两次密码不一致', 'confirm');
      const result = schema.validate({ 'pwd': 'a', 'confirm': 'b' } as Record<string, Object>);
      expect(result.errors[0].path).assertEqual('confirm');
    });

    it('FormValidator returns first field error', 0, (): void => {
      const validator = new FormValidator({ 'name': v.string().required('姓名必填') });
      expect(validator.validateField('name', '')).assertEqual('姓名必填');
    });

    it('FormValidator ignores unknown fields', 0, (): void => {
      const validator = new FormValidator({ 'name': v.string().required() });
      expect(validator.validateField('unknown', '')).assertNull();
    });
  });

  describe('validator async regression', (): void => {
    it('async custom rule accepts valid input', 0, async (): Promise<void> => {
      const schema = v.string().customAsync((value: string): Promise<boolean> => Promise.resolve(value === 'ok'),
        '远程校验失败');
      expect((await schema.validateAsync('ok')).valid).assertTrue();
    });

    it('async custom exception becomes configured message', 0, async (): Promise<void> => {
      const schema = v.string().customAsync((_value: string): Promise<boolean> =>
        Promise.reject(new Error('network failed')), '远程校验失败');
      const result = await schema.validateAsync('value');
      expect(result.valid).assertFalse();
      expect(result.errors[0].message).assertEqual('远程校验失败');
    });

    it('object async validation rejects non-object input', 0, async (): Promise<void> => {
      expect((await v.object({}).validateAsync([])).valid).assertFalse();
    });

    it('FormValidator validates all async fields', 0, async (): Promise<void> => {
      const validator = new FormValidator({
        'username': v.string().customAsync((value: string): Promise<boolean> =>
          Promise.resolve(value !== 'taken'), '用户名已存在'),
        'code': v.number().customAsync((value: number): Promise<boolean> =>
          Promise.resolve(value === 9527), '验证码错误'),
      });
      const errors = await validator.validateAllAsync({ 'username': 'taken', 'code': 1 });
      expect(errors['username']).assertEqual('用户名已存在');
      expect(errors['code']).assertEqual('验证码错误');
    });

    it('FormValidator reports async whole-form validity', 0, async (): Promise<void> => {
      const validator = new FormValidator({
        'username': v.string().customAsync((_value: string): Promise<boolean> => Promise.resolve(true), '失败'),
        'code': v.number().customAsync((_value: number): Promise<boolean> => Promise.resolve(true), '失败'),
      });
      expect(await validator.isValidAsync({ 'username': 'available', 'code': 9527 })).assertTrue();
    });
  });
}
