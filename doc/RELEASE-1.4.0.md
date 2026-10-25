# @hmkit/validator 1.4.0

1.4.0 增加兼容的 Schema 构造隔离方案，并修复对象 shape 的 nullable 输出类型。已有 1.3 系列主入口 API 保留。

## OHPM 包内

安装：`ohpm install @hmkit/validator@1.4.0`。可用性以 OHPM 审核和公开注册表结果为准。

```typescript
import { liteV, StringSchema } from '@hmkit/validator/lite';
import { SchemaFactory } from '@hmkit/validator/reuse';

const names = new SchemaFactory((): StringSchema => liteV.string().required());
const shortNames = names.derive((schema: StringSchema): StringSchema => schema.max(8));
shortNames.create().validate('Alice');
```

每次 create 都重新构建完整规则图。构造回调必须在内部创建可变子 Schema；外部共享实例、递归图和捕获状态不会被自动复制。旧链式方法继续可变，不能把此方案当作任意深拷贝。

对象 shape 现在接受 nullable 输出，包含异步 parse；保留原 83 个主入口符号，SchemaFactory 通过可选子路径导入。

## 仓库配套

- `scripts/model-codegen.mjs`：从单一定义生成 ArkTS 输入、输出、浅层 Patch 和 Schema，`--check` 检查生成漂移；仅覆盖文档列出的子集。
- `tooling/standard-schema.mjs`：独立 JS/TS Standard Schema v1 桥接，不是 ArkTS HAR 的原生接口或自动类型推导。
- `example/HttpValidation.ets`：HarmonyOS API12+ RCP 参考适配器，包含实际取消和资源清理；核心库无网络依赖。

这些工具和示例从源码仓库获取，不随 OHPM HAR 安装。模拟器与真实 HTTP 证据不等于真机或生产弱网验收。

[行为与使用边界](BEHAVIOR-COMPATIBILITY.md) · [1.4.0 验证报告](VALIDATION-1.4.0.md) · [GitHub](https://github.com/lxshwyan/harmony-validator) · [Gitee](https://gitee.com/lxsh_wyan/harmony-validator)
