# harmony-validator

> `@hmkit/validator` —— 纯血鸿蒙（HarmonyOS NEXT / ArkTS）声明式表单/数据校验库。
> 链式 API，内置**手机号、身份证、银行卡、车牌、统一社会信用代码、邮编**等中国本地化规则，开箱即用。

像写 `zod` / `yup` 一样写校验，但国内高频场景一个库全搞定。

## 安装

```bash
ohpm i @hmkit/validator
```

## 快速上手

```ts
import { v } from '@hmkit/validator';

// 单值校验
v.string().required().phone().validate('13800138000'); // { valid: true, errors: [] }

// 对象整体校验（注意 ArkTS 中 Record 字面量 key 必须加引号）
const schema = v.object({
  'name': v.string().required('请输入姓名').min(2),
  'phone': v.string().required().phone(),
  'age': v.number().required().integer().min(18, '需年满18岁'),
});
schema.validate({ 'name': '张', 'phone': '123', 'age': 16 });
// valid=false，errors 带字段路径
```

更多用法见 [`validator/example/Example.ets`](./validator/example/Example.ets)。

## 工程结构

- `validator/` —— 要发布的 HAR 库模块（OHPM 包 `@hmkit/validator`）
- `entry/` —— 测试 App（含可视化 Demo 页，可在 DevEco Previewer 中查看）

## 链接

- OHPM 包详情：https://ohpm.openharmony.cn/#/cn/detail/@hmkit%2Fvalidator
- 库文档：[validator/README.md](./validator/README.md) · [English](./validator/readme-en.md)

## License

[MIT](./validator/LICENSE)
