import type { StandardSchemaV1 } from '@standard-schema/spec';
import { toStandardSchema, type HmkitSchema } from './standard-schema.mjs';

declare const numberSchema: HmkitSchema<number>;
const standard: StandardSchemaV1<unknown, number> = toStandardSchema(numberSchema);
const output: StandardSchemaV1.InferOutput<typeof standard> = 3;
// @ts-expect-error The bridge must preserve the declared output type.
const invalid: StandardSchemaV1.InferOutput<typeof standard> = 'three';
void output; void invalid;
