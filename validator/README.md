# @hmkit/validator

> 鸿蒙 ArkTS 声明式表单/数据校验库。链式 API，内置手机号、身份证、银行卡等**中国本地化规则**，开箱即用。

像写 `zod` / `yup` 一样写校验，但国内高频场景一个库全搞定。

## 特性

- 🔗 **链式声明式 API** —— `v.string().required().phone()`，读起来像说话
- 🇨🇳 **中国规则开箱即用** —— 手机号、身份证（含校验位）、银行卡（Luhn）、车牌（含新能源）、统一社会信用代码、邮编
- 📦 **零依赖**、纯 ArkTS 实现
- 🧩 **对象 / 数组校验** —— 整表校验，错误带字段路径（含数组下标，如 `items.0.name`）
- 🪆 **深层嵌套** —— 对象、数组任意层级互相嵌套
- ⏳ **异步校验** —— `validateAsync` / `customAsync`，支持远程查重（用户名、手机号是否已注册）
- 🔗 **跨字段校验** —— `.refine()`，如确认密码一致、结束日期晚于开始日期
- 🎚️ **条件/可选** —— `.optional()`、`.requiredWhen()`（某字段满足条件时才必填）
- 🧮 **多种类型** —— 字符串、数字、布尔、枚举、日期、数组、对象
- 📝 **ArkUI 表单联动** —— `FormValidator` 控制器，与 `TextInput` 等组件实时联动
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

### 数组校验

```typescript
import { v } from '@hmkit/validator';

// 逐元素校验 + 长度约束；错误路径带下标
v.array(v.string().phone()).validate(['13800138000', '123']);
// { valid: false, errors: [{ path: '1', message: '请输入正确的手机号' }] }

v.array(v.string()).min(1, '至少填一项').validate([]);
// { valid: false, errors: [{ path: '', message: '至少填一项' }] }
```

### 深层嵌套（对象 ↔ 数组任意层级）

```typescript
const orderSchema = v.object({
  'items': v.array(v.object({
    'name': v.string().required('请输入商品名'),
    'qty':  v.number().required().min(1, '数量至少为 1'),
  })).nonEmpty('至少一件商品'),
});

orderSchema.validate({ 'items': [{ 'name': '', 'qty': 0 }] });
// errors: [
//   { path: 'items.0.name', message: '请输入商品名' },
//   { path: 'items.0.qty',  message: '数量至少为 1' },
// ]
```

### 异步校验（远程查重）

```typescript
// customAsync 仅在 validateAsync 时执行；同步 validate 会忽略它
const checkUsername = async (name: string): Promise<boolean> => {
  // 调接口判断用户名是否可用，返回 true 表示通过
  return await api.isUsernameAvailable(name);
};

const schema = v.string().required().min(3).customAsync(checkUsername, '用户名已被占用');
const result = await schema.validateAsync('taken');
// { valid: false, errors: [{ path: '', message: '用户名已被占用' }] }
```

### ArkTS 泛型类型

```typescript
class RegisterModel {
  pwd: string = '';
  confirm: string = '';
}

const form = v.object<RegisterModel>({
  'pwd': v.string().required(),
  'confirm': v.string().required(),
}).refine((data: RegisterModel): boolean => data.pwd === data.confirm,
  '两次密码不一致', 'confirm');

const tags = v.array(v.string());          // ArraySchema<string>
const status = v.enumOf(['draft', 'done']); // EnumSchema<string>
```

ArkTS 不支持 TypeScript 的 conditional type、`infer` 和 mapped type，因此对象模型采用
`v.object<Model>()` 显式声明；基础类型、数组元素和枚举值由工厂自动保留泛型。

### ArkUI 表单联动（FormValidator）

```typescript
import { v, FormValidator } from '@hmkit/validator';

@Entry
@Component
struct RegisterForm {
  private validator: FormValidator = new FormValidator({
    'username': v.string().required('请输入用户名').min(3),
    'phone':    v.string().required().phone(),
    'age':      v.number().required().integer().min(18, '需年满 18 岁'),
  });

  @State username: string = '';
  @State errors: Record<string, string> = {};

  build() {
    Column() {
      TextInput({ placeholder: '用户名' })
        .onChange((val: string) => {
          this.username = val;
          // 输入时实时校验单字段；返回错误信息(或 null)
          const msg = this.validator.validateField('username', val);
          this.errors = msg === null ? {} as Record<string, string>
                                     : { 'username': msg } as Record<string, string>;
        })
      if (this.errors['username'] !== undefined) {
        Text(this.errors['username']).fontColor('#E64340')
      }

      Button('提交').onClick(() => {
        // 提交时整体校验，返回 字段->错误 的 map
        const errs = this.validator.validateAll({ 'username': this.username });
        this.errors = errs;
      })
    }
  }
}
```

