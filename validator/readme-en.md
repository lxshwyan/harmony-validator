# @hmkit/validator

> A declarative form / data validation library for HarmonyOS (ArkTS). Chainable API with built-in **China-localized rules** (mobile number, ID card, bank card, and more) — ready to use out of the box.

Write validations like you do with `zod` / `yup`, but with high-frequency Chinese scenarios covered by a single library.

## Features

- 🔗 **Chainable, declarative API** — `v.string().required().phone()`, reads like plain language
- 🇨🇳 **China rules out of the box** — mobile number, ID card (with checksum), bank card (Luhn), license plate (incl. new-energy), unified social credit code, postal code
- 🪶 **On-demand rules and plugins** — lite entry, 18 independent rule subpaths, custom sync/async plugins
- 📦 **Zero dependencies**, pure ArkTS
- 🧩 **Object / array validation** — whole-form validation with per-field error paths (incl. array indices like `items.0.name`)
- 🪆 **Deep nesting** — objects and arrays nested to any depth
- ⏳ **Async validation** — `validateAsync` / `customAsync`, e.g. remote uniqueness checks (is a username / phone already registered)
- 🔗 **Cross-field validation** — `.refine()`, e.g. confirm-password match, end-date after start-date
- 🎚️ **Conditional / optional** — `.optional()`, `.requiredWhen()` (required only when another field matches)
- 🧮 **Many types** — string, number, boolean, enum, date, array, object
- 🌐 **i18n and error codes** — built-in Chinese/English, custom catalogs, field labels, stable `code`
- 🧱 **Composition and transforms** — `literal` / `union` / `nullable` / `default` / `transform`
- 🗺️ **Describable schemas** — metadata, stable serialization, and JSON Schema Draft 2020-12 conversion
- 🌳 **Complete composition** — recursive `lazy`, `intersection`, conditional `when`, deep partials, object extend/merge
- 🔁 **Bidirectional pipelines** — codecs, document restoration, JSON Schema import, and custom kind registries
- 🧭 **Flexible execution** — business context, structured errors, error limits, batch validation, and cancellation
- 📝 **ArkUI form binding** — `FormValidator` controller that wires up to `TextInput` and other components in real time
- 💬 **Chinese error messages** by default, every message overridable

## Installation

```bash
ohpm install @hmkit/validator
```

## Quick Start

### 1.1 composition, context, and codecs

```typescript
import { v, validateValue, fromJSONSchema } from '@hmkit/validator';

const amount = v.context(v.number().positive(),
  (value: number, context: Record<string, Object>): boolean =>
    value <= (context['limit'] as number), 'Amount exceeds limit');
validateValue(amount, 80, { context: { 'limit': 100 }, abortEarly: true });

const numberText = v.codec(v.string(), v.number(),
  (input: string): number => Number(input),
  (output: number): string => `${output}`);
numberText.parse('42'); // value = 42
numberText.encode(42);  // value = '42'

const imported = fromJSONSchema({ 'type': 'string', 'minLength': 2 });
```

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

### ArkTS generic types

```typescript
class RegisterModel {
  pwd: string = '';
  confirm: string = '';
}

const form = v.object<RegisterModel>({
  'pwd': v.string().required(),
  'confirm': v.string().required(),
}).refine((data: RegisterModel): boolean => data.pwd === data.confirm,
  'Passwords do not match', 'confirm');

const tags = v.array(v.string());           // ArraySchema<string>
const status = v.enumOf(['draft', 'done']); // EnumSchema<string>
```

ArkTS does not support TypeScript conditional types, `infer`, or mapped types, so object models use an explicit
`v.object<Model>()`. Primitive, array-element, and enum-value types are retained automatically by the factories.

### Localization, field labels, and error codes

```typescript
import { v, ErrorCode } from '@hmkit/validator';

v.setLocale('en-US');
const result = v.string().label('Email').required().email().validate('bad');
// result.errors[0] = { path: '', code: 'email', message: 'Email: Invalid email address' }

if (result.errors[0].code === ErrorCode.EMAIL) {
  // Track or map UI by stable code instead of matching display text.
}

v.addLocale('my-app', {
  'required': '{label} is required',
  'string_min': '{label} needs at least {min} characters',
});
v.setLocale('my-app');
```

Messages are resolved when `validate` / `parse` runs, so already-created schemas respond to later locale changes.
An explicit `message` always wins. Catalog templates may use `{label}`; built-in parameters also include
`{min}`, `{max}`, `{values}`, and `{expected}`.

### Composition, defaults, and transforms

