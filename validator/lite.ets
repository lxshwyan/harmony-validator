/** OHPM 轻量入口：不会自动注册全部中国规则。 */
export { liteV } from './src/main/ets/lite';
export { StringSchema } from './src/main/ets/schemas/StringSchema';
export {
  StringRulePlugin, BasicStringRulePlugin, registerStringRule, unregisterStringRule, getStringRule
} from './src/main/ets/plugins/StringRulePlugin';
export {
  AnySchema, ParsableSchema, ParseResult, SchemaDescriptor, SchemaMetadata,
  SchemaRuleDescriptor, ValidateError, ValidateResult
} from './src/main/ets/core/types';
export { schemaToDescriptor, serializeSchema, toJSONSchema } from './src/main/ets/core/schema';
export { ErrorCode, MessageCatalog, MessageParams, ValidatorI18n } from './src/main/ets/core/i18n';
