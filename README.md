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

更多用法见 [`example/Example.ets`](./example/Example.ets)。示例保留在仓库中，不进入发布 HAR。

## 工程结构

- `validator/` —— 要发布的 HAR 库模块（OHPM 包 `@hmkit/validator`）
- `entry/` —— 测试 App（含可视化 Demo 页，可在 DevEco Previewer 中查看）
- `validator/src/test/` —— Hypium 自动化回归测试
- `scripts/verify.sh` —— 测试、release 构建与 HAR 安全检查统一入口

## 开发验证

```bash
./scripts/verify.sh
```

当前版本为 `1.3.1`。本次补丁增加 API 12/API 23 消费构建门禁、升级测试依赖并补齐仓库根许可证，保持 1.3 公共 API 不变。见 [1.3.1 发布说明](doc/RELEASE-1.3.1.md)与 [1.3.0 功能指南](doc/ADVANCED-1.3.0.md)。OHPM 可用性以平台审核结果为准。

## 链接

- OHPM 包详情：https://ohpm.openharmony.cn/#/cn/detail/@hmkit%2Fvalidator
- 库文档：[validator/README.md](./validator/README.md) · [English](./validator/readme-en.md)

## License

[MIT](./validator/LICENSE)