包含远程规则的提交可使用 `await validator.validateAllAsync(values)`；多个顶层字段会并发校验。
只需要布尔结果时使用 `await validator.isValidAsync(values)`。

> 完整可运行示例见仓库 `entry` 模块的 `FormDemo.ets`。

### 跨字段校验 `.refine()`（确认密码 / 日期先后）

```typescript
const form = v.object({
  'pwd': v.string().required().min(6),
  'confirm': v.string().required(),
}).refine((o: Record<string, Object>): boolean => o['pwd'] === o['confirm'], '两次密码不一致', 'confirm');

form.validate({ 'pwd': 'abc123', 'confirm': 'abc999' });
// { valid: false, errors: [{ path: 'confirm', message: '两次密码不一致' }] }
```

### 条件必填 `.requiredWhen()` / 可选 `.optional()`

```typescript
// 企业(type=company)才必填税号
const schema = v.object({
  'type': v.string(),
  'taxId': v.string().requiredWhen('type',
    (t: Object | null | undefined): boolean => (t as string) === 'company', '企业必须填写税号'),
});
schema.validate({ 'type': 'person', 'taxId': '' }); // 通过（个人无需税号）

v.string().optional().min(5).validate(''); // 通过（可选字段留空跳过规则）
```

### 布尔 / 枚举 / 日期

```typescript
v.boolean().isTrue('请先同意协议').validate(false);     // 失败
v.enumOf(['male', 'female']).validate('unknown');       // 失败：取值必须是 male / female
v.date().min('2020-01-01').validate('2019-06-01');      // 失败：早于下限（接受 Date/时间戳/字符串）
v.date().strict().validate('2023-02-29');               // 失败：严格 ISO 日期不存在
v.date().strict().validate('2024-01-01T08:00:00+08:00'); // 通过：日期时间必须带时区
```

## API

### `v` 工厂

| 方法 | 说明 |
|---|---|
| `v.string()` | 创建字符串校验器 |
| `v.number()` | 创建数字校验器 |
| `v.boolean()` | 创建布尔校验器 |
| `v.enumOf(values, message?)` | 创建枚举校验器，值必须在 `values` 内 |
| `v.date()` | 创建日期校验器（接受 `Date`/时间戳/日期字符串） |
| `v.object(shape)` | 创建对象校验器，`shape` 为 `{ 字段: 校验器 }`，支持 `.refine()` 跨字段 |
| `v.array(element)` | 创建数组校验器，`element` 为元素校验器 |

### 通用方法（所有校验器共有）

下列方法 **string / number / boolean / enum / date / array / object 全部支持**，行为一致：

| 方法 | 说明 |
|---|---|
| `.required(msg?)` | 必填（空值报错） |
| `.optional()` | 显式可选，空值跳过所有规则直接通过 |
| `.requiredWhen(field, predicate, msg?)` | 条件必填：同级字段 `field` 满足 `predicate` 时才必填（在 `v.object()` 中生效） |
| `.validate(value)` | 同步校验，返回 `ValidateResult` |
| `.validateAsync(value)` | 异步校验，返回 `Promise<ValidateResult>` |

> `v.object().optional()` 表示该对象字段可为 `null`/`undefined`（用于可空的嵌套对象）。
> 下面各类型表格只列「该类型特有」的方法，通用方法不再重复。

### StringSchema

> 通用方法（`required`/`optional`/`requiredWhen`）见上方「通用方法」节。

| 方法 | 说明 |
|---|---|
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
| `.landline(msg?)` | 固定电话/座机 |
| `.vin(msg?)` | 车架号 VIN 格式（17 位） |
| `.vinChecksum(msg?)` | VIN 格式 + ISO 3779 第 9 位校验位 |
| `.ipv4(msg?)` | IPv4 地址 |
| `.chineseName(msg?)` | 中文姓名 |
| `.qq(msg?)` / `.wechat(msg?)` | QQ 号 / 微信号 |
| `.url(msg?)` | http(s) 网址 |
| `.customAsync(fn, msg)` | 自定义异步规则（`fn` 返回 `Promise<boolean>`），仅 `validateAsync` 时执行 |

