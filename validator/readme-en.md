# @hmkit/validator

> A declarative form / data validation library for HarmonyOS (ArkTS). Chainable API with built-in **China-localized rules** (mobile number, ID card, bank card, and more) — ready to use out of the box.

Write validations like you do with `zod` / `yup`, but with high-frequency Chinese scenarios covered by a single library.

## Features

- 🔗 **Chainable, declarative API** — `v.string().required().phone()`, reads like plain language
- 🇨🇳 **China rules out of the box** — mobile number, ID card (with checksum), bank card (Luhn), license plate (incl. new-energy), unified social credit code, postal code
- 📦 **Zero dependencies**, pure ArkTS
- 🧩 **Object / array validation** — whole-form validation with per-field error paths (incl. array indices like `items.0.name`)
- 🪆 **Deep nesting** — objects and arrays nested to any depth
- ⏳ **Async validation** — `validateAsync` / `customAsync`, e.g. remote uniqueness checks (is a username / phone already registered)
- 🔗 **Cross-field validation** — `.refine()`, e.g. confirm-password match, end-date after start-date
- 🎚️ **Conditional / optional** — `.optional()`, `.requiredWhen()` (required only when another field matches)
- 🧮 **Many types** — string, number, boolean, enum, date, array, object
- 📝 **ArkUI form binding** — `FormValidator` controller that wires up to `TextInput` and other components in real time
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

### Array

```typescript
import { v } from '@hmkit/validator';

// Per-element validation + length constraints; error path carries the index
v.array(v.string().phone()).validate(['13800138000', '123']);
// { valid: false, errors: [{ path: '1', message: '请输入正确的手机号' }] }

v.array(v.string()).min(1, 'At least one item').validate([]);
// { valid: false, errors: [{ path: '', message: 'At least one item' }] }
```

### Deep nesting (object ↔ array, any depth)

```typescript
const orderSchema = v.object({
  'items': v.array(v.object({
    'name': v.string().required('Name required'),
    'qty':  v.number().required().min(1, 'Qty >= 1'),
  })).nonEmpty('At least one item'),
});

orderSchema.validate({ 'items': [{ 'name': '', 'qty': 0 }] });
// errors: [
//   { path: 'items.0.name', message: 'Name required' },
//   { path: 'items.0.qty',  message: 'Qty >= 1' },
// ]
```

### Async validation (remote uniqueness check)

```typescript
// customAsync runs only on validateAsync; the sync validate() ignores it
const checkUsername = async (name: string): Promise<boolean> => {
  return await api.isUsernameAvailable(name); // true = passes
};

const schema = v.string().required().min(3).customAsync(checkUsername, 'Username taken');
const result = await schema.validateAsync('taken');
// { valid: false, errors: [{ path: '', message: 'Username taken' }] }
```

### ArkUI form binding (FormValidator)

```typescript
import { v, FormValidator } from '@hmkit/validator';

@Entry
@Component
struct RegisterForm {
  private validator: FormValidator = new FormValidator({
    'username': v.string().required('Username required').min(3),
    'phone':    v.string().required().phone(),
    'age':      v.number().required().integer().min(18, 'Must be 18+'),
  });

  @State username: string = '';
  @State errors: Record<string, string> = {};

  build() {
    Column() {
      TextInput({ placeholder: 'Username' })
        .onChange((val: string) => {
          this.username = val;
          // Validate a single field on input; returns the error message (or null)
          const msg = this.validator.validateField('username', val);
          this.errors = msg === null ? {} as Record<string, string>
                                     : { 'username': msg } as Record<string, string>;
        })
      if (this.errors['username'] !== undefined) {
        Text(this.errors['username']).fontColor('#E64340')
      }

      Button('Submit').onClick(() => {
        // Validate the whole form on submit; returns a field -> error map
        const errs = this.validator.validateAll({ 'username': this.username });
        this.errors = errs;
      })
    }
  }
}
```

> A full runnable example lives in `FormDemo.ets` under the repo's `entry` module.

### Cross-field `.refine()`, conditional `.requiredWhen()`, types

```typescript
// Confirm password
const form = v.object({ 'pwd': v.string().required(), 'confirm': v.string().required() })
  .refine((o: Record<string, Object>): boolean => o['pwd'] === o['confirm'], 'Passwords do not match', 'confirm');

// taxId required only when type === 'company'
v.string().requiredWhen('type',
  (t: Object | null | undefined): boolean => (t as string) === 'company', 'Tax ID required');

v.boolean().isTrue('Please accept').validate(false);   // fail
v.enumOf(['male', 'female']).validate('unknown');      // fail
v.date().min('2020-01-01').validate('2019-06-01');     // fail (accepts Date / timestamp / string)
```

## API

### `v` factory

| Method | Description |
|---|---|
| `v.string()` | Create a string validator |
| `v.number()` | Create a number validator |
| `v.boolean()` | Create a boolean validator |
| `v.enumOf(values, message?)` | Enum validator; value must be one of `values` |
| `v.date()` | Date validator (accepts `Date` / timestamp / date string) |
| `v.object(shape)` | Create an object validator; supports `.refine()` for cross-field |
| `v.array(element)` | Create an array validator; `element` is the per-element validator |

