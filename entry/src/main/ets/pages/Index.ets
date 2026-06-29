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
    this.runAsyncCases();
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

    // —— v0.2 新增：数组校验 ——
    list.push({
      title: 'v0.2 数组：[手机号, 123]（下标1应失败）',
      result: v.array(v.string().phone()).validate(['13800138000', '123']),
    });
    list.push({
      title: 'v0.2 数组 min(1)：空数组（应失败）',
      result: v.array(v.string()).min(1, '至少填一项').validate([]),
    });
    list.push({
      title: 'v0.2 数组：全部合法（应通过）',
      result: v.array(v.string().min(2)).validate(['abc', 'de']),
    });

    // —— v0.2 新增：深层嵌套（对象→数组→对象，路径 items.0.name）——
    const orderSchema = v.object({
      'items': v.array(v.object({
        'name': v.string().required('请输入商品名'),
        'qty': v.number().required().min(1, '数量至少为1'),
      })).nonEmpty('至少一件商品'),
    });
    const order: Record<string, Object> = {
      'items': [
        { 'name': '', 'qty': 0 } as Record<string, Object>,
        { 'name': '苹果', 'qty': 2 } as Record<string, Object>,
      ],
    };
    list.push({
      title: 'v0.2 深嵌套：订单 items.0 缺名/数量（路径 items.0.*）',
      result: orderSchema.validate(order),
    });

    return list;
  }

  // —— v0.2 新增：异步校验（模拟远程查重，结果回来后追加到列表）——
  runAsyncCases(): void {
    // 模拟「已注册用户名」远程查重,延迟 300ms 返回
    const checkUsername: (name: string) => Promise<boolean> = (name: string): Promise<boolean> => {
      return new Promise<boolean>((resolve: (v: boolean) => void): void => {
        setTimeout((): void => {
          const taken: string[] = ['admin', 'taken', '张三'];
          resolve(!taken.includes(name));
        }, 300);
      });
    };
    const userSchema = v.string().required('请输入用户名').min(3).customAsync(checkUsername, '该用户名已被占用');

    userSchema.validateAsync('taken').then((r: ValidateResult): void => {
      this.cases = this.cases.concat([{ title: 'v0.2 异步：用户名 taken（远程查重应失败）', result: r }]);
    });
    userSchema.validateAsync('freeuser').then((r: ValidateResult): void => {
      this.cases = this.cases.concat([{ title: 'v0.2 异步：用户名 freeuser（应通过）', result: r }]);
    });
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
