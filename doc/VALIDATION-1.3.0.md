# 1.3.0 本地验证报告

日期：2026-09-16。状态：用户已授权发布 1.3.0；OHPM 可用性以平台审核结果为准。此报告不构成无缺陷、全平台或完整 JSON Schema 合规保证。

## 用户要求的独立复核

本次重新运行原有 289 项测试、release HAR 构建、模块化/API/安全/体积检查及两个独立消费工程构建，全部通过。随后只新增 4 项测试，覆盖共享 Schema 的表单间取消隔离、超时后恢复、嵌套包装错误路径、51 组数值的四入口一致性；完整 293 项连续运行两轮均通过。未修改生产代码。原有 entry 联调文件和 test-form-pilot.sh 的运行前后 SHA-256 完全一致。

独立本地复核未发现新增失败，当时 HDC 返回 Empty。随后按用户要求启动已有模拟器并完成下述验收。以下校验值为实际用于模拟器验收的重建产物；旧构建的归档哈希不应再用于校验当前产物。

## 模拟器验收（2026-09-16）

- 设备：已有 Pura 90，HarmonyOS 6.1.0 / API 23，1320×2856；显式 HDC 目标 `127.0.0.1:5555`，设备型号查询为 `emulator`，没有操作真机。
- IDE 提示镜像缺失，检查发现配置指向 bundled SDK，但镜像已安装在 `Library/Huawei/Sdk`。使用官方 Emulator 启动参数指定现有镜像位置；未重装、重置设备或改写 SDK 配置。
- `bash scripts/test-consumer-emulator.sh 127.0.0.1:5555` 退出码 0。主入口与按需入口分别安装、三次进程停止/启动，均显示 `PASS 1.3 consumer`。
- 两个入口的重复执行、Cancelled 状态、重新执行恢复 PASS、Back 退出后重进均通过。最终发布包复验进程存活，主入口 PID 3325、按需入口 PID 3496。
- 两张最终截图均人工式视觉核对显示 PASS；采集的最终进程日志未匹配 JS error、uncaught、unhandled、app freeze、fatal、crash 关键词。这是限定日志检查，不是所有系统事件均无错误的保证。
- 实际运行消费场景涵盖 safety 深度/节点与循环检查、uniqueBy、JSON 数值/数组/条件规则、字段 dispose 取消通知，以及已有递归、判别联合、超时取消、动态依赖等。
- 范围：这是 HAR 消费集成冒烟，不是把 293 条本地单元测试全部搬到设备。按钮取消验证状态和恢复，不证明点击发生在请求进行中；在途协作取消由消费场景内的任务检查覆盖。没有真实网络适配验收，也没有运行中强杀/所有屏幕规格覆盖。

证据在 `external-consumer/build/emulator-validation/`：main/lite 的 start-1/2/3、repeat、cancel、reenter 布局 JSON，pass.jpeg 截图和 process.log。最终发布包执行摘要位于 `/tmp/validator-130-release-emulator.log`。下述两份 HAP 哈希在验收前后保持一致。

发布前更新中英文版本说明后，重新运行 293 项测试、全部包检查、两个消费工程构建及模拟器验收，均通过。重跑时原模拟器已退出，脚本因无有效 emulator 目标安全停止；重新启动原模拟器后完整复验通过。最终日志为 `/tmp/validator-130-release-{tests,build,consumer,emulator}.log`，下述哈希对应最终发布产物。

## 完成范围

1. FormValidator 字段取消与超时：新输入、显式校验、重置/销毁取消旧任务；并发提交状态隔离；旧事件不派发过期依赖；第三方 Schema 抛错后清理同批次任务。
2. safety 独立入口：迭代式 inspectInput、guarded，显式限额和祖先循环检测。
3. collections 独立入口：uniqueBy 校验解析后的元素键，支持错误路径后缀和自定义消息。
4. JSON Schema 导入：multipleOf、exclusiveMinimum/Maximum、uniqueItems、contains/minContains/maxContains、if/then/else，包含严格参数诊断。
5. 中英文说明、稳定错误码、主/按需 HAR 消费场景及包内声明检查。

主入口已有 83 个符号保持；两个新增包装入口不从主入口导出。完整用法与边界见 [中文指南](ADVANCED-1.3.0.md) / [English guide](ADVANCED-1.3.0-en.md)。

## 可重复检查结果

| 检查 | 结果 |
| --- | --- |
| 修改前基线 | 263 项通过 |
| 最终 Hypium 本地测试 | 293/293，通过；0 Failure / Error / Ignore |
| 重复执行 | 再次 293/293，通过 |
| 行 / 函数 / 分支覆盖率 | 93.27% / 83.21% / 85.46% |
| 覆盖率门槛 | 90% / 80% / 80%，未降低 |
| HAR release 构建 | 通过，元数据版本 1.3.0 |
| 主入口 API 合约 | 83 个已有符号通过 |
| 模块化检查 | 18 个规则路径、原有高级入口、safety/collections 声明及符号通过 |
| 敏感文件 / release 元数据扫描 | 通过 |
| HAR 大小 | 162151 字节，约 158.35 KiB；原有 163840 字节门槛未提高，余量 1689 字节 |
| 独立主入口 HAP 构建 | 通过，269333 字节 |
| 独立按需入口 HAP 构建 | 通过，235605 字节 |
| 消费产物对应关系 | 消费安装后的 modules.abc 与当前 HAR 内容哈希一致 |
| git diff --check | 通过 |
| 本轮设备运行 | Pura90 API23 模拟器主/按需入口冒烟通过；真机未执行 |

