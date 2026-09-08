/** Schema interchange entry; does not auto-register format plugins. */
export { JSONSchemaDiagnostic, JSONSchemaImportOptions, JSONSchemaImportError, inspectJSONSchema } from './src/main/ets/core/JSONImportDiagnostics';
export { SchemaRegistry, SchemaDescriptorFactory, schemaFromDescriptor, deserializeSchemaDocument, fromJSONSchema } from './src/main/ets/core/interop';
export { schemaToDescriptor, schemaToDocument, serializeSchema, serializeSchemaDocument, toJSONSchema } from './src/main/ets/core/schema';
export { SchemaDescriptor, SchemaDocument, SchemaMetadata, SchemaRuleDescriptor } from './src/main/ets/core/types';
