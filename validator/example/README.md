# @hmkit/validator 示例

`Example.ets` 演示了三类用法：

1. **单值校验** —— `v.string().required().phone().validate(value)`
2. **中国本地化规则** —— 身份证、银行卡、车牌、统一社会信用代码、邮编
3. **对象整体校验** —— `v.object({...})`，错误带字段路径

安装：

```bash
ohpm i @hmkit/validator
```

把 `Example.ets` 中的 `runValidatorExamples()` 拷到任意 Ability/Page 调用即可。
