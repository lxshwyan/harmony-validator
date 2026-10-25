# 后续改进开发验证记录

本文保留发布前的开发验证快照，以下 1.3.1 元数据与产物哈希仅对应当时的本地构建。正式 1.4.0 的检查、发布与下载状态见 [1.4.0 验证报告](VALIDATION-1.4.0.md)。

日期：2026-10-25。开发分支 `codex/validator-stability`，基线 `v1.3.1 / 2f1c7da`。本分支尚未发布新版本；本地 HAR 仍使用基线版本元数据，不代表 OHPM 的 1.3.1 包已包含新功能。

## 实现范围

- 新增 `@hmkit/validator/reuse`：SchemaFactory 惰性构造与派生；可派生不同输出类型。保留现有可变 API，不实现任意对象深拷贝。
- 单一 JSON 定义生成 ArkTS Input / Output / Patch 接口及 Schema 构造器，`--check` 防止生成文件漂移。支持子集和限制见[行为说明](BEHAVIOR-COMPATIBILITY.md)。
- 独立 JS/TS Standard Schema v1 桥接，使用官方 spec 1.1.0 做严格类型检查；不打入纯 ArkTS HAR，也不宣称 ArkTS 获得 TS 类型推导。
- HarmonyOS RCP 请求适配器、真实 HTTP 回环服务、主/按需消费页与模拟器网络验收。
- 修复对象 shape 声明不接受 nullable 输出的问题；消费页补充隐藏/显示生命周期及旧异步 finally 隔离。
- 根 README 与库的中英文 README 均补充 GitHub / Gitee 开源地址。

## 检查结果

| 检查 | 结果 |
| --- | --- |
| 原始基线 Hypium | 293 / 293 |
| 最终 Hypium | 299 / 299，0 Failure / Error / Ignore |
| 行 / 函数 / 分支覆盖率 | 93.20% / 82.98% / 85.53% |
| 原覆盖率门槛 | 90% / 80% / 80%，未降低 |
| 工具层 | 16 组宿主测试通过，含默认/转换/可选/nullable/Patch/漂移/标准路径/错误/异常/取消/超时 |
| 官方 Standard Schema 接口 | spec 1.1.0 + TypeScript strict / noEmit，通过 |
| 真实 Node HTTP | 8 组；12 个请求均清理，6 个在途取消均在服务端观察到 aborted |
| 主入口 API 合约 | 原 83 个符号保留 |
| 模块化与敏感文件扫描 | 18 个规则路径及 reuse 新入口，通过 |
| HAR 体积 | 163641 字节；原 163840 字节门槛未提高，余量 199 字节 |
| API12 主 / 按需消费 HAP | 287845 / 254145 字节，构建通过 |
| API23 主 / 按需消费 HAP | 287845 / 254145 字节，构建通过 |
| API23 模拟器消费 | 主入口与按需入口的重启、重跑、取消、恢复、退出重进均通过 |
| 模拟器真实 HTTP | 两种入口均通过；服务端断连证据另行保存 |
| 真机 | 用户没有真机，本轮未验收 |
| git diff --check | 通过 |

体积只代表本测试工程，新增页面还包含网络验收代码；这些数字不能当作库相对其他方案的包体排名。工具链为 DevEco Studio 6.1.0（DS-243.24978.46.36.610850），已安装 HarmonyOS SDK 6.1.0.105 / API23。编译目标 API12 / API23 使用同一工具链，API12 未作设备运行保证。

编译仍有 SDK 生成 `.d.ets` 的 `@keepTs` / `@ts-nocheck` 提示、消费工程未配置签名提示，以及测试辅助轮询请求的可能抛异常提示；未通过改写生成物隐藏警告。该轮询异常会交给外层验收流程记录为失败。

## 模拟器与网络证据

使用已有 Pura 90 模拟器，HDC 显式目标 `127.0.0.1:5555`，设备模型检查为 emulator，系统返回 `OpenHarmony-6.1.0.115`，配置 API23。

本机 HTTP 服务仅监听 127.0.0.1:18743，模拟器通过 10.0.2.2 访问。正常、名称占用、HTTP503 和断开连接均验证了结果与资源清理。每种入口的 5 个在途取消场景是旧输入被替换、超时、reset、dispose、提交校验中取消；另有一个已确认被服务端接收的请求用于实际页面退出。

两种入口共 12 个在途请求由服务端记录提前关闭，均无 completed 事件；验收脚本按本轮起始事件偏移核对，不复用上一次结果。消费页日志记录每轮普通场景 started=10 / destroyed=10 / cancelled=5 / active=0 / destroyFailures=0；退出场景 started=1 / destroyed=1 / cancelled=1 / active=0。destroyed 在此表示已关闭的独立 RCP session。

