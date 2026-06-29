# @hmkit/validator

> A declarative form / data validation library for HarmonyOS (ArkTS). Chainable API with built-in **China-localized rules** (mobile number, ID card, bank card, and more) — ready to use out of the box.

Write validations like you do with `zod` / `yup`, but with high-frequency Chinese scenarios covered by a single library.

## Features

- 🔗 **Chainable, declarative API** — `v.string().required().phone()`, reads like plain language
- 🇨🇳 **China rules out of the box** — mobile number, ID card (with checksum), bank card (Luhn), license plate (incl. new-energy), unified social credit code, postal code
- 📦 **Zero dependencies**, pure ArkTS
- 🧩 **Whole-object validation** — validate an entire form at once and get per-field errors with paths
- 💬 **Chinese error messages** by default, every message overridable

## Installation

```bash
ohpm install @hmkit/validator
```

## Quick Start

### Single value

```typescript
import { v } from '@hmkit/validator';

const result = v.string().required().phone().validate('13800138000');
// result: { valid: true, errors: [] }

const bad = v.string().required().phone().validate('123');
// bad: { valid: false, errors: [{ path: '', message: '请输入正确的手机号' }] }
```

### Form (object)

```typescript
import { v } from '@hmkit/validator';

// Note: ArkTS strict mode requires quoted keys in Record literals.
const schema = v.object({
  'name':  v.string().required('请输入姓名').min(2),
  'phone': v.string().required().phone(),
  'idNo':  v.string().idCard(),
  'age':   v.number().required().integer().min(18, '需年满 18 岁'),
});

const form: Record<string, Object> = {
  'name': '张三',
  'phone': '139xxxx0000',   // invalid
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

### `v` factory

| Method | Description |
|---|---|
| `v.string()` | Create a string validator |
| `v.number()` | Create a number validator |
| `v.object(shape)` | Create an object validator; `shape` is `{ field: validator }` |

### StringSchema

| Method | Description |
|---|---|
| `.required(msg?)` | Required (empty string / missing fails) |
| `.min(len, msg?)` / `.max(len, msg?)` | Length range |
| `.pattern(re, msg?)` | Custom regular expression |
| `.custom(fn, msg)` | Custom function, returns true to pass |
| `.email(msg?)` | Email |
| `.phone(msg?)` | Mainland China mobile number |
| `.idCard(msg?)` | 18-digit resident ID card (checksum) |
| `.bankCard(msg?)` | Bank card (Luhn) |
| `.plateNumber(msg?)` | License plate (incl. new-energy) |
| `.creditCode(msg?)` | Unified social credit code |
| `.postalCode(msg?)` | Postal code |

### NumberSchema

| Method | Description |
|---|---|
| `.required(msg?)` | Required |
| `.min(n, msg?)` / `.max(n, msg?)` | Numeric range (inclusive) |
| `.integer(msg?)` | Must be an integer |
| `.positive(msg?)` | Must be positive |
| `.custom(fn, msg)` | Custom function |

### Result

```typescript
interface ValidateResult {
  valid: boolean;
  errors: ValidateError[];   // empty array when valid
}
interface ValidateError {
  path: string;     // field path; empty string for single-value validation
  message: string;  // error message
}
```

## Roadmap

Current `0.1.0` (MVP). Planned: array validation, async validation, deep nested objects, integration with ArkUI form components.

## License

MIT
