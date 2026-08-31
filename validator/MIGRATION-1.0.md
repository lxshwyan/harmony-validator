# Migrating to 1.0

`1.0.0` keeps all documented 0.8 APIs. Existing `validate` / `validateAsync`, `parse` / `parseAsync`,
FormValidator, China rules, lite entry, rule subpaths, metadata, `serializeSchema()` and `toJSONSchema()` calls remain valid.

## Compatibility defaults

- `v.object()` still uses `passthrough`: unknown keys are accepted and retained by `parse()`.
- Use `.strict()` to reject unknown keys, or `.strip()` to accept but remove them from parsed output.
- `serializeSchema()` keeps the unversioned 0.8 descriptor shape. New persisted data should use
  `serializeSchemaDocument()`, whose envelope is `{ format: "hmkit-schema", version: "1.0", schema: ... }`.
- Runtime predicates, preprocessors, transforms and plugin functions are not serialized as executable code.

## New common schemas

```typescript
import { AnySchema, v } from '@hmkit/validator';

const dictionary = v.record(v.string());
const coordinates = v.tuple([v.number(), v.number()]);

const variants: Record<string, AnySchema<Record<string, Object>>> = {};
variants['text'] = v.object({ 'type': v.literal('text'), 'value': v.string().required() });
variants['count'] = v.object({ 'type': v.literal('count'), 'value': v.number().required() });
const event = v.discriminatedUnion('type', variants);
```

ArkTS does not provide TypeScript-style mapped tuple inference here, so `v.tuple()` deliberately exposes
`Array<Object>` output. Use an explicit business model after parsing when stronger tuple typing is required.

## Object composition

```typescript
const base = v.object({
  'name': v.string().required(),
  'age': v.number().required(),
  'secret': v.string(),
});

const update = base.partial(['age']).omit(['secret']).strip();
```

`partial()`, `pick()` and `omit()` return a new ObjectSchema and do not mutate `base`. They keep the current
unknown-key mode. Chain `.strip()` when `pick()` / `omit()` should also project parsed output.

## Safe coercion

- `coerceString()` accepts strings, numbers and booleans; it rejects objects and arrays.
- `coerceNumber()` accepts numbers and non-empty finite numeric strings; it rejects booleans and empty strings.
- `coerceBoolean()` accepts booleans, `"true"` / `"false"`, and `1` / `0`.
- `coerceDate()` accepts valid Date, timestamp and date-string inputs and returns a new Date.
- `preprocess()` catches callback exceptions and returns a `preprocess` error.

Use `parse()` / `parseAsync()` to obtain converted output. `validate()` only reports validity.

## Descriptor and JSON Schema changes

JSON Schema now maps records, tuples, discriminated unions and strict objects. Nested schemas with a metadata
`id` are deduplicated through stable `$defs/$ref`. A recursive descriptor must be named with `metadata.id`;
unnamed cycles fail immediately with an explicit error. Raw descriptor serialization rejects cycles and points
callers to `toJSONSchema()` for reference-based output.
