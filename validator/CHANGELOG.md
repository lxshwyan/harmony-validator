# Changelog

## 0.3.0

- **跨字段校验** `v.object({...}).refine(fn, message, path?)`：拿到整个对象判断，支持「确认密码==密码」「结束日期>开始日期」等
- **条件/可选校验** `.optional()` 显式可选；`.requiredWhen(field, predicate, message?)` 当兄弟字段满足条件时才必填
- **新类型**：`v.boolean()`(含 `isTrue`/`isFalse`，如同意协议)、`v.enumOf([...])`(值在集合内)、`v.date()`(接受 Date/时间戳/字符串，含 `min`/`max` 先后)
- **新增中国本地化规则**：固定电话 `landline`、车架号 `vin`、`ipv4`、中文姓名 `chineseName`、`qq`、`wechat`、`url`
- 校验接口新增可选 `siblings` 上下文参数（支撑 `requiredWhen`），同步/异步 API 向后兼容

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
