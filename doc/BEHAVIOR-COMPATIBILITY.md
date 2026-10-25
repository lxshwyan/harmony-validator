# 行为、兼容性与安全复用

本文对应 1.4.0，以 1.3.1 为基础。`reuse` 新入口需要安装 1.4.0；1.3.1 不包含该入口。OHPM 可用性以公开注册表为准，发布验证见 [1.4.0 验证报告](VALIDATION-1.4.0.md)。

## 兼容性证据如何理解

| 项目 | 当前证据 |
| --- | --- |
| 库版本 | 1.4.0；保留原 83 个主入口符号 |
| 最低兼容配置 | API12，来自项目配置，不等于 API12 设备验收 |
| 工具链 | DevEco Studio 6.1.0，DS-243.24978.46.36.610850；HarmonyOS SDK 6.1.0.105 / API23 |
| 消费编译 | 同一 DevEco SDK 分别按 API12 / API23 目标构建；主入口与按需入口均检查 |
| 模拟器 | 已有 Pura 90 / API23；实际执行结果见开发验证报告 |
| 真机 | 用户没有真机，未验收 |
| 声明提示 | 当前 DevEco 自动生成 `.d.ets` 中的 `@keepTs` / `@ts-nocheck` 会触发消费警告；未修改生成物隐藏提示 |

`@hmkit/validator/form` 是本包的子路径，FormValidator 不要求安装 `@hmkit/form`，也不直接创建 ArkUI 组件。

## 缺失、空值与解析

| 写法 | 缺失 / undefined | null | 空字符串 |
| --- | --- | --- | --- |
| `liteV.string()` | 通过 | 通过 | 通过，跳过后续字符串规则 |
| `liteV.string().required()` | 失败 | 失败 | 失败 |
| `liteV.string().required().nullable()` | 失败 | 通过 | 失败 |
| `liteV.string().required().default('x')` | validate 允许；parse 返回 x | 失败 | 失败 |
| `liteV.object(shape)` | 默认失败 | 默认失败 | 类型失败 |
| `liteV.array(item)` | 默认允许 | 默认允许 | 类型失败 |

基础字符串 parse 保留传入值：默认可选不代表把 null / 空串转换成 undefined。`nullable` 允许 null；`default` 只替换 undefined，不能当作 null 的替代规则。默认值直接输出，需由定义者保证满足业务约束。

`validate` 主要返回有效性，`parse` 返回处理后的数据；需要 default / transform 结果时使用 parse。TransformSchema 和 uniqueBy 的 validate 也会执行解析/转换，回调有副作用时要特别注意。

`ObjectSchema` 默认保留未知字段；`.strict()` 拒绝未知字段；`.strip()` 接受未知字段但在 parse 输出中删除。不要把它们当作同一默认行为。

`partial(keys?)` 仅使对象指定字段的 undefined / 缺失可跳过；显式 null 仍由子规则判断。它不自动合并到已有完整对象，也不自动把显式 `Model` 泛型改成可选模型。

## 规则实例的共享边界

基础 Schema 的 `.min/.max/.required/.optional` 等方法修改自身；对象的 `.partial/.pick/.omit` 返回新容器，内部子 Schema 引用仍可能共享。

不要从同一个可变字符串实例分别调用 `.max(8)` 和 `.max(32)`，期望得到独立的两份规则。稳定版可直接使用返回新 Schema 的构造函数。

1.4.0 新增可选入口 `@hmkit/validator/reuse`：

```typescript
import { liteV, StringSchema } from '@hmkit/validator/lite';
import { SchemaFactory } from '@hmkit/validator/reuse';

const names = new SchemaFactory<StringSchema>((): StringSchema => liteV.string().required());
const shortNames = names.derive((s: StringSchema): StringSchema => s.max(8));
const longNames = names.derive((s: StringSchema): StringSchema => s.max(32));
shortNames.create().validate('123456789'); // 失败
longNames.create().validate('123456789');  // 通过
```

`derive` 是惰性的，每次 create 重新调用完整构造函数，再依次应用配置；不缓存实例，不序列化回调，不修改旧链式行为。

必须把可变子 Schema、递归图、可变默认对象等放在构造函数内部创建。若回调总是返回外部已存在的实例，或子规则来自外部共享对象，工厂也无法使它们独立。自定义回调捕获的外部状态仍由调用方管理。这是构造隔离，不是任意 Schema 的深拷贝或所有方法的不可变改造。