```typescript
const status = v.union<string>([
  v.literal('draft'),
  v.literal('done'),
]);

status.validate('draft'); // pass
status.validate('other'); // code = 'union'

const nickname = v.string().nullable().default('Guest');
nickname.parse(undefined); // { success: true, value: 'Guest', errors: [] }
nickname.parse(null);      // { success: true, value: null, errors: [] }

const age = v.string().required().transform<number>(
  (value: string): number => parseInt(value, 10),
  'Could not transform age',
);
age.parse('18'); // { success: true, value: 18, errors: [] }
```

`validate()` only answers whether a value is valid. Use `parse()` or `parseAsync()` to retrieve defaulted or
transformed output. `default()` handles only `undefined`, while `nullable()` additionally accepts explicit `null`.

### Schema metadata, serialization, and JSON Schema

```typescript
import {
  v, schemaToDescriptor, serializeSchema, serializeSchemaDocument, toJSONSchema
} from '@hmkit/validator';

const userSchema = v.object({
  'name': v.string().required().min(2).label('Name'),
  'age': v.number().integer().min(0),
}).meta({
  id: 'https://example.com/user',
  title: 'User',
  description: 'User profile',
  examples: [{ 'name': 'Alice', 'age': 18 } as Record<string, Object>],
});

const descriptor = schemaToDescriptor(userSchema);
const saved = serializeSchema(userSchema, 2); // 0.8-compatible structure
const document = serializeSchemaDocument(userSchema, 2); // recommended versioned 1.0 document
const jsonSchema = toJSONSchema(userSchema);
```

Every built-in schema supports `.meta(metadata)`, `.describe(text)`, and `.describeSchema()`.
Custom/async predicates, object refinements, runtime transforms, business plugins, and third-party schemas cannot be
represented equivalently by standard JSON Schema. The default mode records them under `x-hmkit-unrepresentable`:

```typescript
toJSONSchema(schema, 'extension'); // default: keep explicit extension notes
toJSONSchema(schema, 'throw');     // fail on anything not representable
toJSONSchema(schema, 'ignore');    // emit only the standard-compatible subset
```

`serializeSchema()` serializes structure, not executable functions. It is intended for documentation, caching, and
auditing; it does not promise to rebuild custom predicates or transforms from JSON.

### 1.0 common schemas, object composition, and safe coercion

```typescript
const settings = v.record(v.coerceString());
settings.parse({ 'retry': 3 }); // retry -> '3'

const point = v.tuple([v.number(), v.number()]);
point.validate([120.1, 30.2]);

const event = v.discriminatedUnion('type', {
  'text': v.object({ 'type': v.literal('text'), 'value': v.string().required() }),
  'count': v.object({ 'type': v.literal('count'), 'value': v.number().required() }),
});

const updateUser = v.object({
  'name': v.string().required(),
  'age': v.number().required(),
  'secret': v.string(),
}).partial(['age']).omit(['secret']).strip();
```

Objects remain `passthrough` by default for 0.x compatibility. `.strict()` rejects unknown keys, while `.strip()`
removes them from parsed output. `partial/pick/omit` return independent schemas. `coerceNumber()` deliberately
does not turn empty strings or booleans into numbers.

### On-demand rules and plugins

The default entry remains fully backward compatible and registers every built-in rule:

```typescript
import { v } from '@hmkit/validator';
v.string().phone().validate('13800138000');
```

When only a few rules are needed, use the lite entry and a rule subpath:

```typescript
import { liteV } from '@hmkit/validator/lite';
import { mobileRule, isMobile } from '@hmkit/validator/rules/mobile';

const phone = liteV.string().required().use(mobileRule);
phone.validate('13800138000');
isMobile('13800138000'); // Pure-function usage is also available
```

Available subpaths are `mobile`, `email`, `idCard`, `bankCard`, `plateNumber`, `creditCode`, `postalCode`,
`landline`, `vin`, `ipv4`, `chineseName`, `qq`, `wechat`, and `url`. This reduces unrelated modules in the
application compile graph; the downloaded OHPM HAR itself still contains the complete package.

Custom plugins support stable codes, localization, and optional asynchronous validation:

```typescript
import { liteV, BasicStringRulePlugin, registerStringRule } from '@hmkit/validator/lite';

const slugRule = new BasicStringRulePlugin(
  'slug',
  'business_slug',
  '只能包含小写字母、数字和减号',
  (value: string): boolean => /^[a-z0-9-]+$/.test(value),
  { 'en-US': 'Only lowercase letters, numbers, and hyphens are allowed' },
);

liteV.string().label('Slug').use(slugRule);
registerStringRule(slugRule);
liteV.string().useRegistered('slug');
```

