# @hmkit/validator 1.3.0

本次围绕异步校验可靠性、输入保护和业务组合规则增量扩展，保持 83 项主入口导出不变。

- 表单字段取消与超时贯通，修复旧事件、并发提交状态及批次失败后的异步任务清理。
- 新增按需入口 `@hmkit/validator/safety`：输入深度、节点数限制与循环引用检查。
- 新增按需入口 `@hmkit/validator/collections`：按解析后的业务字段去重、自定义消息及错误路径。
- JSON Schema 导入增强：multipleOf、数值排他边界、uniqueItems、contains 数量约束、if/then/else 与严格诊断。
- 补充双语错误码、中英文使用文档和回归测试。

验证：293 项本地测试通过；覆盖率为行 93.27%、函数 83.21%、分支 85.46%；发布 HAR、API 契约、模块隔离、包安全和体积门禁通过。主入口及按需入口独立消费 HAP 在 Pura90 API23 模拟器通过启动、重复执行、取消状态恢复和返回重入冒烟验收。

限制：未完成真机与真实网络验收；模拟器冒烟不等同于所有单元测试的设备执行。不宣称完整 JSON Schema 合规、任意精度计算或按需入口必然减少整个安装包体积。

OHPM 上架需等待平台审核。审核通过后安装：`ohpm install @hmkit/validator@1.3.0`。

[中文指南](https://github.com/lxshwyan/harmony-validator/blob/v1.3.0/doc/ADVANCED-1.3.0.md) · [English guide](https://github.com/lxshwyan/harmony-validator/blob/v1.3.0/doc/ADVANCED-1.3.0-en.md) · [验证报告](https://github.com/lxshwyan/harmony-validator/blob/v1.3.0/doc/VALIDATION-1.3.0.md)