## 显式类型与单一来源生成

`liteV.object<Model>(shape)` 保留显式结果类型，不逐字段证明 Model 与 shape 一致。需要降低两份定义的维护成本时，可使用开发工具：

```bash
node scripts/model-codegen.mjs example/models/order.model.json example/models/Order.generated.ets
node scripts/model-codegen.mjs example/models/order.model.json example/models/Order.generated.ets --check
```

同一份 JSON 生成输入、输出、浅层 Patch 接口及每次新建 Schema 的函数。示例包含嵌套数组、nullable、默认值和字符串 length 转数字：输入 referenceLength 是 string，输出为 number。

`--check` 比较生成文件全文，定义变化但没有重新生成、或者手改生成代码都会失败。日常修改 JSON 定义，不分别维护生成的两套规则。

当前生成子集：string / number / boolean / object / array，字段 required / nullable / scalar default、min / max、integer，以及 trim / lowercase / length 三种字符串转换。nullable 数组元素需手写 Schema，生成器明确拒绝。对象输出采用 strip。Patch 只放宽根对象字段，缺失字段不填默认值；传入的嵌套对象仍需完整，合并后应再校验完整对象。

可选但不可空的生成字段由对象级 partial 表达；字段出现时仍使用 required 子规则，避免原生“默认可选”允许 null 导致生成类型失真。未知配置、保留标识符、未支持类型和任意自定义回调明确报错，不默默丢掉约束。

这是受支持子集的代码生成，不是从任意现有 Schema 自动推导 ArkTS 类型，也不覆盖用户后来对生成 Schema 的任意手动修改。

## 请求取消

参考适配器：[HttpValidation.ets](../example/HttpValidation.ets)。这是 HarmonyOS API12+ 的 RemoteCommunicationKit / RCP 示例，不是 OpenHarmony 核心库的生产依赖。每次校验拥有独立 session；取消时显式 cancel(request)，各结束路径退订并 close；已取消时不会创建请求。统计中的 destroyed 表示已关闭的独立 session。页面退出应取消令牌并 dispose 其 FormValidator。

本轮模拟器实测中，仅调用 NetworkKit 的 http.destroy() 未能让服务端观察到在途请求提前关闭，因此没有将它作为“已证明停止传输”的参考实现。不同系统和网络适配器应独立验收，不能只看调用了哪个清理方法。OpenHarmony 项目可按同一取消协议接入自身支持的网络 API。

`ValidationCancellationToken` 通知适配器清理；它不能撤回服务器已处理的业务，也不能撤回已经进入提交 handler 的操作。超时不强制终止同步 CPU 工作。输入保护与 JSON Schema 诊断的限制继续遵循 [1.3 指南](ADVANCED-1.3.0.md)。

消费示例同时在 onPageHide 和 aboutToDisappear 清理页面令牌。根页面进入后台不一定销毁组件，不能只依赖 aboutToDisappear；onPageShow 重新创建校验，并通过当前令牌身份隔离旧任务的 finally，避免旧调用清除新页面 busy 状态。

## JS / TS 标准接口桥接

`tooling/standard-schema.mjs` 与 `.d.mts` 提供独立的 JS/TS 适配器，位于仓库工具层，未打入纯 ArkTS HAR。用 `toStandardSchema(schema, { async: true })` 得到 `~standard` v1 对象；有异步规则时必须选择 async 模式，默认同步模式只执行同步规则。

成功返回 parse 后的输出，失败映射 issues，异常保留抛出/拒绝；旧式只有 validate 的第三方 Schema 则返回通过校验的原值。支持 libraryOptions / 固定 validationOptions 中的 context、错误裁剪、取消与异步超时；子令牌隔离，不取消共享父令牌。同步桥接拒绝 timeoutMs。

原生点分路径不能无损表达包含点号的字段名；需要精确路径时传入 mapPath。TS 声明保留显式输出泛型，但不产生 ArkTS 中不存在的类型推导。官方 `@standard-schema/spec` 1.1.0 仅作为开发依赖执行接口类型检查，没有添加到生产库依赖。

运行 `bash scripts/verify-tooling.sh` 检查生成文件、工具层、HTTP 回环及正式标准接口类型。消费构建另外检查生成 ArkTS 与 RCP 参考适配器。