### Common methods (all validators)

These work on **every** validator (string / number / boolean / enum / date / array / object):

| Method | Description |
|---|---|
| `.required(msg?)` | Required (empty value fails) |
| `.optional()` | Explicitly optional; empty value skips all rules |
| `.requiredWhen(field, predicate, msg?)` | Required only when sibling `field` matches `predicate` (inside `v.object()`) |
| `.validate(value)` | Synchronous, returns `ValidateResult` |
| `.validateAsync(value)` | Asynchronous, returns `Promise<ValidateResult>` |

> `v.object().optional()` lets the object field be `null`/`undefined` (for nullable nested objects).
> The per-type tables below list only type-specific methods.

### StringSchema

> Common methods (`required`/`optional`/`requiredWhen`) are in the "Common methods" section above.

| Method | Description |
|---|---|
| `.min(len, msg?)` / `.max(len, msg?)` | Length range |
| `.pattern(re, msg?)` | Custom regular expression |
| `.custom(fn, msg)` | Custom function, returns true to pass |
| `.email(msg?)` | Email |
| `.phone(msg?)` | Mainland China mobile number |
| `.idCard(msg?)` | 18-digit resident ID card (birth date + checksum) |
| `.bankCard(msg?)` | Bank card (Luhn) |
| `.plateNumber(msg?)` | License plate (incl. new-energy) |
| `.creditCode(msg?)` | Unified social credit code (with check digit) |
| `.postalCode(msg?)` | Postal code |
| `.landline(msg?)` | Landline phone |
| `.vin(msg?)` | Vehicle VIN (17 chars) |
| `.ipv4(msg?)` | IPv4 address |
| `.chineseName(msg?)` | Chinese name |
| `.qq(msg?)` / `.wechat(msg?)` | QQ / WeChat id |
| `.url(msg?)` | http(s) URL |
| `.customAsync(fn, msg)` | Custom async rule (`fn` returns `Promise<boolean>`), runs only on `validateAsync` |

### NumberSchema

| Method | Description |
|---|---|
| `.required(msg?)` | Required |
| `.min(n, msg?)` / `.max(n, msg?)` | Numeric range (inclusive) |
| `.integer(msg?)` | Must be an integer |
| `.positive(msg?)` | Must be positive |
| `.custom(fn, msg)` | Custom function |
| `.customAsync(fn, msg)` | Custom async rule, runs only on `validateAsync` |

### ArraySchema (`v.array(element)`)

> An empty array counts as "present" (doesn't trigger required); use `min`/`nonEmpty` for length.

| Method | Description |
|---|---|
| `.min(n, msg?)` / `.max(n, msg?)` | Element count range |
| `.nonEmpty(msg?)` | Must not be an empty array |

### BooleanSchema (`v.boolean()`)

> Note `false` is not treated as empty, so it won't trigger required.

| Method | Description |
|---|---|
| `.isTrue(msg?)` / `.isFalse(msg?)` | Must be true / false (e.g. accept terms) |

### EnumSchema (`v.enumOf(values, msg?)`)

Value must `===` one of `values`, otherwise it fails. (Type-specific behavior only; common methods above.)

### DateSchema (`v.date()`)

Accepts a `Date`, a millisecond timestamp, or a parseable date string.

| Method | Description |
|---|---|
| `.min(date, msg?)` / `.max(date, msg?)` | Not before / not after (an unparseable bound makes the rule a no-op) |

### ObjectSchema-specific (`v.object(shape)`)

| Method | Description |
|---|---|
| `.refine(fn, message, path?)` | Cross-field: fails when `fn(wholeObject)` returns `false`; `path` assigns the error to a field. `fn` should null-check internally; thrown errors are caught safely |
| `.optional()` | Skip when the object field is `null`/`undefined` (nullable nested object) |

### Sync / async validation

Every validator exposes two entries:

| Method | Description |
|---|---|
| `.validate(value)` | Synchronous, returns `ValidateResult` |
| `.validateAsync(value)` | Asynchronous, returns `Promise<ValidateResult>`; runs both sync rules and `customAsync` async rules |

### FormValidator (form binding)

```typescript
new FormValidator(shape: Record<string, AnySchema>)
```

| Method | Description |
|---|---|
| `.validateField(name, value)` | Validate a single field, returns the first error message or `null` |
| `.validateFieldAsync(name, value)` | Async single-field validation, returns `Promise<string \| null>` |
| `.validateAll(values)` | Whole-form validation, returns a `Record<field, message>` of failing fields only |
| `.isValid(values)` | Whether the whole form passes, returns `boolean` |

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

## Version

Current `0.3.0`. Roadmap:

- `0.1.0` MVP: chainable API + China-localized rules + object validation
- `0.2.0`: array validation, async validation, deep nesting, ArkUI form binding `FormValidator`
- `0.3.0`: cross-field `.refine()`, conditional/optional `.optional()`/`.requiredWhen()`, new types `v.boolean()`/`v.enumOf()`/`v.date()`, more China rules (landline/VIN/IPv4/Chinese name/QQ/WeChat/URL)

See the full [CHANGELOG](./CHANGELOG.md).

## License

MIT
