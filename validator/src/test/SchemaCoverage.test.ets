import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { FormValidator } from '../main/ets/form/FormValidator';

export default function schemaCoverageTest(): void {
  describe('boolean and enum schemas', (): void => {
    it('boolean handles required values and type errors', 0, (): void => {
      expect(v.boolean().required('必须选择').validate(null).errors[0].message).assertEqual('必须选择');
      expect(v.boolean().validate('true').errors[0].message).assertEqual('类型错误，期望布尔值');
      expect(v.boolean().validate(false).valid).assertTrue();
    });

    it('boolean enforces true and false states', 0, (): void => {
      expect(v.boolean().isTrue().validate(false).valid).assertFalse();
      expect(v.boolean().isTrue().validate(true).valid).assertTrue();
      expect(v.boolean().isFalse().validate(true).valid).assertFalse();
      expect(v.boolean().isFalse().validate(false).valid).assertTrue();
    });

    it('boolean supports optional and conditional required', 0, (): void => {
      expect(v.boolean().required().optional().validate(null).valid).assertTrue();
      const schema = v.object({
        'enabled': v.boolean(),
        'accepted': v.boolean().requiredWhen('enabled',
          (value: Object | null | undefined): boolean => value === true, '启用时必须选择'),
      });
      expect(schema.validate({ 'enabled': true } as Record<string, Object>).valid).assertFalse();
      expect(schema.validate({ 'enabled': false } as Record<string, Object>).valid).assertTrue();
    });

    it('boolean async validation matches sync validation', 0, async (): Promise<void> => {
      expect((await v.boolean().isTrue().validateAsync(false)).valid).assertFalse();
    });

    it('enum handles membership and custom messages', 0, (): void => {
      const schema = v.enumOf(['draft', 'done'], '状态无效');
      expect(schema.validate('draft').valid).assertTrue();
      expect(schema.validate('other').errors[0].message).assertEqual('状态无效');
    });

    it('enum handles required optional and empty members', 0, (): void => {
      expect(v.enumOf(['a']).required('必须选择').validate('').errors[0].message).assertEqual('必须选择');
      expect(v.enumOf(['a']).required().optional().validate(null).valid).assertTrue();
      expect(v.enumOf(['', 'a']).required().validate('').valid).assertTrue();
    });

    it('enum supports conditional and async validation', 0, async (): Promise<void> => {
      const schema = v.object({
        'mode': v.string(),
        'level': v.enumOf(['high', 'low']).requiredWhen('mode',
          (value: Object | null | undefined): boolean => value === 'advanced', '请选择等级'),
      });
      expect(schema.validate({ 'mode': 'advanced' } as Record<string, Object>).valid).assertFalse();
      expect((await v.enumOf([1, 2]).validateAsync(2)).valid).assertTrue();
    });
  });

  describe('number and array schemas', (): void => {
    it('number handles empty type and NaN inputs', 0, (): void => {
      expect(v.number().required('请输入数字').validate('').errors[0].message).assertEqual('请输入数字');
      expect(v.number().validate('1').errors[0].message).assertEqual('类型错误，期望数字');
      expect(v.number().validate(NaN).valid).assertFalse();
    });

    it('number enforces range integer and positive rules', 0, (): void => {
      expect(v.number().min(2).validate(1).valid).assertFalse();
      expect(v.number().max(2).validate(3).valid).assertFalse();
      expect(v.number().integer().validate(1.5).valid).assertFalse();
      expect(v.number().positive().validate(0).valid).assertFalse();
      expect(v.number().min(1).max(3).integer().positive().validate(2).valid).assertTrue();
    });

    it('number supports optional and conditional required', 0, (): void => {
      expect(v.number().required().optional().validate(null).valid).assertTrue();
      const schema = v.object({
        'type': v.string(),
        'amount': v.number().requiredWhen('type',
          (value: Object | null | undefined): boolean => value === 'paid', '金额必填'),
      });
      expect(schema.validate({ 'type': 'paid' } as Record<string, Object>).valid).assertFalse();
    });

    it('number custom rules return configured failures', 0, (): void => {
      expect(v.number().custom((value: number): boolean => value % 2 === 0, '必须为偶数')
        .validate(3).errors[0].message).assertEqual('必须为偶数');
      expect(v.number().custom((value: number): boolean => value % 2 === 0, '必须为偶数')
        .validate(4).valid).assertTrue();
    });

    it('number async rules handle false and success', 0, async (): Promise<void> => {
      const schema = v.number().customAsync((value: number): Promise<boolean> => Promise.resolve(value === 8),
        '远程数字校验失败');
      expect((await schema.validateAsync(7)).valid).assertFalse();
      expect((await schema.validateAsync(8)).valid).assertTrue();
    });

    it('array handles required optional and type errors', 0, (): void => {
      expect(v.array(v.string()).required('列表必填').validate(null).errors[0].message).assertEqual('列表必填');
      expect(v.array(v.string()).required().optional().validate(null).valid).assertTrue();
      expect(v.array(v.string()).validate('not-array').errors[0].message).assertEqual('类型错误，期望数组');
    });

    it('array enforces min max and non-empty rules', 0, (): void => {
      expect(v.array(v.string()).min(2).validate(['one']).valid).assertFalse();
      expect(v.array(v.string()).max(1).validate(['one', 'two']).valid).assertFalse();
      expect(v.array(v.string()).nonEmpty().validate([]).valid).assertFalse();
      expect(v.array(v.string()).min(1).max(2).validate(['one']).valid).assertTrue();
    });

    it('array supports conditional required', 0, (): void => {
      const schema = v.object({
        'enabled': v.boolean(),
        'items': v.array(v.string()).requiredWhen('enabled',
          (value: Object | null | undefined): boolean => value === true, '列表必填'),
      });
      expect(schema.validate({ 'enabled': true } as Record<string, Object>).valid).assertFalse();
      expect(schema.validate({ 'enabled': false } as Record<string, Object>).valid).assertTrue();
    });

    it('array async validation preserves element paths', 0, async (): Promise<void> => {
      const schema = v.array(v.string().customAsync((value: string): Promise<boolean> =>
        Promise.resolve(value === 'ok'), '元素无效'));
      const result = await schema.validateAsync(['ok', 'bad']);
      expect(result.valid).assertFalse();
      expect(result.errors[0].path).assertEqual('1');
    });

    it('array async validation rejects invalid containers', 0, async (): Promise<void> => {
      expect((await v.array(v.string()).validateAsync('bad')).valid).assertFalse();
      expect((await v.array(v.string()).required().validateAsync(null)).valid).assertFalse();
    });
  });

  describe('date object and form branches', (): void => {
    it('date accepts Date objects and finite timestamps', 0, (): void => {
      expect(v.date().validate(new Date('2024-01-01T00:00:00Z')).valid).assertTrue();
      expect(v.date().validate(1704067200000).valid).assertTrue();
      expect(v.date().validate({ 'date': '2024-01-01' } as Record<string, Object>).valid).assertFalse();
    });

    it('date enforces min and max boundaries', 0, (): void => {
      expect(v.date().min('2024-01-01').validate('2023-12-31').valid).assertFalse();
      expect(v.date().max('2024-01-01').validate('2024-01-02').valid).assertFalse();
      expect(v.date().min('invalid').max('invalid').validate('2024-01-01').valid).assertTrue();
    });

    it('date supports required optional and conditional required', 0, (): void => {
      expect(v.date().required('日期必填').validate('').errors[0].message).assertEqual('日期必填');
      expect(v.date().required().optional().validate(null).valid).assertTrue();
      const schema = v.object({
        'enabled': v.boolean(),
        'date': v.date().requiredWhen('enabled',
          (value: Object | null | undefined): boolean => value === true, '日期必填'),
      });
      expect(schema.validate({ 'enabled': true } as Record<string, Object>).valid).assertFalse();
    });

    it('strict date returns custom messages and checks time fields', 0, (): void => {
      expect(v.date().strict('ISO 日期错误').validate('2024-13-01').errors[0].message).assertEqual('ISO 日期错误');
      expect(v.date().strict().validate('2024-01-01T24:00:00Z').valid).assertFalse();
      expect(v.date().strict().validate('2024-01-01T23:59:59.123Z').valid).assertTrue();
    });

    it('date async validation mirrors sync rules', 0, async (): Promise<void> => {
      expect((await v.date().min('2024-01-01').validateAsync('2023-01-01')).valid).assertFalse();
    });

    it('object supports optional empty values and root errors', 0, (): void => {
      expect(v.object({}).optional().validate(null).valid).assertTrue();
      expect(v.object({}).validate(null).errors[0].message).assertEqual('对象不能为空');
    });

    it('object refine handles pass and thrown predicates', 0, (): void => {
      const passed = v.object({ 'value': v.number() })
        .refine((data: Record<string, Object>): boolean => data['value'] === 1, '值错误');
      expect(passed.validate({ 'value': 1 } as Record<string, Object>).valid).assertTrue();
      const thrown = v.object({}).refine((_data: Record<string, Object>): boolean => {
        throw new Error('refine failed');
      }, '对象规则失败');
      expect(thrown.validate({} as Record<string, Object>).errors[0].message).assertEqual('对象规则失败');
    });

    it('object async validation keeps shape order and paths', 0, async (): Promise<void> => {
      const schema = v.object({
        'first': v.string().customAsync((_value: string): Promise<boolean> => Promise.resolve(false), '第一项错误'),
        'second': v.string().customAsync((_value: string): Promise<boolean> => Promise.resolve(false), '第二项错误'),
      });
      const result = await schema.validateAsync({ 'first': 'a', 'second': 'b' } as Record<string, Object>);
      expect(result.errors[0].path).assertEqual('first');
      expect(result.errors[1].path).assertEqual('second');
    });

    it('FormValidator covers field async and whole-form sync paths', 0, async (): Promise<void> => {
      const validator = new FormValidator({
        'name': v.string().required('姓名必填').customAsync((value: string): Promise<boolean> =>
          Promise.resolve(value !== 'taken'), '姓名已存在'),
      });
      expect(await validator.validateFieldAsync('unknown', 'value')).assertNull();
      expect(await validator.validateFieldAsync('name', 'taken')).assertEqual('姓名已存在');
      expect(await validator.validateFieldAsync('name', 'available')).assertNull();
      expect(validator.validateAll({ 'name': '' })['name']).assertEqual('姓名必填');
      expect(Object.keys(validator.validateAll({ 'name': 'available' })).length).assertEqual(0);
      expect(validator.isValid({ 'name': 'available' })).assertTrue();
      expect(validator.isValid({ 'name': '' })).assertFalse();
    });
  });
}