证据生成于 `external-consumer/build/emulator-validation/`：

- `main-http.json` / `lite-http.json`：真实 HTTP 验收 PASS。
- `main-http-active.json` / `lite-http-active.json`：退出前请求已开始。
- `main-http-reenter.json` / `lite-http-reenter.json`：退出重进后普通消费恢复 PASS。
- `main-http-process.log` / `lite-http-process.log`：RCP 取消及清理统计。
- `http-server-events.json`：本轮服务端 received / aborted / completed 记录。

## 验证中发现并处理的问题

1. 新测试最初使用了错误 LazySchema 路径和无显式类型的嵌套字面量，已按实际 ArkTS 模块和类型要求修正。
2. 生成模型在消费工程中暴露 NullableSchema 与原 SchemaShape 的声明不兼容。扩宽 shape 输出类型并新增同步、异步回归；没有借助绕过类型检查的注释修复。
3. 默认可选原始标量会允许 null，可能使生成模型的可选非空字段失真。生成器改用对象级 partial 控制缺失，出现的字段保留 required；增加明确 null 的反例。
4. 模拟器首次锁屏导致 aa start 失败，唤醒并滑动解锁后继续。
5. NetworkKit http.destroy() 的初始参考适配器未通过服务端提前断连断言，旧请求仍完成。最终改用提供显式 cancel(request) 的 RCP 独立 session；不把函数调用计数替代传输证据。
6. 根页面后台时未必触发 aboutToDisappear，导致退出请求继续执行。消费页增加 onPageHide 取消、onPageShow 恢复，并隔离旧 finally；通过实际 Back 退出和重新进入验证。

## 重跑

```bash
bash scripts/verify.sh

# 终端一：本地受控 HTTP 服务
node scripts/network-fixture.mjs 18743

# 终端二：先启动已有模拟器并解锁；脚本只接受明确的 emulator 目标
bash scripts/test-consumer-emulator.sh 127.0.0.1:5555 --network
```

若 node 不在 PATH，先执行 `source scripts/env.sh` 使用 DevEco 自带运行时。`verify.sh` 会安装锁定开发依赖、检查生成文件、执行工具层和 HTTP 回环测试、运行 Hypium、构建 HAR、检查门槛并编译四种消费 HAP。

本轮日志暂存 `/tmp/validator-stability-{baseline,tests,build,tooling,consumer,emulator}.log`。基线日志对应 293 项，最终 tests 日志对应 299 项。失败的初始 destroy 方案另有 `/tmp/validator-stability-http-destroy-failed.log`。

模拟器实际运行的本地构建 SHA-256（补充 Gitee 文档之前）：

- HAR：`de31baea4ad5a1f9b43e939e9dcb24261a17350f6539c4c8e40d7ed02eb0f95d`
- API23 主入口 HAP：`65ccfa5dd591f1a61cad95c38aad9a9a91e7fa9ba3f6ed7187436ff1dd1b592e`
- API23 按需入口 HAP：`0055eb051b3ccd910c06716313660b7f5e68eaa04859b2c04c929b5f8eb02012`

补充仓库链接后重新构建 HAR 并通过体积、扫描、API 与模块化门槛；API12/API23 四种消费 HAP 也重新编译通过，日志为 `/tmp/validator-stability-links-{build,consumer}.log`。本次只改文档，未重复运行模拟器；对比重建前消费工程安装的库与新 HAR，`modules.abc` SHA-256 均为 `b0e7f44c07c68a6a888c01ab3f45b8df9254f1ecbd128405ce07d15df7af6320`。

补充链接后的最终本地构建 SHA-256：

- HAR：`9a055464b8edcff4d5178d7a49c6d6ba380b98f688553ea38bcf69df79c4dd6c`
- API23 主入口 HAP：`633d17be7082e323d36a8460519650e52b0f7bb132e1cb3ef573ab9139eb6913`
- API23 按需入口 HAP：`5adef0734e601ecdb0c9fc5e6612ba527952b3a294fee7d7761aa97907aa7f68`

## 保留边界

真机、弱网/代理/真实生产服务、不同硬件系统版本、完整 JSON Schema 合规以及跨库同场性能基准不在本轮完成声明中。真实网络证据来自受控回环 HTTP，仍需目标业务适配器验收。

RCP 参考适配器是 HarmonyOS 示例；核心库仍无网络生产依赖。JS/TS 桥接位于仓库工具层；更多类型与规则没有明确需求时不作数量扩展。SchemaFactory 要求构造函数每次创建完整可变图，模型生成只保证支持子集的单一来源，均不表示任意旧 Schema 已变成不可变或自动推导。
