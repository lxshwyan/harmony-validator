import { describe, it, expect } from '@ohos/hypium';
import { v } from '../main/ets/index';
import { AnySchema, ValidateResult } from '../main/ets/core/types';
import {
  FormFieldState, FormState, FormTrigger, FormValidator, FormValidatorOptions
} from '../main/ets/form/FormValidator';

function wait(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, ms);
  });
}

class RejectingSchema implements AnySchema {
  readonly __schemaType: Object | null = null;

  validate(_value: Object | null | undefined): ValidateResult {
    return { 'valid': true, 'errors': [] };
  }

  validateAsync(_value: Object | null | undefined): Promise<ValidateResult> {
    return Promise.reject(new Error('第三方异步校验失败'));
  }
}

export default function v060Test(): void {
  describe('0.6 form state and trigger strategy', (): void => {
    it('default change trigger validates and returns isolated state snapshots', 0, async (): Promise<void> => {
      const validator = new FormValidator({ 'name': v.string().required('姓名必填') });
      expect((await validator.onChange('name', '') as string)).assertEqual('姓名必填');
      const field: FormFieldState = validator.getFieldState('name');
      expect(field.dirty).assertTrue();
      expect(field.touched).assertFalse();
      expect(field.validating).assertFalse();
      expect(field.error as string).assertEqual('姓名必填');
      field.error = '外部修改';
      const state: FormState = validator.getState();
      expect(state.submitting).assertFalse();
      expect(state.errors['name']).assertEqual('姓名必填');
      expect(validator.getFieldState('name').error as string).assertEqual('姓名必填');
    });

    it('blur-only field ignores change then validates and marks touched on blur', 0, async (): Promise<void> => {
      const options: FormValidatorOptions = {
        'fields': { 'email': { 'triggers': [FormTrigger.BLUR] } }
      };
      const validator = new FormValidator({ 'email': v.string().email('邮箱错误') }, options);
      expect(await validator.onChange('email', 'bad')).assertNull();
      expect(validator.getFieldState('email').dirty).assertTrue();
      expect((await validator.onBlur('email', 'bad')) as string).assertEqual('邮箱错误');
      expect(validator.getFieldState('email').touched).assertTrue();
    });

    it('global manual trigger only validates explicit manual events', 0, async (): Promise<void> => {
      const validator = new FormValidator({ 'code': v.string().required('必填') }, {
        'triggers': [FormTrigger.MANUAL]
      });
      expect(await validator.onBlur('code', '')).assertNull();
      expect((await validator.validateOn('code', '', FormTrigger.MANUAL)) as string).assertEqual('必填');
      expect(await validator.validateOn('unknown', '', FormTrigger.CHANGE)).assertNull();
    });

    it('sync validation stores and clears errors while preserving old API', 0, (): void => {
      const validator = new FormValidator({ 'name': v.string().required('必填') });
      expect(validator.validateField('name', '') as string).assertEqual('必填');
      expect(validator.getState().errors['name']).assertEqual('必填');
      expect(validator.validateField('name', 'ok')).assertNull();
      expect(Object.keys(validator.getState().errors).length).assertEqual(0);
      expect(validator.validateField('missing', '')).assertNull();
    });

    it('whole-form sync validation updates every field state', 0, (): void => {
      const validator = new FormValidator({
        'name': v.string().required('姓名必填'),
        'age': v.number().min(18, '年龄不足')
      });
      const errors = validator.validateAll({ 'name': '', 'age': 20 });
      expect(errors['name']).assertEqual('姓名必填');
      expect(validator.getFieldState('name').error as string).assertEqual('姓名必填');
      expect(validator.getFieldState('age').error).assertNull();
      expect(validator.isValid({ 'name': '鸿蒙', 'age': 20 })).assertTrue();
    });
  });

  describe('0.6 debounce, race protection and dependencies', (): void => {
    it('debounce coalesces calls and completes superseded promises', 0, async (): Promise<void> => {
      let calls = 0;
      const validator = new FormValidator({
        'name': v.string().customAsync((value: string): Promise<boolean> => {
          calls++;
          return Promise.resolve(value === 'latest');
        }, '不可用')
      }, { 'debounceMs': 20 });
      const first = validator.onChange('name', 'old');
      const second = validator.onChange('name', 'latest');
      const results = await Promise.all([first, second]);
      expect(results[0]).assertNull();
      expect(results[1]).assertNull();
      expect(calls).assertEqual(1);
      expect(validator.getFieldState('name').validating).assertFalse();
    });

    it('field debounce overrides the global value and rejects invalid input', 0, async (): Promise<void> => {
      const validator = new FormValidator({ 'name': v.string().required('必填') }, {
        'debounceMs': 100,
        'fields': { 'name': { 'debounceMs': 1 } }
      });
      expect((await validator.onChange('name', '')) as string).assertEqual('必填');
    });

    it('explicit sync validation cancels debounce and clears validating', 0, async (): Promise<void> => {
      const validator = new FormValidator({ 'name': v.string().required('必填') }, { 'debounceMs': 50 });
      const pending = validator.onChange('name', '');
      expect(validator.getFieldState('name').validating).assertTrue();
      expect(validator.validateField('name', 'ok')).assertNull();
      expect(await pending).assertNull();
      expect(validator.getFieldState('name').validating).assertFalse();
    });

    it('latest async input wins when an older request finishes last', 0, async (): Promise<void> => {
      const validator = new FormValidator({
        'name': v.string().customAsync(async (value: string): Promise<boolean> => {
          await wait(value === 'old' ? 30 : 1);
          return value === 'new';
        }, '不可用')
      });
      const oldRequest = validator.validateFieldAsync('name', 'old');
      const newRequest = validator.validateFieldAsync('name', 'new');
      await Promise.all([oldRequest, newRequest]);
      expect(validator.getFieldState('name').error).assertNull();
      expect(validator.getFieldState('name').validating).assertFalse();
      expect(await validator.validateFieldAsync('unknown', 'x')).assertNull();
    });

    it('source change revalidates direct dependent fields', 0, async (): Promise<void> => {
      let dependentCalls = 0;
      const validator = new FormValidator({
        'password': v.string(),
        'confirm': v.string().customAsync((value: string): Promise<boolean> => {
          dependentCalls++;
          return Promise.resolve(value === 'secret');
        }, '两次输入不一致')
      }, {
        'fields': {
          'confirm': { 'dependencies': ['password'] },
          'password': { 'dependencies': [] }
        }
      });
      await validator.onChange('password', 'secret', { 'password': 'secret', 'confirm': 'bad' });
      expect(dependentCalls).assertEqual(1);
      expect(validator.getFieldState('confirm').error as string).assertEqual('两次输入不一致');
      await validator.onChange('password', 'secret');
      expect(dependentCalls).assertEqual(1);
    });

    it('duplicate dependency declarations do not duplicate validation', 0, async (): Promise<void> => {
      let calls = 0;
      const validator = new FormValidator({
        'source': v.string(),
        'target': v.string().customAsync((_value: string): Promise<boolean> => {
          calls++;
          return Promise.resolve(true);
        }, '失败')
      }, { 'fields': { 'target': { 'dependencies': ['source', 'source'] } } });
      await validator.onChange('source', 'x', { 'source': 'x', 'target': 'ok' });
      expect(calls).assertEqual(1);
    });
  });

  describe('0.6 submit and lifecycle', (): void => {
    it('invalid submit marks fields touched and skips the handler', 0, async (): Promise<void> => {
      let submitted = false;
      const validator = new FormValidator({ 'name': v.string().required('必填') });
      const errors = await validator.submit({ 'name': '' }, async (): Promise<void> => {
        submitted = true;
      });
      expect(errors['name']).assertEqual('必填');
      expect(submitted).assertFalse();
      expect(validator.getFieldState('name').touched).assertTrue();
      expect(validator.getState().submitting).assertFalse();
    });

    it('valid submit exposes submitting state inside handler then restores it', 0, async (): Promise<void> => {
      let duringSubmit = false;
      const validator = new FormValidator({ 'name': v.string().required() });
      const errors = await validator.submit({ 'name': 'ok' }, async (): Promise<void> => {
        duringSubmit = validator.getState().submitting;
        await wait(1);
      });
      expect(Object.keys(errors).length).assertEqual(0);
      expect(duringSubmit).assertTrue();
      expect(validator.getState().submitting).assertFalse();
      expect(await validator.isValidAsync({ 'name': 'ok' })).assertTrue();
    });

    it('submit restores state when handler rejects', 0, async (): Promise<void> => {
      const validator = new FormValidator({ 'name': v.string() });
      let rejected = false;
      try {
        await validator.submit({ 'name': 'ok' }, (): Promise<void> => Promise.reject(new Error('提交失败')));
      } catch (_error) {
        rejected = true;
      }
      expect(rejected).assertTrue();
      expect(validator.getState().submitting).assertFalse();
    });

    it('reset cancels debounce and restores reusable clean state', 0, async (): Promise<void> => {
      const validator = new FormValidator({ 'name': v.string().required('必填') }, { 'debounceMs': 50 });
      const pending = validator.onChange('name', '');
      validator.reset();
      expect(await pending).assertNull();
      expect(validator.getFieldState('name').dirty).assertFalse();
      expect(Object.keys(validator.getState().errors).length).assertEqual(0);
      expect((await validator.onChange('name', '')) as string).assertEqual('必填');
    });

    it('dispose cancels pending work and ignores later events', 0, async (): Promise<void> => {
      const validator = new FormValidator({ 'name': v.string().required('必填') }, { 'debounceMs': 50 });
      const pending = validator.onChange('name', '');
      validator.dispose();
      expect(await pending).assertNull();
      expect(validator.getFieldState('name').validating).assertFalse();
      expect(await validator.onChange('name', '')).assertNull();
      validator.reset();
      expect((await validator.validateFieldAsync('name', '')) as string).assertEqual('必填');
    });

    it('third-party async rejection settles debounce and restores all states', 0, async (): Promise<void> => {
      const validator = new FormValidator({ 'remote': new RejectingSchema() }, { 'debounceMs': 1 });
      let fieldRejected = false;
      try {
        await validator.onChange('remote', 'value');
      } catch (_error) {
        fieldRejected = true;
      }
      expect(fieldRejected).assertTrue();
      expect(validator.getFieldState('remote').validating).assertFalse();

      let submitRejected = false;
      try {
        await validator.submit({ 'remote': 'value' });
      } catch (_error) {
        submitRejected = true;
      }
      expect(submitRejected).assertTrue();
      expect(validator.getFieldState('remote').validating).assertFalse();
      expect(validator.getState().submitting).assertFalse();
    });
  });
}
