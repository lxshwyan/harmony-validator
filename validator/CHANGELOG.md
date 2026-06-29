# Changelog

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
