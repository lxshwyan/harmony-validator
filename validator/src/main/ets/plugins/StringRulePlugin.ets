import { MessageCatalog, RuleIssue, ValidatorI18n, issue } from '../core/i18n';

/** 可复用的字符串规则插件。 */
export interface StringRulePlugin {
  /** 注册名；同名插件后注册者覆盖前者。 */
  name: string;
  /** 稳定、机器可读的错误码。 */
  code: string;
  /** 默认中文错误消息。 */
  message: string;
  /** 可选多语言消息，key 为 locale。 */
  messages?: Record<string, string>;
  /** 为 true 时 StringSchema 会执行 validateAsync。 */
  hasAsync?: boolean;
  /** 返回 true 表示通过；异常会被安全转换为校验失败。 */
  validate(value: string): boolean;
  /** 可选异步规则；仅在 validateAsync/parseAsync 中执行。 */
  validateAsync?(value: string): Promise<boolean>;
}

/** 内置规则使用的轻量插件实现，也可供业务规则直接复用。 */
export class BasicStringRulePlugin implements StringRulePlugin {
  name: string;
  code: string;
  message: string;
  messages?: Record<string, string>;
  hasAsync: boolean = false;
  private predicate: (value: string) => boolean;
  private asyncPredicate?: (value: string) => Promise<boolean>;

  constructor(name: string, code: string, message: string, predicate: (value: string) => boolean,
    messages?: Record<string, string>, asyncPredicate?: (value: string) => Promise<boolean>) {
    this.name = name;
    this.code = code;
    this.message = message;
    this.predicate = predicate;
    this.messages = messages;
    this.asyncPredicate = asyncPredicate;
    this.hasAsync = asyncPredicate !== undefined;
  }

  validate(value: string): boolean {
    return this.predicate(value);
  }

  async validateAsync(value: string): Promise<boolean> {
    if (this.asyncPredicate === undefined) {
      return true;
    }
    return this.asyncPredicate(value);
  }
}

const STRING_RULES: Map<string, StringRulePlugin> = new Map<string, StringRulePlugin>();

function installMessages(plugin: StringRulePlugin): void {
  const zh: MessageCatalog = {};
  zh[plugin.code] = plugin.message;
  ValidatorI18n.addLocale('zh-CN', zh);
  if (plugin.messages === undefined) {
    return;
  }
  const locales = Object.keys(plugin.messages);
  for (const locale of locales) {
    const catalog: MessageCatalog = {};
    catalog[plugin.code] = plugin.messages[locale];
    ValidatorI18n.addLocale(locale, catalog);
  }
}

/** 在 Schema 绑定插件时安装一次语言词条，避免每次输入重复合并语言包。 */
export function prepareStringRule(plugin: StringRulePlugin): void {
  installMessages(plugin);
}

/** 注册一个命名插件；同名注册会替换旧插件，便于业务覆盖。 */
export function registerStringRule(plugin: StringRulePlugin): void {
  installMessages(plugin);
  STRING_RULES.set(plugin.name, plugin);
}

/** 删除命名插件，主要用于插件卸载和测试隔离。 */
export function unregisterStringRule(name: string): boolean {
  return STRING_RULES.delete(name);
}

/** 查询命名插件。 */
export function getStringRule(name: string): StringRulePlugin | undefined {
  return STRING_RULES.get(name);
}

/** 把插件应用为 RuleIssue；异常与 false 都安全转换为同一个错误。 */
export function applyStringRule(plugin: StringRulePlugin, value: string, message?: string): RuleIssue | null {
  try {
    return plugin.validate(value) ? null : issue(plugin.code, message);
  } catch (_error) {
    return issue(plugin.code, message);
  }
}

/** 执行插件的可选异步部分；异常安全转换为同一错误。 */
export async function applyStringRuleAsync(plugin: StringRulePlugin, value: string,
  message?: string): Promise<RuleIssue | null> {
  if (plugin.validateAsync === undefined) {
    return null;
  }
  try {
    return (await plugin.validateAsync(value)) ? null : issue(plugin.code, message);
  } catch (_error) {
    return issue(plugin.code, message);
  }
}
