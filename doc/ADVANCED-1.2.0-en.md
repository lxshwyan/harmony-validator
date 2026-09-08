# 1.2.0 advanced usage and acceptance

The candidate remains API-compatible. New functionality is not a claim of complete JSON Schema compliance.

## Recursive updates

Import `LazySchema` and `DiscriminatedUnionSchema` from `@hmkit/validator/composition`, and `liteV` / `AnySchema` from `@hmkit/validator/lite`. Call `deepPartial()` to build a separate update model. Lazy factories remain deferred; a per-conversion cache preserves recursive edges, including mutual recursion. Discriminated unions still reject absent or unknown tags before validating the selected partial branch.

Missing fields are not equivalent to null. Existing constraints and refine/transform callbacks remain active. Cyclic input objects are not supported. A partial model does not merge updates into stored data; validate the merged object with the complete model. Third-party deep-partial extensions should forward the optional `DeepPartialContext` to `deepPartialSchema(child, context)` and register deferred recursive placeholders first. Unsupported custom wrappers remain unchanged.

## Strict JSON Schema import

```ts
import { fromJSONSchema, inspectJSONSchema } from '@hmkit/validator/interop';
const source = JSON.parse('{"type":"number","multipleOf":2}') as Record<string, Object>;
const diagnostics = inspectJSONSchema(source); // #/multipleOf: unsupported
// fromJSONSchema(source, { strict: true }); // throws JSONSchemaImportError
```

Permissive import remains the default. `onDiagnostic` reports issues without enabling strict rejection. Strict import rejects diagnostics before conversion; the error contains `diagnostics` with escaped JSON Pointer paths. Boolean schemas are supported.

This is capability preflight, not a complete meta-schema validator. It reports unsupported keywords/formats, structured const/enum values, array-valued type, unsupported additionalProperties combinations, missing references, and reference cycles that do not descend into a property/item. Annotations do not fill defaults or resolve remote identifiers. Register format plugins before importing. Full Draft 2020-12 conformance and lossless export are not guaranteed.

## Cooperative remote cancellation

String/Number `customAsync` callbacks now receive optional per-call `ValidationOptions` as their second argument. Existing one-argument callbacks remain compatible. Subscribe through `options?.cancellation?.onCancel(cleanup)` and unsubscribe when your request finishes. Real request adapters must abort their own resource; a token cannot forcibly stop arbitrary network activity.

Each `validateValueAsync` creates an isolated child token. Caller cancellation returns `cancelled`; a timeout returns `timeout` and notifies the child without cancelling the shared parent. Repeated cancellation is harmless, late subscribers are notified immediately, and one throwing cleanup callback does not block other listeners. The execution helper removes its timers and subscriptions. Third-party exceptions still propagate and notify the child for cleanup.

```ts
import { liteV } from '@hmkit/validator/lite';
import { ValidationOptions, ValidationCancellationToken, validateValueAsync } from '@hmkit/validator/execution';
function remoteCheck(value: string, options?: ValidationOptions): Promise<boolean> {
  return new Promise<boolean>((resolve): void => {
    let unsubscribe: (() => void) | undefined;
    const timer = setTimeout((): void => { unsubscribe?.(); resolve(value !== 'taken'); }, 30);
    unsubscribe = options?.cancellation?.onCancel((): void => { clearTimeout(timer); resolve(false); });
  });
}
const token = new ValidationCancellationToken();
const task = validateValueAsync(liteV.string().customAsync(remoteCheck, 'Already registered'),
  'alice', { cancellation: token, timeoutMs: 3000 });
token.cancel();
```

This example simulates a request with a timer, not a live network service. Direct `parseAsync` can forward a token to custom rules; deadline/cancellation racing is provided by `validateValueAsync`.

## Dynamic forms and compiled examples

Import `FormValidator` / `FormTrigger` from `@hmkit/validator/form`; combine `WhenSchema` with field dependencies to switch required fields for personal/business accounts. Dispose the previous controller when replacing a dynamic shape, and call `dispose()` when the page leaves. Form disposal does not automatically abort arbitrary requests: the page owns its request tokens.

`scripts/consumer-scenarios.ets` contains the compiled recursive, discriminated, strict-import, mock-remote, and dynamic-form examples. The main/lite consumer pages provide acceptance/cancel buttons and reject overlapping acceptance runs. Their page-exit hook cancels the current request token.

## Device acceptance

Run `./scripts/verify.sh` first. Configure valid device signing for `external-consumer` in DevEco without committing credentials. Install and run both consumer variants, confirm `PASS 1.2 consumer`, then exercise repeated runs, cancellation, and leaving/reopening the page. A real adapter also requires weak-network/offline/timeout and rapid-input testing to ensure stale results cannot replace newer UI state and request resources are actually released. Build success and deterministic request mocks do not constitute real-device/network verification.