两个 HAP 的大小仅为此测试工程的结果，不承诺任意业务工程的包体收益。

最终产物 SHA-256：

- HAR：`d9a2e46ae562bba28aab9af511cf2d67c284048633a29961158683de85d1a7bb`
- 主入口 HAP：`32a92d96862fcfe5aa47df67228877b8b63174d5316f8d5de92f4c0ad83557af`
- 按需入口 HAP：`a534b12174e80dc56c9f86eb0004f08477ed01db64b4d2645154070aa3217818`

## 新增测试覆盖

相对 1.2.0 增加 30 项测试。单个压力用例内部包含 100 次重复取消；另一个用例包含 200 组固定种子数值样本，不将内部循环数虚报为独立测试数。

- 永不自行结束的异步规则：替换、reset、dispose、字段超时均结束调用方等待，并通知清理。
- 整表第三方 Schema 异常取消同批任务；并发提交不会被旧 finally 提前清除 busy。
- 非触发 change、防抖取消、失效事件依赖、兄弟字段 requiredWhen、ContextSchema 兄弟参数保留。
- 深度/节点边界、1000 层迭代遍历、祖先循环与共享子树区分、非法配置、四条执行路径和 transform 保留。
- 解析后的键去重、错误下标、基础错误阻止 selector、大小写标准化、错误数量限制和取消。
- 小数/科学计数/极小数的倍数、排他边界、非有限输入、整数随机样本对照。
- 嵌套结构相等、对象键顺序、contains 零匹配与缺省行为、条件分支、同级组合和非法关键词诊断。

## 过程中发现并处理的问题

- ArkTS 测试代码要求显式 InputLimits / object 泛型；requiredWhen 需要谓词，不接受字符串值参数。已按真实 API 修正。
- 最初的异常清理测试用 customAsync 模拟抛错，但该 API 原有行为是转成普通校验错误，造成另一条永不结束任务超时。改用确实抛错的 AnySchema 测试，保留原 API 行为，最终两轮无超时。
- 接通执行助手后，带 ConfigurableSchema 的字段可能丢失 siblings；已优先调用带 siblings 的标准入口，并添加 ContextSchema 回归。
- 原有“不支持 multipleOf”诊断用例改成明确未知关键词，保留指针转义与诊断行为测试。

## 重跑命令

以下分项组成完整本地质量检查；此次没有在根工程重新安装依赖，以保留现有 entry 表单联调环境。独立消费工程由脚本安装当前 HAR。

```bash
bash scripts/test-local.sh
bash scripts/test-local.sh
bash scripts/build-release.sh
bash scripts/check-modular-rules.sh
bash scripts/scan-har.sh
bash scripts/check-api-contract.sh
bash scripts/check-size-budget.sh
bash scripts/verify-consumer.sh
git diff --check
```

调试日志本机暂存在 `/tmp/validator-130-final-tests.log`、`/tmp/validator-130-repeat-tests.log`、`/tmp/validator-130-final-build.log`、`/tmp/validator-130-final-consumer.log`。标准测试报告在 `validator/.test/default/outputs/test/reports/`。

独立复核日志：`/tmp/validator-130-recheck-tests.log`、`/tmp/validator-130-recheck-expanded.log`、`/tmp/validator-130-recheck-repeat.log`、`/tmp/validator-130-recheck-build.log`、`/tmp/validator-130-recheck-consumer.log`。

## 未验收项与限制

- 本轮 1.3.0 模拟器验收已完成，真机仍未验收；1.2.0 的历史结果未用作本轮证据。
- 独立消费 HAP 尚未配置签名；没有读取私钥、修改签名配置或绕过设备校验。
- 真实网络、弱网和页面实际退出的请求释放尚未验收。测试中取消通知已验证，但适配器是否真正停止请求仍需业务联调。
- 构建仍有生成声明文件相关 ArkTS 警告以及未配置签名警告；构建成功不等于实际运行已经验证。
- 输入保护只检查普通输入数据，不是 CPU/内存沙箱；JSON Schema 支持仍为明确子集；数组结构去重最坏二次复杂度；Number 解析前已经丢失的精度无法恢复。
- 本次未修改原有 entry 表单联调文件、未提交已有推广文章，也没有改动其他库。

真实网络与真机验收尚未完成，该限制保留在发布说明中。用户已授权发布。模拟器保留运行，当前显示按需入口验收页面。
