# 1.3.1 发布验证报告

日期：2026-10-17。范围：1.3 系列兼容性维护，不增加公共 API。

## 结果

| 检查 | 结果 |
| --- | --- |
| Hypium | 293/293，通过；0 Failure / Error / Ignore |
| 行 / 函数 / 分支覆盖率 | 93.27% / 83.21% / 85.46% |
| 覆盖率门槛 | 90% / 80% / 80%，未降低 |
| 测试依赖 | `@ohos/hypium` 1.0.29 |
| release HAR | 构建、模块化、API 合约、安全、元数据与 OHPM prepublish 通过 |
| 主入口 API 合约 | 83 个已有符号通过，无新增或删除 |
| HAR 大小 | 162685 字节，通过 163840 字节门槛 |
| API 12 目标消费者 | 主入口 269333 字节；按需入口 235605 字节，均编译通过 |
| API 23 目标消费者 | 主入口 269333 字节；按需入口 235605 字节，均编译通过 |
| 包内容对应关系 | 消费工程安装的 `modules.abc` 与当前 HAR 内容哈希一致 |
| `git diff --check` | 通过 |

API 12 消费工程使用 `compatibleSdkVersion` / `targetSdkVersion` 5.0.0(12)；API 23 消费工程保持最低兼容 API 12，并使用 `targetSdkVersion` 6.1.0(23)。两组都由本机 DevEco SDK 6.1.0.105 构建。

## 产物 SHA-256

- HAR：`b6ebd5850935b082e5d27d8d1c78e612e8189240e9b08db0dce446fcabf0766c`
- API 12 主入口 HAP：`6a8c60428e18dd883aa3df0293c173095f5b81c3358845a1f8fd8e7ced491603`
- API 12 按需入口 HAP：`2efe95fae587bfc73f1905d5884935c963104beca268b82d5c80ea8d41628a6e`
- API 23 主入口 HAP：`891dd156a02467a0aae8869e14061b4f7343d6a3d993c826dca5aec777c724c4`
- API 23 按需入口 HAP：`ca388032a645feb733d2f2edd7632384851a042579e59ceac8d32e9a7ac48817`

## 已知边界

- 当前 DevEco 生成的 `.d.ets` 带有 `@keepTs` / `@ts-nocheck`，严格模式消费者会显示工具链警告；这些注释不在库源码中，本版本没有修改生成产物掩盖警告。
- 本次验证为主机测试和 API 12/API 23 编译矩阵，没有新增真机、弱网或真实网络适配器取消验收。
- 协作式取消仍要求底层适配器响应取消通知；输入保护不是执行沙箱；JSON Schema 支持仍为明确子集。

## 重跑

```bash
./scripts/verify.sh
ohpm prepublish validator/build/default/outputs/default/validator.har
git diff --check
```
