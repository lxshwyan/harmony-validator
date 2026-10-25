# 1.4.0 发布验证报告

日期：2026-10-25。功能基线为 `7d3078d`，发布版 `@hmkit/validator@1.4.0`。

## 验证结果

| 检查 | 结果 |
| --- | --- |
| Hypium | 299/299，0 Failure / Error / Ignore |
| 行 / 函数 / 分支覆盖率 | 93.20% / 82.98% / 85.53% |
| 原覆盖率门槛 | 90% / 80% / 80%，未降低 |
| 仓库工具测试 | 16 组，通过 |
| Node 真实 HTTP | 8 组，通过；6 个在途取消由服务端确认断连 |
| Standard Schema 桥接 | 官方 spec 1.1.0 严格类型检查，通过；仅 JS/TS 仓库工具 |
| 主入口合约 / 模块化 | 原 83 个符号、18 个规则路径及 reuse 入口，通过 |
| HAR 元数据与扫描 | release / obfuscated / 1.4.0，通过 |
| HAR 体积 | 163289 字节，通过原 163840 字节门槛 |
| API12 主 / 按需消费 | 287845 / 254145 字节，编译通过 |
| API23 主 / 按需消费 | 287845 / 254145 字节，编译通过 |
| 消费安装内容 | 安装的 modules.abc 与本次 HAR 哈希一致 |
| API23 模拟器 | 最终 1.4.0 HAR 消费的两种入口均通过重启、重跑、取消、恢复与退出重进 |
| 模拟器真实 HTTP | 两种入口共 12 个在途取消均由服务端确认 aborted，无 completed |
| OHPM prepublish | `prepublish @hmkit/validator 1.4.0 succeed.` |
| git diff --check | 通过 |
| 真机 | 用户无设备，未验收 |

工具链：DevEco Studio 6.1.0（DS-243.24978.46.36.610850）、HarmonyOS SDK 6.1.0.105 / API23、OHPM 6.1.1.830。模拟器为已有 Pura 90，系统 `OpenHarmony-6.1.0.115`，HDC 明确目标 `127.0.0.1:5555`。API12 为当前 SDK 的目标构建，不是 API12 设备运行保证。

首轮包因新增说明超出原体积门槛 226 字节；将双语 README 中重复的历史列表合并到同包 CHANGELOG 后重建，未提高预算，保留 API 示例与行为边界。SDK 生成声明的 `@keepTs` / `@ts-nocheck` 等既有提示仍保留。

本轮执行日志位于 `/tmp/validator-1.4.0-{verify,build,consumer,prepublish,emulator}.log`。首次 verify 在体积检查处停止；文档调整后从构建开始重跑其余门槛及四种消费构建，并完成 prepublish 和最终模拟器验收。首次模拟器因锁屏未到达消费状态，唤醒并滑动解锁后全流程通过。网络证据由脚本按本轮事件偏移核对，生成于 `external-consumer/build/emulator-validation/`。

## 产物 SHA-256

- HAR：`daad713e191a9260fdd26550d362caa09501f488257545d284ca8f27e54c9ea7`
- API12 主入口 HAP：`dd49440edff9d0b976313e89d9cdef080918e276b4867e7816d67ec6748fe033`
- API12 按需入口 HAP：`24973c6c32b26a0d890b0f623157e2a7c0781bd495b975ca739cab4dd743f1fc`
- API23 主入口 HAP：`5d56eaa7ffc7f278d3ba920b6852d926130c394ca96deb5b7daaca840c6811f4`
- API23 按需入口 HAP：`5304b392d3a823da24be105b4da1a444cf107305aaee49c7828bd9f4d2e54d9c`

## 发布状态

- OHPM：预发布校验已通过，正式 publish 待执行；截至发布前查询，公开 latest 为 1.3.1。
- GitHub / Gitee：1.4.0 发布源码、标签和下载产物待同步。
- prepublish 只校验包内容，不表示发布认证、平台审核或公开可安装已完成，见[华为官方说明](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-hmos-ohpm-prepublish)。

## 使用范围

SchemaFactory 和 nullable shape 修复包含在 HAR。模型生成器、JS/TS 标准桥接、RCP 参考适配器通过源码仓库提供，不在 HAR 中；不表示任意深拷贝、全面不可变或完整 JSON Schema 合规。

当前无真机、弱网、代理、生产服务及跨库性能基准结果。体积是本测试工程的数据，不能作为跨库排名。

[1.4.0 发布说明](RELEASE-1.4.0.md) · [行为与边界](BEHAVIOR-COMPATIBILITY.md)