Thrown predicates and rejected asynchronous plugin promises become configured validation errors instead of crashing the form.

### ArkUI form binding (FormValidator)

```typescript
import { v, FormTrigger, FormValidator } from '@hmkit/validator';

@Entry
@Component
struct RegisterForm {
  private validator: FormValidator = new FormValidator({
    'username': v.string().required('Username required').min(3),
  }, {
    'debounceMs': 300,
    'fields': { 'username': { 'triggers': [FormTrigger.CHANGE] } },
  });

  @State username: string = '';
  @State errors: Record<string, string> = {};

  build() {
    Column() {
      TextInput({ placeholder: 'Username' })
        .onChange((val: string) => {
          this.username = val;
          // Async rules, debounce, and latest-input-wins protection are built in
          this.validator.onChange('username', val, { 'username': val }).then((msg: string | null) => {
            this.errors = msg === null ? {} as Record<string, string>
                                       : { 'username': msg } as Record<string, string>;
          });
        })
      if (this.errors['username'] !== undefined) {
        Text(this.errors['username']).fontColor('#E64340')
      }

      Button('Submit').onClick(async () => {
        // Marks fields touched, tracks submitting, and only runs a handler when valid
        this.errors = await this.validator.submit({ 'username': this.username });
      })
    }
  }
}
```

For blur validation, configure `triggers: [FormTrigger.BLUR]` and call `validator.onBlur(...)` from ArkUI `onBlur`.
Call `dispose()` when the page is destroyed, or `reset()` before reusing the same instance.

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
v.date().strict().validate('2023-02-29');              // fail: nonexistent strict ISO date
v.date().strict().validate('2024-01-01T08:00:00+08:00'); // pass: datetime includes a zone
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
| `v.literal(value, message?)` | Exact-value validator using `===` |
| `v.union(schemas, message?)` | Composition validator; succeeds when any member succeeds |
| `v.record(valueSchema, message?)` | String-keyed record whose values share one schema |
| `v.tuple(items, message?)` | Fixed-length positional array; ArkTS output is `Array<Object>` |
| `v.discriminatedUnion(field, variants, message?)` | Select an object variant directly by its discriminator |
| `v.preprocess(fn, schema, message?)` | Preprocess before the inner schema; thrown errors become `preprocess` issues |
| `v.coerceString/Number/Boolean/Date(message?)` | Safely coerce only explicitly supported representations |
| `v.setLocale(locale)` / `v.getLocale()` | Set/read the current locale (`zh-CN` / `en-US` built in) |
| `v.addLocale(locale, messages)` | Register or incrementally override a custom message catalog |

### Common methods (all validators)

These work on **every** validator (string / number / boolean / enum / date / array / object):

| Method | Description |
|---|---|
| `.required(msg?)` | Required (empty value fails) |
| `.optional()` | Explicitly optional; empty value skips all rules |
| `.requiredWhen(field, predicate, msg?)` | Required only when sibling `field` matches `predicate` (inside `v.object()`) |
| `.label(name)` | Add a business field name to messages without changing the error path |
| `.nullable()` | Additionally accept explicit `null` |
| `.default(value)` | Use a default output when the input is `undefined` |
| `.transform(fn, msg?)` | Transform valid output; exceptions become a `transform` error |
| `.validate(value)` | Synchronous, returns `ValidateResult` |
| `.validateAsync(value)` | Asynchronous, returns `Promise<ValidateResult>` |
| `.parse(value)` | Validate and return typed `ParseResult<T>` output |
| `.parseAsync(value)` | Async validation and typed `Promise<ParseResult<T>>` output |

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
| `.vin(msg?)` | Vehicle VIN format (17 chars) |
| `.vinChecksum(msg?)` | VIN format plus ISO 3779 position-9 check digit |
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
| `.strict(msg?)` | String must be a real `YYYY-MM-DD` or zoned ISO datetime; Date/timestamp remain accepted |

### ObjectSchema-specific (`v.object(shape)`)

| Method | Description |
|---|---|
| `.refine(fn, message, path?)` | Cross-field: fails when `fn(wholeObject)` returns `false`; `path` assigns the error to a field. `fn` should null-check internally; thrown errors are caught safely |
| `.optional()` | Skip when the object field is `null`/`undefined` (nullable nested object) |
| `.strict(msg?)` / `.passthrough()` / `.strip()` | Reject / retain / remove unknown keys during parse; passthrough is the default |
| `.partial(keys?)` | Make all or selected fields optional at the object layer; returns a new schema |
| `.pick(keys)` / `.omit(keys)` | Include/exclude fields and return a new schema; chain `.strip()` for output projection |

