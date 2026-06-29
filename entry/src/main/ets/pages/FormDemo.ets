import { v } from '@hmkit/validator';
import { router } from '@kit.ArkUI';
import { FormValidator } from '../form/FormValidator';

/**
 * ArkUI 表单联动 Demo：输入时实时校验，提交时整体校验。
 * 展示 @hmkit/validator 与 ArkUI TextInput 的联动用法。
 */
@Entry
@Component
struct FormDemo {
  // 字段名 -> 校验器；FormValidator 据此实时/整体校验
  private validator: FormValidator = new FormValidator({
    'username': v.string().required('请输入用户名').min(3, '用户名至少3位'),
    'phone': v.string().required('请输入手机号').phone(),
    'age': v.number().required('请输入年龄').integer('年龄须为整数').min(18, '需年满18岁'),
  });

  @State username: string = '';
  @State phone: string = '';
  @State age: string = '';
  @State errors: Record<string, string> = {};
  @State submitTip: string = '';
  @State submitOk: boolean = false;

  // 把当前输入拼成校验用的值对象（age 字符串转数字）
  private currentValues(): Record<string, Object> {
    const vals: Record<string, Object> = { 'username': this.username, 'phone': this.phone };
    if (this.age !== '') {
      vals['age'] = Number(this.age);
    }
    return vals;
  }

  // 更新某字段错误（不可变替换以触发刷新）
  private setError(name: string, msg: string | null): void {
    const next: Record<string, string> = {};
    for (const k of Object.keys(this.errors)) {
      if (k !== name) {
        next[k] = this.errors[k];
      }
    }
    if (msg !== null) {
      next[name] = msg;
    }
    this.errors = next;
  }

  @Builder
  field(label: string, name: string, value: string, inputType: InputType,
    onChange: (val: string) => void) {
    Column() {
      Text(label).fontSize(14).fontColor('#666').margin({ bottom: 4 })
      TextInput({ text: value, placeholder: `请输入${label}` })
        .type(inputType)
        .height(44)
        .borderRadius(8)
        .backgroundColor('#FFFFFF')
        .borderWidth(1)
        .borderColor(this.errors[name] !== undefined ? '#E64340' : '#E5E5E5')
        .onChange(onChange)
      if (this.errors[name] !== undefined) {
        Text(this.errors[name])
          .fontSize(12).fontColor('#E64340')
          .margin({ top: 4 })
          .width('100%')
          .textAlign(TextAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 14 })
  }

  build() {
    Column() {
      Row() {
        Text('← 返回').fontSize(15).fontColor('#3478F6')
          .onClick(() => router.back())
        Text('表单联动 Demo').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Text('').width(48)
      }
      .width('100%').margin({ top: 16, bottom: 20 })

      this.field('用户名', 'username', this.username, InputType.Normal, (val: string) => {
        this.username = val;
        this.setError('username', this.validator.validateField('username', val));
      })

      this.field('手机号', 'phone', this.phone, InputType.Number, (val: string) => {
        this.phone = val;
        this.setError('phone', this.validator.validateField('phone', val));
      })

      this.field('年龄', 'age', this.age, InputType.Number, (val: string) => {
        this.age = val;
        const num: Object | undefined = val === '' ? undefined : Number(val);
        this.setError('age', this.validator.validateField('age', num));
      })

      Button('提交')
        .width('100%').height(46).margin({ top: 6 })
        .onClick(() => {
          const errs = this.validator.validateAll(this.currentValues());
          this.errors = errs;
          this.submitOk = Object.keys(errs).length === 0;
          this.submitTip = this.submitOk ? '✓ 校验通过，可以提交' : `✗ 还有 ${Object.keys(errs).length} 处错误`;
        })

      if (this.submitTip !== '') {
        Text(this.submitTip)
          .fontSize(15)
          .fontColor(this.submitOk ? '#1AAD19' : '#E64340')
          .margin({ top: 14 })
      }
    }
    .width('100%').height('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor('#F2F3F5')
  }
}