### NumberSchema

| 方法 | 说明 |
|---|---|
| `.min(n, msg?)` / `.max(n, msg?)` | 数值范围（含端点） |
| `.integer(msg?)` | 必须为整数 |
| `.positive(msg?)` | 必须为正数 |
| `.custom(fn, msg)` | 自定义函数 |
| `.customAsync(fn, msg)` | 自定义异步规则，仅 `validateAsync` 时执行 |

### ArraySchema（`v.array(element)`）

> 空数组视为「已填」(不触发 required)，用 `min`/`nonEmpty` 约束长度。

| 方法 | 说明 |
|---|---|
| `.min(n, msg?)` / `.max(n, msg?)` | 元素个数范围 |
| `.nonEmpty(msg?)` | 不能为空数组 |

### BooleanSchema（`v.boolean()`）

> 注意 `false` 不算空值，不会触发 required。

| 方法 | 说明 |
|---|---|
| `.isTrue(msg?)` / `.isFalse(msg?)` | 必须为真 / 为假（如同意协议） |

### EnumSchema（`v.enumOf(values, msg?)`）

值必须 `===` `values` 中的某一项，否则报错。（仅特有行为，通用方法见上。）

### DateSchema（`v.date()`）

接受 `Date` 对象、毫秒时间戳或可解析的日期字符串。

| 方法 | 说明 |
|---|---|
| `.min(date, msg?)` / `.max(date, msg?)` | 不早于 / 不晚于（边界无法解析时自动忽略该规则） |
| `.strict(msg?)` | 字符串必须为真实 `YYYY-MM-DD` 或带时区的 ISO 日期时间；Date/时间戳仍可用 |

### ObjectSchema 特有（`v.object(shape)`）

| 方法 | 说明 |
|---|---|
| `.refine(fn, message, path?)` | 跨字段校验：`fn` 拿到整个对象返回 `false` 时报错；`path` 指定错误归属字段（默认对象级）。`fn` 内部应自行判空，即便抛异常也会被安全捕获 |
| `.optional()` | 对象字段可为 `null`/`undefined` 时跳过（可空嵌套对象） |

### 同步 / 异步校验

每个校验器都有两个入口：

| 方法 | 说明 |
|---|---|
| `.validate(value)` | 同步校验，返回 `ValidateResult` |
| `.validateAsync(value)` | 异步校验，返回 `Promise<ValidateResult>`，会同时跑同步规则与 `customAsync` 异步规则 |

### FormValidator（表单联动）

```typescript
new FormValidator(shape: Record<string, AnySchema>)
```

| 方法 | 说明 |
|---|---|
| `.validateField(name, value)` | 实时校验单字段，返回首条错误信息或 `null` |
| `.validateFieldAsync(name, value)` | 异步校验单字段，返回 `Promise<string \| null>` |
| `.validateAll(values)` | 整体校验，返回只含出错字段的 `Record<字段名, 错误信息>` |
| `.isValid(values)` | 整体是否通过，返回 `boolean` |
| `.validateAllAsync(values)` | 并发校验整表，返回 `Promise<Record<字段名, 错误信息>>` |
| `.isValidAsync(values)` | 异步判断整表是否通过，返回 `Promise<boolean>` |

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

当前版本 `0.4.0`。演进路线：

- `0.1.0` MVP：链式 API + 中国本地化规则 + 对象校验
- `0.2.0`：数组校验、异步校验、深层嵌套、ArkUI 表单联动 `FormValidator`
- `0.3.0`：跨字段校验 `.refine()`、条件/可选 `.optional()`/`.requiredWhen()`、新类型 `v.boolean()`/`v.enumOf()`/`v.date()`、新增中国规则（固话/VIN/IPv4/中文姓名/QQ/微信/URL）
- `0.4.0`：泛型 Schema、整表异步校验、严格 ISO 日期、VIN 校验位、正确性修复与发布安全基线

## 开发与验证

```bash
./scripts/verify.sh
```

该命令会安装依赖、运行 Hypium 本地测试、检查覆盖率门槛、构建 release HAR，并检查包内敏感发布信息和 release 元数据。
当前基线：74/74 测试通过；行覆盖率 93.11%、函数 84.15%、分支 88.24%。发布门槛分别为 90% / 80% / 80%，报告生成在 `validator/.test/default/outputs/test/reports/`。

完整变更见 [CHANGELOG](./CHANGELOG.md)。

## License

MIT
