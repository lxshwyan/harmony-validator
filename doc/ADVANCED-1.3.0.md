# 1.3.0：有边界的校验执行

本次在 1.2.0 基础上增量扩展。新模块使用按需入口，不添加主入口导出。OHPM 可用性以平台审核结果为准。

## 字段取消与超时

```typescript
import { FormValidator } from '@hmkit/validator/form';
import { liteV } from '@hmkit/validator/lite';
import { ValidationOptions } from '@hmkit/validator/execution';

const name = liteV.string().customAsync((value: string, options?: ValidationOptions): Promise<boolean> => {
  return new Promise<boolean>((resolve): void => {
    let unsubscribe: (() => void) | undefined;
    const timer = setTimeout((): void => { unsubscribe?.(); resolve(value !== 'taken'); }, 30);
    unsubscribe = options?.cancellation?.onCancel((): void => { clearTimeout(timer); resolve(false); });
  });
}, '名称已被占用');

const form = new FormValidator({ 'name': name }, {
  timeoutMs: 3000,
  fields: { 'name': { timeoutMs: 1000 } }
});
```

字段配置覆盖全局超时；不配置则没有截止时间。配置必须是有限正数，否则异步调用抛出 RangeError。

新校验或 change 事件会取消该字段旧任务，即使 change 不在触发策略中，也会让旧任务失效。reset/dispose 取消待执行防抖和在途校验。旧事件不再派发过期依赖数据，旧提交的 finally 不会清除新提交的 busy 状态。整表校验抛出异常时会取消同一批次剩余任务，但不取消后续新校验。

dispose 后显式字段校验不再执行；整表校验/提交返回 `$form` 取消错误。reset 可以重新启用控制器。提交在校验阶段被取消或取代时不调用业务 handler；**已经进入 handler 的业务提交不会被撤回或强制取消**。

底层规则必须主动响应 onCancel 才能释放网络资源。不响应取消的 Promise 会被调用方停止等待，但底层工作仍可能继续。自定义规则成功/失败结束时应退订自己的监听器。示例使用定时器，不是网络适配实现。

## 输入保护：显式启用，不改变旧调用

```typescript
import { liteV } from '@hmkit/validator/lite';
import { guarded, inspectInput } from '@hmkit/validator/safety';

const schema = guarded(liteV.array(liteV.number()), { maxDepth: 8, maxNodes: 1000 });
schema.parse([1, 2, 3]);
inspectInput([1, 2, 3], { maxDepth: 1, maxNodes: 4 });
```

- 根深度为 0；默认 maxDepth=64、maxNodes=10000。
- 节点包括根和每次访问的属性值。共享子对象在每条访问路径计数，但不视为循环；祖先回指产生 `input_cycle`。
- 超限分别返回 `input_depth`、`input_nodes`，错误包含发现问题的点分路径；返回首个保护错误。
- 用迭代遍历避免预检查自身递归溢出；guarded 在 validate/validateAsync/parse/parseAsync 前检查原始输入，再委托原 Schema。
- 配置在创建 wrapper 时复制并检查。maxDepth 必须为非负整数、maxNodes 为正整数。

边界：这是针对普通数据的预检，不是执行沙箱。只遍历自身可枚举属性；不限制字符串字节数、正则耗时、Schema 递归次数、transform 产生的结果或自定义回调；属性 getter 的副作用/异常不被吞掉。Object.keys 仍需枚举当前对象。需要配合接口请求体大小限制、可信 Schema 和合适的业务超时。普通 schema.validate 不会自动开启保护。

## 数组业务去重

```typescript
import { liteV } from '@hmkit/validator/lite';
import { uniqueBy } from '@hmkit/validator/collections';

const rows = uniqueBy(
  liteV.array(liteV.object<Record<string, Object>>({ 'sku': liteV.string().required() })),
  (row: Record<string, Object>): string => row['sku'] as string,
  { path: 'sku', message: '商品编号重复' }
);
const data: Record<string, Object>[] = [{ 'sku': 'a' }, { 'sku': 'b' }, { 'sku': 'a' }];
rows.validate(data); // unique_by，path 为 2.sku
```

四条执行路径都先调用内部解析，再检查解析结果，所以 transform 的标准化结果参与去重。基础解析失败不会调用 selector；校验阶段也会运行 transform，区别于部分原始 Schema 的 validate。selector 接收解析后的元素，返回 string/number/boolean/null/undefined，异常原样传播。缺失值不会被跳过，同样的 undefined 会重复；必填要求由元素 Schema 表达。Map 键语义区分 `1` 和 `'1'`，视 `0` 和 `-0` 相同。第一条保留，后续重复项各返回一条错误。先 guarded 再使用大数组约束可以限制输入规模。

guarded/uniqueBy 属于运行时包装，其 descriptor 明确标记不可表达；不承诺回调、输入限额或去重 selector 能往返序列化/转换到 JSON Schema。

## JSON Schema 新增关键词

`fromJSONSchema` 的导入子集增加：

- 数值：`multipleOf`、数值型 `exclusiveMinimum` / `exclusiveMaximum`。
- 数组：结构比较的 `uniqueItems`；对象键插入顺序不影响相等，重复位置带数组下标。
- 包含：`contains`、`minContains` / `maxContains`；默认至少匹配 1 项，最小值可为 0，无 contains 时忽略数量约束。
- 条件：`if` / `then` / `else`；仅执行选中分支，缺失分支视为通过，没有 if 时忽略 then/else；仍与同级约束相交。

```typescript
import { fromJSONSchema } from '@hmkit/validator/interop';
const schema = fromJSONSchema(JSON.parse(
  '{"type":"number","multipleOf":0.01,"exclusiveMinimum":0,"exclusiveMaximum":5}'
) as Record<string, Object>, { strict: true });
schema.validate(4.02);  // 通过
schema.validate(4.021); // multiple_of
```

数值检查基于 Number 的规范十进制字符串做整除计算，不使用 epsilon 容差。`0.3` 可通过 multipleOf=0.1，而 `0.1 + 0.2` 对应 0.30000000000000004，不通过。JSON.parse 之前/期间丢失的精度无法恢复，不是任意精度金额库。非法 multipleOf（非有限正数）即使宽松导入也会抛错，避免无效算术。

数组结构去重最坏为二次复杂度，适用于有限业务数组，不承诺大规模去重性能。新关键词按相应实例类型生效，不隐式要求 type。strict 会检查新增参数及其嵌套 Schema；它仍是能力诊断，不是完整元 Schema 验证，也不表示完整 Draft 2020-12 合规。结构型 const/enum 等先前不支持的能力仍保持原边界。

标准语义参考：[数组](https://json-schema.org/understanding-json-schema/reference/array)、[条件](https://json-schema.org/understanding-json-schema/reference/conditionals)、[数值](https://json-schema.org/understanding-json-schema/reference/numeric)。

## 验证

本地用例覆盖字段竞态/超时/异常/重置/销毁、重复取消、深层与循环输入、去重路径及转换、数值随机样本、JSON 组合与严格诊断。主/按需入口消费示例通过打包 HAR 使用两个新入口。具体测试数量、覆盖率、包体和设备状态以 `VALIDATION-1.3.0.md` 为准，不复用 1.2.0 的设备验收结论。
