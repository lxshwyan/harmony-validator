# harmony-validator

> `@hmkit/validator` —— 纯血鸿蒙（HarmonyOS NEXT / ArkTS）声明式表单/数据校验库。
> 链式 API，内置**手机号、身份证、银行卡、车牌、统一社会信用代码、邮编**等中国本地化规则，开箱即用。

像写 `zod` / `yup` 一样写校验，但国内高频场景一个库全搞定。

## 安装

1.4.0 源码与 HAR 下载见 [Releases](https://github.com/lxshwyan/harmony-validator/releases/tag/v1.4.0)。OHPM 1.4.0 尚未上架时请使用 1.3.1；1.4.0 公开状态见 [发布验证报告](doc/VALIDATION-1.4.0.md)。以下为上架后的新版安装命令。

```bash
ohpm i @hmkit/validator@1.4.0
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

1.4.0 新增 HAR 可选入口 SchemaFactory，并修复 nullable 对象 shape 声明。仓库另提供模型/Schema 单一来源生成工具、JS/TS 标准接口桥接和真实 HTTP 取消示例；这些工具与示例不打入 HAR。用法和限制见 [行为与兼容性说明](doc/BEHAVIOR-COMPATIBILITY.md)。

```bash
./scripts/verify.sh
```

验证包含工具层的锁定开发依赖安装、生成文件一致性检查、真实回环 HTTP、Hypium、HAR 门槛以及 API12/API23 消费编译。模拟器网络验收另见 [开发验证记录](doc/VALIDATION-STABILITY.md)，真机未验收。

当前源码版本为 `1.4.0`，见 [1.4.0 发布说明](doc/RELEASE-1.4.0.md)。OHPM 可用性以平台审核与公开注册表结果为准；已有 1.3 系列 API 保持兼容。

## 链接

- 开源仓库：[GitHub](https://github.com/lxshwyan/harmony-validator) · [Gitee](https://gitee.com/lxsh_wyan/harmony-validator)
- OHPM 包详情：https://ohpm.openharmony.cn/#/cn/detail/@hmkit%2Fvalidator
- 库文档：[validator/README.md](./validator/README.md) · [English](./validator/readme-en.md)

## License

[MIT](./validator/LICENSE)
