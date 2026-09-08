# 1.2.0 高级用法与验收

所有示例面向 1.2.0 候选版本。版本保持兼容；功能丰富不等于完整实现 JSON Schema 标准。

## 递归与判别联合更新

```ts
import { liteV, AnySchema } from '@hmkit/validator/lite';
import { LazySchema, DiscriminatedUnionSchema } from '@hmkit/validator/composition';

const tree: LazySchema<Record<string, Object>> = new LazySchema<Record<string, Object>>(
  (): AnySchema<Record<string, Object>> => liteV.object({
    'name': liteV.string().required(), 'children': liteV.array(tree)
  }));
const leaf: Record<string, Object> = {};
const update: Record<string, Object> = { 'children': [leaf] };
tree.deepPartial().validate(update); // 通过；原 tree 仍要求 name

const account = new DiscriminatedUnionSchema<Record<string, Object>>('kind', {
  'person': liteV.object({ 'kind': liteV.literal('person'), 'name': liteV.string().required() })
}).deepPartial();
const patch: Record<string, Object> = { 'kind': 'person' };
account.validate(patch); // 通过，但缺少 kind 或未知 kind 都失败
```

每次 `deepPartial()` 创建独立转换上下文；Lazy 工厂保持延迟求值，同一次转换的递归边复用转换结果。不支持带循环引用的输入对象本身。字段可省略不等于字段值可以是 null，也不会重写业务 refine/transform 回调。更新模型不会把校验结果自动合并回完整业务对象；合并后仍应使用完整模型校验。

第三方可实现 `DeepPartialSchema<T>`；若内部包含子 Schema，接收可选 `DeepPartialContext` 并将其传给 `deepPartialSchema(child, context)`。递归实现必须先注册延迟占位。没有扩展能力的自定义 Schema 保持原样。

## 严格导入与诊断

```ts
import { fromJSONSchema, inspectJSONSchema } from '@hmkit/validator/interop';
const source = JSON.parse('{"type":"number","multipleOf":2}') as Record<string, Object>;
const diagnostics = inspectJSONSchema(source); // #/multipleOf：未支持
// fromJSONSchema(source, { strict: true }); // 抛出 JSONSchemaImportError
```

默认仍为宽松导入，保证兼容。`onDiagnostic` 可在宽松模式收集诊断；严格模式在转换前拒绝诊断项，错误对象带 `diagnostics`。路径按 JSON Pointer 转义。新增布尔 Schema：true 接受，false 拒绝。

严格检查是当前实现的能力预检，不是完整的标准元 Schema 校验器。未知关键词、未注册 format、结构型 const/enum、数组型 type、未支持的 additionalProperties 组合、缺失引用及不向子字段前进的引用循环会被报告。`$id`、标题、默认值等注解不触发默认填充或远程解析。格式规则仍取决于插件，导入时先注册所需插件；不提供完整 Draft 2020-12 合规或无损导出保证。

## 可取消的远程规则

```ts
import { liteV } from '@hmkit/validator/lite';
import { ValidationOptions, ValidationCancellationToken, validateValueAsync } from '@hmkit/validator/execution';

// 可执行的请求模拟；接入真实网络时，把 clearTimeout 换成适配器的停止请求操作。
function remoteCheck(value: string, options?: ValidationOptions): Promise<boolean> {
  return new Promise<boolean>((resolve): void => {
    let unsubscribe: (() => void) | undefined;
    const timer = setTimeout((): void => { unsubscribe?.(); resolve(value !== 'taken'); }, 30);
    unsubscribe = options?.cancellation?.onCancel((): void => {
      clearTimeout(timer);
      resolve(false);
    });
  });
}
const token = new ValidationCancellationToken();
const schema = liteV.string().customAsync(remoteCheck, '用户名已被占用');
const task = validateValueAsync(schema, 'alice', { cancellation: token, timeoutMs: 3000 });
token.cancel(); // 页面退出/新输入替代旧输入时调用；task 返回 cancelled
```

String/Number 的 customAsync 第二个参数可读取本次选项，旧单参数回调仍兼容。每个 `validateValueAsync` 使用独立子令牌，超时返回 `timeout` 并通知子令牌，不取消调用者共享令牌；父令牌取消则通知该次调用。订阅可退订，重复 cancel 无副作用，晚订阅立即通知，单个清理回调抛错不阻止其余清理。请求结束后应退订；库会清理自己的定时器及父子订阅。第三方异常仍抛出，并通知本次子令牌释放资源。

取消不是强制停止网络：适配器必须响应通知。直接 `schema.parseAsync()` 可以传入令牌供规则读取，但等待超时/取消竞争由 `validateValueAsync` 提供。`FormValidator.dispose()` 管理自身状态及防抖，不自动取消任意外部请求；页面需要管理并取消自己的令牌。

## 动态字段与页面生命周期

按需导入 `FormValidator` / `FormTrigger`（`@hmkit/validator/form`），用 `WhenSchema`（`@hmkit/validator/composition`）按兄弟字段控制必填，并通过 `fields.company.dependencies = ['mode']` 在模式变化后重新校验。页面退出时调用 `form.dispose()`；重建表单结构时销毁旧控制器再创建新控制器，不修改内部字段映射。

可编译的完整例子在 `scripts/consumer-scenarios.ets`：递归树、判别联合、严格导入、远程请求模拟及个人/企业表单切换。`scripts/consumer-main.ets` 与 `consumer-lite.ets` 是带验收/取消按钮的 ArkUI 页面，重复点击验收会被 busy 状态阻止；页面退出会取消当前令牌。

## 真机验收清单

1. 先运行 `./scripts/verify.sh`，确认全量测试、覆盖率、HAR 与两个独立消费 HAP 构建通过。
2. 在 DevEco 为 `external-consumer` 配置对应设备的开发签名。不要提交证书、私钥、签名口令或带敏感内容的配置。
3. 分别构建安装主入口和按需入口页面，确认出现 `PASS 1.2 consumer`。
4. 连续点击验收、运行中取消、运行中退出并重新进入，检查无崩溃、无卡死、无未处理 Promise 异常。
5. 手动输入/真实网络集成属于业务适配验收：模拟弱网、断网、超时、快速替换输入，确保旧结果不覆盖新状态且实际请求资源被释放。

本地模拟请求与编译成功不能替代真实网络/真机验收。签名未配置时，真机项必须保持待验收。
