# @hmkit/validator 1.3.1

这是 1.3 系列的兼容性维护版本，公共 API 与 1.3.0 相同。

- 发布消费工程同时按 API 12 和 API 23 目标语义编译主入口与按需入口。
- 测试依赖升级至 `@ohos/hypium` 1.0.29，不降低测试与覆盖率门槛。
- 仓库根目录新增 MIT License，改善 GitHub 许可证识别和源码复用说明。
- 继续验证 release HAR、模块化入口、API 合约、敏感内容与包体预算。

当前 DevEco 工具链会在生成的 `.d.ets` 文件中写入 `@keepTs` / `@ts-nocheck`，部分消费者可能看到严格类型提示；这些标记不在库源码中，本版本不修改生成产物规避提示。

验证详情见 [1.3.1 验证报告](VALIDATION-1.3.1.md)。真机与真实网络取消仍未纳入本次补丁验收。

OHPM 上架需等待平台审核。审核通过后安装：`ohpm install @hmkit/validator@1.3.1`。

[1.3 中文指南](https://github.com/lxshwyan/harmony-validator/blob/v1.3.1/doc/ADVANCED-1.3.0.md) · [1.3 English guide](https://github.com/lxshwyan/harmony-validator/blob/v1.3.1/doc/ADVANCED-1.3.0-en.md) · [验证报告](https://github.com/lxshwyan/harmony-validator/blob/v1.3.1/doc/VALIDATION-1.3.1.md)