### Sync / async validation

Every validator exposes two entries:

| Method | Description |
|---|---|
| `.validate(value)` | Synchronous, returns `ValidateResult` |
| `.validateAsync(value)` | Asynchronous, returns `Promise<ValidateResult>`; runs both sync rules and `customAsync` async rules |

StringSchema also provides `.use(plugin, message?)` and `.useRegistered(name, message?)`. A plugin's asynchronous
part runs only through `validateAsync()` or `parseAsync()`.

### FormValidator (form binding)

```typescript
new FormValidator(shape: Record<string, AnySchema>, options?: FormValidatorOptions)
```

| Method | Description |
|---|---|
| `.validateField(name, value)` | Validate a single field, returns the first error message or `null` |
| `.validateFieldAsync(name, value)` | Async single-field validation, returns `Promise<string \| null>` |
| `.validateAll(values)` | Whole-form validation, returns a `Record<field, message>` of failing fields only |
| `.isValid(values)` | Whether the whole form passes, returns `boolean` |
| `.validateAllAsync(values)` | Concurrent whole-form validation, returns `Promise<Record<field, message>>` |
| `.isValidAsync(values)` | Async whole-form validity, returns `Promise<boolean>` |
| `.validateOn(name, value, trigger, values?)` | Validate according to a field's `change/blur/manual` trigger policy |
| `.onChange(...)` / `.onBlur(...)` | Async convenience methods for ArkUI input and blur events |
| `.submit(values, handler?)` | Mark touched, validate asynchronously, and invoke handler only when valid |
| `.getFieldState(name)` | Snapshot of `touched/dirty/validating/error` |
| `.getState()` | Snapshot of whole-form `submitting/errors` |
| `.reset()` / `.dispose()` | Reset reusable state / clean up pending page work |

`FormValidatorOptions` supports global `triggers` and `debounceMs`, with per-field overrides under `fields[name]`.
`dependencies` lists the source fields a field depends on; a source change revalidates each direct dependent.

### Result

```typescript
interface ValidateResult {
  valid: boolean;
  errors: ValidateError[];   // empty array when valid
}
interface ValidateError {
  path: string;     // field path; empty string for single-value validation
  message: string;  // error message
  code?: string;    // stable code; always present for built-in rules
}
interface ParseResult<T> {
  success: boolean;
  value?: T;        // typed defaulted/transformed output
  errors: ValidateError[];
}
```

## Version

Current development release: `1.1.0` (release candidate). Roadmap:

- `0.1.0` MVP: chainable API + China-localized rules + object validation
- `0.2.0`: array validation, async validation, deep nesting, ArkUI form binding `FormValidator`
- `0.3.0`: cross-field `.refine()`, conditional/optional `.optional()`/`.requiredWhen()`, new types `v.boolean()`/`v.enumOf()`/`v.date()`, more China rules (landline/VIN/IPv4/Chinese name/QQ/WeChat/URL)
- `0.4.0`: generic schemas, async whole-form validation, strict ISO dates, VIN checksums, correctness fixes, and release security
- `0.5.0`: error codes, localization, labels, literal/union, nullable/default/transform, and typed parsing
- `0.6.0`: ArkUI debounce, async race protection, validation triggers, submitting/touched/dirty state, and field dependencies
- `0.7.0`: independently importable China rules, a lite entry, and sync/async rule plugins
- `0.8.0`: schema metadata, structural serialization, JSON Schema conversion, and explicit unsupported-rule policies
- `1.0.0`: record/tuple/discriminated unions, object composition and unknown-key modes, safe coercion, versioned descriptors, reference safety, and release quality gates
- `1.1.0`: recursive/intersection/conditional schemas, context, codecs, structured errors, batch/cancellation, document restoration, JSON Schema import, and 18 modular rules

## Development and verification

```bash
./scripts/verify.sh
```

This installs dependencies, runs local Hypium tests, enforces coverage thresholds, builds a release HAR, and checks publishing credentials, release metadata, the public API contract, and a 128 KiB package-size budget.
Current baseline: 232/232 tests passing; 91.18% line, 81.01% function, and 81.60% branch coverage. New tests cover recursive/intersection/conditional schemas, codecs, context, error tools, batch/cancellation, document restoration, JSON Schema import, standard-format corpora, deep recursion, and round-trip stability; all 1.0 and earlier regressions remain green. Release thresholds are 90% / 80% / 80%; reports are generated under `validator/.test/default/outputs/test/reports/`.

See the full [CHANGELOG](./CHANGELOG.md).
For upgrades from 0.x, see [Migrating to 1.0](./MIGRATION-1.0.md).

## License

MIT
