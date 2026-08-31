import { v, FormTrigger, FormValidator, serializeSchemaDocument, toJSONSchema } from '@hmkit/validator';
import { liteV } from '@hmkit/validator/lite';
import { mobileRule } from '@hmkit/validator/rules/mobile';
import { router } from '@kit.ArkUI';

/**
 * ArkUI 表单联动 Demo：防抖输入校验、失焦触发、状态与异步提交。
 * 展示 @hmkit/validator 与 ArkUI TextInput 的联动用法。
 *
 * 关键：TextInput 的 text 用 $$ 双向绑定到 @State，输入时不会重建输入框、不丢焦点。
 */
@Entry
@Component
struct FormDemo {
  // 1.0.0：真实 App 消费 strict/record、JSON Schema 与版本化描述导出，作为 HAR 入口编译门禁。
  private schemaJson: string = JSON.stringify(toJSONSchema(v.object({
    'username': v.string().required().min(3),
    'phone': v.string().required().phone(),
    'age': v.number().required().integer().min(18),
    'preferences': v.record(v.coerceString()).optional(),
  }).strict().meta({ title: 'RegisterForm' })));
  private schemaDocument: string = serializeSchemaDocument(v.object({
    'username': v.string().required(),
  }).strict());
  // 字段名 -> 校验器；FormValidator 据此实时/整体校验
  private validator: FormValidator = new FormValidator({
    'username': v.string().required('请输入用户名').min(3, '用户名至少3位'),
    // 轻量入口 + 手机号插件：不会因该字段额外加载其他中国规则。
    'phone': liteV.string().required('请输入手机号').use(mobileRule),
    'age': v.number().required('请输入年龄').integer('年龄须为整数').min(18, '需年满18岁'),
  }, {
    'debounceMs': 300,
    'fields': {
      'phone': { 'triggers': [FormTrigger.BLUR] },
      'username': { 'triggers': [FormTrigger.CHANGE] },
    }
  });

  @State username: string = '';
  @State phone: string = '';
  @State age: string = '';
  @State errors: Record<string, string> = {};
  @State submitTip: string = '';
  @State submitOk: boolean = false;
  @State submitting: boolean = false;

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

  private async validateUsername(value: string): Promise<void> {
    const message = await this.validator.onChange('username', value, this.currentValues());
    this.setError('username', message);
  }

  private async validatePhone(): Promise<void> {
    const message = await this.validator.onBlur('phone', this.phone, this.currentValues());
    this.setError('phone', message);
  }

  private async submitForm(): Promise<void> {
    this.submitting = true;
    try {
      const errs = await this.validator.submit(this.currentValues());
      this.errors = errs;
      this.submitOk = Object.keys(errs).length === 0;
      this.submitTip = this.submitOk ? '✓ 校验通过，可以提交' : `✗ 还有 ${Object.keys(errs).length} 处错误`;
    } finally {
      this.submitting = false;
    }
  }

  aboutToDisappear(): void {
    this.validator.dispose();
  }

  @Builder
  errorText(name: string) {
    if (this.errors[name] !== undefined) {
      Text(this.errors[name])
        .fontSize(12).fontColor('#E64340')
        .margin({ top: 4 }).width('100%').textAlign(TextAlign.Start)
    }
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

      // 用户名
      Column() {
        Text('用户名').fontSize(14).fontColor('#666').margin({ bottom: 4 })
        TextInput({ text: $$this.username, placeholder: '请输入用户名' })
          .height(44).borderRadius(8).backgroundColor('#FFFFFF')
          .borderWidth(1).borderColor(this.errors['username'] !== undefined ? '#E64340' : '#E5E5E5')
          .onChange((val: string) => {
            this.validateUsername(val);
          })
        this.errorText('username')
      }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 14 })

      // 手机号
      Column() {
        Text('手机号').fontSize(14).fontColor('#666').margin({ bottom: 4 })
        TextInput({ text: $$this.phone, placeholder: '请输入手机号' })
          .type(InputType.Number)
          .height(44).borderRadius(8).backgroundColor('#FFFFFF')
          .borderWidth(1).borderColor(this.errors['phone'] !== undefined ? '#E64340' : '#E5E5E5')
          .onBlur(() => {
            this.validatePhone();
          })
        this.errorText('phone')
      }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 14 })

      // 年龄
      Column() {
        Text('年龄').fontSize(14).fontColor('#666').margin({ bottom: 4 })
        TextInput({ text: $$this.age, placeholder: '请输入年龄' })
          .type(InputType.Number)
          .height(44).borderRadius(8).backgroundColor('#FFFFFF')
          .borderWidth(1).borderColor(this.errors['age'] !== undefined ? '#E64340' : '#E5E5E5')
          .onChange((val: string) => {
            const num: Object | undefined = val === '' ? undefined : Number(val);
            this.setError('age', this.validator.validateField('age', num));
          })
        this.errorText('age')
      }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 14 })

      Button(this.submitting ? '校验中…' : '提交')
        .width('100%').height(46).margin({ top: 6 })
        .enabled(!this.submitting)
        .onClick(() => {
          this.submitForm();
        })

      if (this.submitTip !== '') {
        Text(this.submitTip)
          .fontSize(15)
          .fontColor(this.submitOk ? '#1AAD19' : '#E64340')
          .margin({ top: 14 })
      }

      Text(this.schemaJson.length > 0 ? 'Schema 描述已就绪' : 'Schema 描述生成失败')
        .fontSize(12).fontColor('#999').margin({ top: 10 })
    }
    .width('100%').height('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor('#F2F3F5')
  }
}
