# 1.3.0: bounded validation

An incremental release. OHPM availability is subject to registry approval. The existing main export contract remains intact; new wrappers use optional subpaths.

## Form cancellation and deadlines

`FormValidatorOptions.timeoutMs` sets a per-field asynchronous deadline; `fields[name].timeoutMs` overrides it. Omission means no deadline. Non-finite/non-positive values reject with RangeError.

Each field owns a cancellation token. New validation, change events (even when change is not a validation trigger), reset and disposal invalidate old work. Pending callers settle even if the underlying promise never resolves. Stale events no longer dispatch outdated dependency values. Failed whole-form validation cancels remaining tasks from that batch, without cancelling newer work. Older submissions cannot clear the latest submission's busy state.

After disposal, explicit field validation is ignored; whole-form validation/submission returns a `$form` cancellation error. Reset reactivates the controller. Cancellation before business-handler entry prevents entry; an already running business handler is not rolled back or forcibly stopped.

Custom rules must observe `options.cancellation.onCancel` to actually release network resources, and unsubscribe when finished. The library cannot forcibly terminate arbitrary requests. The Chinese guide and packaged consumer fixture include a timer-based mock, not a real-network adapter.

## Optional input protection

```typescript
import { liteV } from '@hmkit/validator/lite';
import { guarded, inspectInput } from '@hmkit/validator/safety';

const schema = guarded(liteV.array(liteV.number()), { maxDepth: 8, maxNodes: 1000 });
schema.parse([1, 2, 3]);
inspectInput([1, 2, 3], { maxDepth: 1, maxNodes: 4 });
```

Root depth is zero. Defaults are depth 64 / 10000 visited values. Shared children are allowed and counted on each path; ancestor cycles fail with `input_cycle`. Limit failures use `input_depth` / `input_nodes` and the offending dot-separated path. Options are validated and copied when the wrapper is created. Depth must be a non-negative integer; nodes must be a positive integer.

Traversal is iterative and considers own enumerable properties. All four validate/parse paths inspect raw input before delegating. This is not a sandbox or CPU quota: string bytes, regular-expression work, schema recursion, transform output and callback work are not bounded. Getters can execute and throw, and Object.keys still enumerates the current object. Use trusted schemas and application-level payload limits. Existing direct schema calls do not automatically enable protection.

## Optional unique parsed keys

```typescript
import { liteV } from '@hmkit/validator/lite';
import { uniqueBy } from '@hmkit/validator/collections';

const rows = uniqueBy(
  liteV.array(liteV.object<Record<string, Object>>({ 'sku': liteV.string().required() })),
  (row: Record<string, Object>): string => row['sku'] as string,
  { path: 'sku', message: 'Duplicate SKU' }
);
const data: Record<string, Object>[] = [{ 'sku': 'a' }, { 'sku': 'b' }, { 'sku': 'a' }];
rows.validate(data); // code unique_by, path 2.sku
```

All four paths parse the inner schema first and inspect parsed values, including transforms. Unlike some original validate methods, this wrapper runs transforms during validation. Invalid elements do not reach the selector. Selector errors propagate. Supported keys: string/number/boolean/null/undefined. Missing keys are not skipped. Map equality distinguishes 1 from '1', and equates 0 with -0. Later duplicates get indexed errors; the first occurrence does not. Use element rules for required keys and guarded for input bounds.

The wrappers' descriptors explicitly mark runtime constraints as unrepresentable. Selectors and input budgets do not round-trip through schema serialization or JSON Schema conversion.

## Extended JSON Schema import

- Numeric `multipleOf`, `exclusiveMinimum`, `exclusiveMaximum`.
- Structural `uniqueItems`, independent of object property insertion order.
- `contains`, `minContains`, `maxContains`: default minimum 1, zero allowed; count bounds ignored without contains.
- `if`/`then`/`else`: only the selected branch is applied; missing branches pass; then/else without if are ignored. Sibling constraints still apply.

```typescript
import { fromJSONSchema } from '@hmkit/validator/interop';
const schema = fromJSONSchema(JSON.parse(
  '{"type":"number","multipleOf":0.01,"exclusiveMinimum":0,"exclusiveMaximum":5}'
) as Record<string, Object>, { strict: true });
schema.validate(4.02); // passes
schema.validate(4.021); // multiple_of
```

Divisibility uses canonical Number decimal strings, not epsilon tolerance. 0.3 is a multiple of 0.1; 0.1+0.2 represents 0.30000000000000004 and is not. Precision lost during parsing cannot be recovered; this is not an arbitrary-precision money library. Invalid multipleOf divisors throw even during permissive import.

Structural uniqueness is quadratic in the worst case: use bounded business arrays. Keywords apply to their corresponding instance types without implicitly requiring type. Strict mode validates the new parameters and nested schemas but remains a capability check, not complete meta-schema or Draft 2020-12 certification. Previous unsupported features, including structural const/enum, remain unsupported.

References: [arrays](https://json-schema.org/understanding-json-schema/reference/array), [conditionals](https://json-schema.org/understanding-json-schema/reference/conditionals), [numbers](https://json-schema.org/understanding-json-schema/reference/numeric).

## Verification

Regression tests cover races, deadlines, failures, resets/disposal, repeated cancellation, deep/cyclic inputs, transformed key uniqueness, randomized numeric samples and strict JSON diagnostics. Packaged HAR consumer fixtures import both new subpaths. See `VALIDATION-1.3.0.md` for exact results and device limitations; earlier release emulator results do not certify this release.
