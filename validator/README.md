# @hmkit/validator

> 鸿蒙 ArkTS 声明式表单/数据校验库。链式 API，内置手机号、身份证、银行卡等**中国本地化规则**，开箱即用。

像写 `zod` / `yup` 一样写校验，但国内高频场景一个库全搞定。

## 特性

- 🔗 **链式声明式 API** —— `v.string().required().phone()`，读起来像说话
- 🇨🇳 **中国规则开箱即用** —— 手机号、身份证（含校验位）、银行卡（Luhn）、车牌（含新能源）、统一社会信用代码、邮编
- 📦 **零依赖**、纯 ArkTS 实现
- 🧩 **对象整体校验** —— 一次校验整个表单，返回每个字段的错误与路径
- 💬 **中文错误提示** —— 默认中文，且每条都可自定义

## 安装

```bash
ohpm install @hmkit/validator
```

## 快速上手

### 单值校验

```typescript
import { v } from '@hmkit/validator';

const result = v.string().required().phone().validate('13800138000');
// result: { valid: true, errors: [] }

const bad = v.string().required().phone().validate('123');
// bad: { valid: false, errors: [{ path: '', message: '请输入正确的手机号' }] }
```

### 表单（对象）校验

```typescript
import { v } from '@hmkit/validator';

// 注意：ArkTS 严格模式要求 Record 字面量的 key 用引号包裹
const schema = v.object({
  'name':  v.string().required('请输入姓名').min(2),
  'phone': v.string().required().phone(),
  'idNo':  v.string().idCard(),
  'age':   v.number().required().integer().min(18, '需年满 18 岁'),
});

const form: Record<string, Object> = {
  'name': '张三',
  'phone': '139xxxx0000',   // 非法
  'idNo': '110101199003074',
  'age': 16,
};

const result = schema.validate(form);
if (!result.valid) {
  for (const e of result.errors) {
    console.error(`${e.path}: ${e.message}`);
    // phone: 请输入正确的手机号
    // age: 需年满 18 岁
  }
}
```

## API

### `v` 工厂

| 方法 | 说明 |
|---|---|
| `v.string()` | 创建字符串校验器 |
| `v.number()` | 创建数字校验器 |
| `v.object(shape)` | 创建对象校验器，`shape` 为 `{ 字段: 校验器 }` |

### StringSchema

| 方法 | 说明 |
|---|---|
| `.required(msg?)` | 必填（空串/未填报错） |
| `.min(len, msg?)` / `.max(len, msg?)` | 长度范围 |
| `.pattern(re, msg?)` | 自定义正则 |
| `.custom(fn, msg)` | 自定义函数，返回 true 通过 |
| `.email(msg?)` | 邮箱 |
| `.phone(msg?)` | 手机号 |
| `.idCard(msg?)` | 18 位身份证（校验位） |
| `.bankCard(msg?)` | 银行卡（Luhn） |
| `.plateNumber(msg?)` | 车牌（含新能源） |
| `.creditCode(msg?)` | 统一社会信用代码 |
| `.postalCode(msg?)` | 邮政编码 |

### NumberSchema

| 方法 | 说明 |
|---|---|
| `.required(msg?)` | 必填 |
| `.min(n, msg?)` / `.max(n, msg?)` | 数值范围（含端点） |
| `.integer(msg?)` | 必须为整数 |
| `.positive(msg?)` | 必须为正数 |
| `.custom(fn, msg)` | 自定义函数 |

### 校验结果

```typescript
interface ValidateResult {
  valid: boolean;
  errors: ValidateError[];   // valid 为 true 时为空数组
}
interface ValidateError {
  path: string;     // 字段路径，单值校验为空串
  message: string;  // 错误提示
}
```

## 版本

当前 `0.1.0`（MVP）。后续计划：数组校验、异步校验、深层嵌套对象、与 ArkUI 表单组件联动。

## License

Apache-2.0
