import { v, ValidateResult, ValidateError } from '@hmkit/validator';

interface Case {
  title: string;
  result: ValidateResult;
}

@Entry
@Component
struct Index {
  @State cases: Case[] = [];

  aboutToAppear(): void {
    this.cases = this.runCases();
  }

  runCases(): Case[] {
    const list: Case[] = [];

    list.push({
      title: '手机号 13800138000（应通过）',
      result: v.string().required().phone().validate('13800138000'),
    });
    list.push({
      title: '手机号 123（应失败）',
      result: v.string().required().phone().validate('123'),
    });
    list.push({
      title: '身份证 11010519491231002X（应通过）',
      result: v.string().idCard().validate('11010519491231002X'),
    });
    list.push({
      title: '银行卡 6259650871772098（Luhn，应通过）',
      result: v.string().bankCard().validate('6259650871772098'),
    });
    list.push({
      title: '年龄 16，min 18（应失败）',
      result: v.number().min(18, '需年满18岁').validate(16),
    });

    const schema = v.object({
      'name': v.string().required('请输入姓名').min(2),
      'phone': v.string().required().phone(),
      'age': v.number().required().integer().min(18, '需年满18岁'),
    });
    const form: Record<string, Object> = { 'name': '张', 'phone': '139000', 'age': 16 };
    list.push({ title: '表单整体校验（预期 3 处错误）', result: schema.validate(form) });

    return list;
  }

  @Builder
  caseItem(item: Case) {
    Column() {
      Row() {
        Text(item.result.valid ? '✓' : '✗')
          .fontColor(item.result.valid ? '#1AAD19' : '#E64340')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ right: 8 })
        Text(item.title)
          .fontSize(15)
          .layoutWeight(1)
      }
      .width('100%')

      ForEach(item.result.errors, (e: ValidateError) => {
        Text(`· ${e.path || '值'}：${e.message}`)
          .fontSize(13)
          .fontColor('#E64340')
          .width('100%')
          .margin({ top: 4, left: 26 })
      })
    }
    .width('100%')
    .padding(12)
    .borderRadius(10)
    .backgroundColor('#FFFFFF')
    .margin({ bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Text('harmony-validator Demo')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 16 })

      Scroll() {
        Column() {
          ForEach(this.cases, (item: Case) => {
            this.caseItem(item);
          })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor('#F2F3F5')
  }
}
