import { describe, expect, it } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { ErrorCode } from '../main/ets/core/i18n';

export default function v050StabilityTest(): void {
  describe('0.5 parse execution stability', (): void => {
    it('runs object transforms exactly once', 0, (): void => {
      let calls = 0;
      const schema = v.object({
        'name': v.string().transform<number>((value: string): number => {
          calls++;
          if (calls > 1) {
            throw new Error('transform called twice');
          }
          return value.length;
        }),
      });
      const parsed = schema.parse({ 'name': 'codex' } as Record<string, Object>);
      expect(parsed.success).assertTrue();
      expect(calls).assertEqual(1);
      expect((parsed.value as Record<string, Object>)['name']).assertEqual(5);
    });

    it('runs array custom rules exactly once per element', 0, (): void => {
      let calls = 0;
      const schema = v.array(v.string().custom((_value: string): boolean => {
        calls++;
        return calls <= 2;
      }, '不应重复校验'));
      const parsed = schema.parse(['a', 'b']);
      expect(parsed.success).assertTrue();
      expect(calls).assertEqual(2);
    });

    it('runs object async rules exactly once', 0, async (): Promise<void> => {
      let calls = 0;
      const schema = v.object({
        'name': v.string().customAsync((_value: string): Promise<boolean> => {
          calls++;
          return Promise.resolve(calls === 1);
        }, '不应重复请求'),
      });
      const parsed = await schema.parseAsync({ 'name': 'open' } as Record<string, Object>);
      expect(parsed.success).assertTrue();
      expect(calls).assertEqual(1);
    });

    it('runs array async rules exactly once per element', 0, async (): Promise<void> => {
      let calls = 0;
      const schema = v.array(v.string().customAsync((_value: string): Promise<boolean> => {
        calls++;
        return Promise.resolve(calls <= 2);
      }, '不应重复请求'));
      const parsed = await schema.parseAsync(['a', 'b']);
      expect(parsed.success).assertTrue();
      expect(calls).assertEqual(2);
    });

    it('does not invoke inner validation when a default is used', 0, async (): Promise<void> => {
      let syncCalls = 0;
      let asyncCalls = 0;
      const syncSchema = v.string().custom((_value: string): boolean => {
        syncCalls++;
        return true;
      }, '不会失败').default('fallback');
      const asyncSchema = v.string().customAsync((_value: string): Promise<boolean> => {
        asyncCalls++;
        return Promise.resolve(true);
      }, '不会失败').default('fallback');
      expect(syncSchema.parse(undefined).value).assertEqual('fallback');
      expect((await asyncSchema.parseAsync(undefined)).value).assertEqual('fallback');
      expect(syncCalls).assertEqual(0);
      expect(asyncCalls).assertEqual(0);
    });
  });

  describe('0.5 nested parse and error stability', (): void => {
    it('keeps full paths for nested object array transform errors', 0, (): void => {
      const schema = v.object({
        'profile': v.object({
          'contacts': v.array(v.object({
            'email': v.string().transform<string>((_value: string): string => {
              throw new Error('bad');
            }),
          })),
        }),
      });
      const contact: Record<string, Object> = { 'email': 'x' };
      const contacts: Array<Object> = [contact];
      const profile: Record<string, Object> = { 'contacts': contacts };
      const input: Record<string, Object> = { 'profile': profile };
      const parsed = schema.parse(input);
      expect(parsed.success).assertFalse();
      expect(parsed.errors[0].path).assertEqual('profile.contacts.0.email');
      expect(parsed.errors[0].code).assertEqual(ErrorCode.TRANSFORM);
    });

    it('keeps full paths in async parse errors', 0, async (): Promise<void> => {
      const schema = v.object({
        'items': v.array(v.string().customAsync((_value: string): Promise<boolean> =>
          Promise.resolve(false), '远程校验失败')),
      });
      const parsed = await schema.parseAsync({ 'items': ['x'] } as Record<string, Object>);
      expect(parsed.success).assertFalse();
      expect(parsed.errors[0].path).assertEqual('items.0');
      expect(parsed.errors[0].code).assertEqual(ErrorCode.CUSTOM);
    });

    it('preserves unknown object properties while parsing known fields', 0, (): void => {
      const schema = v.object({
        'age': v.string().transform<number>((value: string): number => parseInt(value, 10)),
      });
      const parsed = schema.parse({ 'age': '18', 'extra': 'kept' } as Record<string, Object>);
      const output = parsed.value as Record<string, Object>;
      expect(output['age']).assertEqual(18);
      expect(output['extra']).assertEqual('kept');
    });

    it('collects all sibling parse errors in stable shape order', 0, (): void => {
      const schema = v.object({
        'first': v.string().required(),
        'second': v.number(),
      });
      const parsed = schema.parse({ 'first': '', 'second': 'bad' } as Record<string, Object>);
      expect(parsed.errors.length).assertEqual(2);
      expect(parsed.errors[0].path).assertEqual('first');
      expect(parsed.errors[1].path).assertEqual('second');
    });

    it('collects array-level and element-level parse errors together', 0, (): void => {
      const parsed = v.array(v.string().min(2)).min(2).parse(['x']);
      expect(parsed.success).assertFalse();
      expect(parsed.errors.length).assertEqual(2);
      expect(parsed.errors[0].code).assertEqual(ErrorCode.ARRAY_MIN);
      expect(parsed.errors[0].path).assertEqual('');
      expect(parsed.errors[1].code).assertEqual(ErrorCode.STRING_MIN);
      expect(parsed.errors[1].path).assertEqual('0');
    });

    it('collects field and refine failures together', 0, (): void => {
      const schema = v.object({
        'name': v.string().required(),
      }).refine((_value: Record<string, Object>): boolean => false, '对象规则失败', 'confirm');
      const parsed = schema.parse({ 'name': '' } as Record<string, Object>);
      expect(parsed.errors.length).assertEqual(2);
      expect(parsed.errors[0].path).assertEqual('name');
      expect(parsed.errors[0].code).assertEqual(ErrorCode.REQUIRED);
      expect(parsed.errors[1].path).assertEqual('confirm');
      expect(parsed.errors[1].code).assertEqual(ErrorCode.REFINE);
    });

    it('keeps async sibling error order deterministic', 0, async (): Promise<void> => {
      const schema = v.object({
        'first': v.string().customAsync((_value: string): Promise<boolean> => Promise.resolve(false), 'first'),
        'second': v.string().customAsync((_value: string): Promise<boolean> => Promise.resolve(false), 'second'),
      });
      for (let i = 0; i < 10; i++) {
        const parsed = await schema.parseAsync({ 'first': 'a', 'second': 'b' } as Record<string, Object>);
        expect(parsed.errors[0].path).assertEqual('first');
        expect(parsed.errors[1].path).assertEqual('second');
      }
    });
  });

  describe('0.5 locale and union stability', (): void => {
    it('isolates custom locale catalogs', 0, (): void => {
      v.addLocale('stable-a', { 'required': 'A {label}' });
      v.addLocale('stable-b', { 'required': 'B {label}' });
      const schema = v.string().label('Name').required();
      v.setLocale('stable-a');
      expect(schema.validate('').errors[0].message).assertEqual('A Name');
      v.setLocale('stable-b');
      expect(schema.validate('').errors[0].message).assertEqual('B Name');
      v.setLocale('zh-CN');
    });

    it('falls back safely for an unknown locale', 0, (): void => {
      v.setLocale('missing-locale');
      const result = v.number().min(3).validate(1);
      expect(result.errors[0].message).assertEqual('不能小于 3');
      expect(result.errors[0].code).assertEqual(ErrorCode.NUMBER_MIN);
      v.setLocale('zh-CN');
    });

    it('short-circuits union candidates after the first success', 0, (): void => {
      let secondCalls = 0;
      const schema = v.union<string>([
        v.string(),
        v.string().custom((_value: string): boolean => {
          secondCalls++;
          return true;
        }, '不会失败'),
      ]);
      expect(schema.parse('ok').success).assertTrue();
      expect(secondCalls).assertEqual(0);
    });

    it('keeps sync and async union failures equivalent', 0, async (): Promise<void> => {
      const schema = v.union<string>([v.literal('a'), v.literal('b')]).label('Mode');
      const sync = schema.parse('x');
      const asyncResult = await schema.parseAsync('x');
      expect(sync.success).assertEqual(asyncResult.success);
      expect(sync.errors[0].code).assertEqual(asyncResult.errors[0].code);
      expect(sync.errors[0].message).assertEqual(asyncResult.errors[0].message);
    });

    it('returns the same result over repeated validations', 0, (): void => {
      const schema = v.string().pattern(/^[a-z]+$/g).min(2).label('Code');
      for (let i = 0; i < 20; i++) {
        expect(schema.validate('valid').valid).assertTrue();
        const invalid = schema.validate('1');
        expect(invalid.valid).assertFalse();
        expect(invalid.errors[0].code).assertEqual(ErrorCode.PATTERN);
      }
    });
  });
}
