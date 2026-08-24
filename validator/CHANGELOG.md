# Changelog

## 0.4.0

- 为 `AnySchema<T>`、数组和枚举增加 ArkTS 泛型类型保留；`v.object<Model>()` 支持显式业务模型和类型安全的 refine 回调
- `FormValidator` 新增 `validateAllAsync()` / `isValidAsync()`，ObjectSchema 与整表异步字段并发执行并保持稳定错误顺序
- DateSchema 新增 `.strict()`，严格校验真实 ISO 日期和带时区日期时间
- StringSchema 新增 `.vinChecksum()`，按 ISO 3779 校验 VIN 第 9 位；原 `.vin()` 格式校验保持兼容

- 修复 `.optional().required()` / `.optional().requiredWhen()` 的链式状态覆盖，使后调用的方法生效
- `ObjectSchema` 对数组、日期和非对象输入返回明确类型错误
- 修复带 `g` / `y` 标记正则重复校验时 `lastIndex` 导致的结果漂移
- 自定义同步/异步规则与 `requiredWhen` predicate 抛异常时安全返回配置的校验错误
- Number/Date 拒绝无穷值，身份证出生日期拒绝未来日期
- 新增 74 项 Hypium 自动化测试；覆盖率达到 lines 93.11%、functions 84.15%、branches 88.24%
- CI 增加 90% 行 / 80% 函数 / 80% 分支覆盖率门禁，拒绝陈旧报告和覆盖率退化
- GitHub Actions 增加持续验证；OHPM 发布前强制测试并构建 release HAR

## 0.3.0

- **跨字段校验** `v.object({...}).refine(fn, message, path?)`：拿到整个对象判断，支持「确认密码==密码」「结束日期>开始日期」等
- **条件/可选校验** `.optional()` 显式可选；`.requiredWhen(field, predicate, message?)` 当兄弟字段满足条件时才必填
- **新类型**：`v.boolean()`(含 `isTrue`/`isFalse`，如同意协议)、`v.enumOf([...])`(值在集合内)、`v.date()`(接受 Date/时间戳/字符串，含 `min`/`max` 先后)
- **新增中国本地化规则**：固定电话 `landline`、车架号 `vin`、`ipv4`、中文姓名 `chineseName`、`qq`、`wechat`、`url`
- 校验接口新增可选 `siblings` 上下文参数（支撑 `requiredWhen`），同步/异步 API 向后兼容
- **健壮性 & 一致性**：
  - 数字字段空串 `''` 视为空值（修 ArkUI 表单空数字输入误报「类型错误」）
  - `v.date().min/max` 传入非法日期时跳过该规则（修「静默全量拒绝」）
  - 身份证增加出生日期合法性校验；统一社会信用代码增加 GB32100 校验位
  - `.refine()` 内部异常被捕获并按「未通过」处理，不会让整个校验崩溃
  - `.optional()` / `.requiredWhen()` 补齐到 Boolean/Enum/Date/Array；`v.object()` 支持 `.optional()`（可空嵌套对象）
  - `FormValidator.validateField` 增加可选整组值参数，使实时校验也能触发 `requiredWhen`
  - 同步规则未通过时短路异步规则（省一次远程查重请求）；固话、中文姓名规则收紧

## 0.2.0

- **数组校验** `v.array(element)`：支持 `min` / `max` / `nonEmpty` 元素个数约束，逐元素套用校验器，错误路径带下标(如 `0`、`items.0.name`)
- **异步校验** `validateAsync()`：所有校验器新增异步入口；字符串/数字新增 `customAsync(fn, message)`，用于远程查重(用户名/手机号是否已注册)等场景
- **深层嵌套**：对象/数组任意层级互相嵌套,错误路径自动拼接(`a.b.0.c`)
- **ArkUI 表单联动** `FormValidator`：把「字段名->校验器」包成控制器,提供 `validateField`(输入实时校验)/ `validateFieldAsync` / `validateAll`(提交整体校验),与 TextInput 等组件联动
- 同步 API 完全向后兼容,`validate()` 行为不变

## 0.1.1

- 新增 `example/` 使用示例目录（单值校验 / 中国本地化规则 / 对象整体校验）
- 补全 `oh-package.json5` 的 `homepage` 与 `repository` 信息
- 开源仓库地址：https://github.com/lxshwyan/harmony-validator

## 0.1.0

首个版本（MVP）。

- 链式声明式校验 API：`v.string()` / `v.number()` / `v.object()`
- 字符串规则：required / min / max / pattern / custom / email
- 中国本地化规则：手机号、身份证（含校验位）、银行卡（Luhn）、车牌（含新能源）、统一社会信用代码、邮政编码
- 数字规则：required / min / max / integer / positive / custom
- 对象逐字段校验，错误带字段路径（支持 `父.子` 形式）
- 中文默认错误提示，且每条均可自定义
