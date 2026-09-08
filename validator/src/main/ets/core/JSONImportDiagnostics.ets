import { getStringRule } from '../plugins/StringRulePlugin';

export class JSONSchemaDiagnostic {
  path: string;
  keyword: string;
  message: string;
  constructor(path: string, keyword: string, message: string) {
    this.path = path; this.keyword = keyword; this.message = message;
  }
}

export interface JSONSchemaImportOptions {
  /** Reject diagnostics before creating a schema. Default false for compatibility. */
  strict?: boolean;
  onDiagnostic?: (diagnostic: JSONSchemaDiagnostic) => void;
}

export class JSONSchemaImportError extends Error {
  diagnostics: JSONSchemaDiagnostic[];
  constructor(diagnostics: JSONSchemaDiagnostic[]) {
    super(`JSON Schema import rejected: ${diagnostics.map((item: JSONSchemaDiagnostic): string =>
      `${item.path}: ${item.message}`).join('; ')}`);
    this.diagnostics = diagnostics;
  }
}

function pointer(value: string): string { return value.replace(/~/g, '~0').replace(/\//g, '~1'); }
function record(value: Object | null | undefined): boolean {
  return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value);
}
function scalar(value: Object | null): boolean { return value === null || typeof value !== 'object'; }

/** Capability diagnostics, not a complete JSON Schema meta-schema validator. */
export function inspectJSONSchema(source: Record<string, Object> | boolean): JSONSchemaDiagnostic[] {
  const diagnostics: JSONSchemaDiagnostic[] = [];
  const active: Object[] = [];
  const root = source as Record<string, Object>;
  const supported = ['$schema', '$id', '$defs', '$ref', '$comment', 'title', 'description', 'default',
    'examples', 'deprecated', 'readOnly', 'writeOnly', 'type', 'const', 'enum', 'allOf', 'anyOf', 'oneOf',
    'minLength', 'maxLength', 'pattern', 'format', 'minimum', 'maximum', 'items', 'minItems', 'maxItems',
    'properties', 'required', 'additionalProperties'];
  const add = (path: string, key: string, message: string): void => {
    diagnostics.push(new JSONSchemaDiagnostic(`${path}/${pointer(key)}`, key, message));
  };
  // References/combinators validate the same input; unlike properties/items they must make progress.
  const loops = (value: Object, chain: Object[]): boolean => {
    if (!record(value)) return false;
    if (chain.indexOf(value) !== -1) return true;
    const next = chain.concat([value]);
    const node = value as Record<string, Object>;
    const reference = node['$ref'];
    if (typeof reference === 'string') {
      if (reference === '#' && loops(root, next)) return true;
      if (reference.startsWith('#/$defs/')) {
        const definitions = root['$defs'] as Record<string, Object> | undefined;
        if (record(definitions)) {
          const target = (definitions as Record<string, Object>)[reference.substring(8)];
          if (record(target) && loops(target, next)) return true;
        }
      }
    }
    for (const keyword of ['allOf', 'anyOf', 'oneOf']) {
      const children = node[keyword];
      if (Array.isArray(children)) {
        for (const child of children as Object[]) if (loops(child, next)) return true;
      }
    }
    return false;
  };
  const visit = (value: Object, path: string): void => {
    if (typeof value === 'boolean') return;
    if (!record(value)) { add(path, '', 'Expected an object or boolean schema'); return; }
    if (active.indexOf(value) !== -1) { add(path, '', 'Use $ref instead of cyclic JavaScript objects'); return; }
    active.push(value);
    const node = value as Record<string, Object>;
    if (loops(value, [])) add(path, '$ref', 'Reference/composition cycle does not descend into properties or items');
    for (const key of Object.keys(node)) {
      const item = node[key];
      if (supported.indexOf(key) === -1) { add(path, key, 'Unsupported keyword; permissive import ignores it'); continue; }
      if (key === 'type' && ['string', 'number', 'integer', 'boolean', 'null', 'array', 'object'].indexOf(item as string) === -1) {
        add(path, key, 'Only a single supported type is accepted; use anyOf for alternatives');
      } else if (key === 'format') {
        const name = item === 'uri' ? 'url' : item as string;
        if (typeof item !== 'string' || getStringRule(name) === undefined) add(path, key, 'Format is not registered; import would ignore it');
      } else if (key === 'const' && !scalar(item)) {
        add(path, key, 'Structural object/array constants are not supported');
      } else if (key === 'enum') {
        if (!Array.isArray(item) || (item as Object[]).length === 0 ||
          (item as Object[]).some((entry: Object): boolean => !scalar(entry))) add(path, key, 'Expected a non-empty array of scalar values');
      } else if (['minLength', 'maxLength', 'minItems', 'maxItems'].indexOf(key) !== -1) {
        if (typeof item !== 'number' || !Number.isInteger(item) || item < 0) add(path, key, 'Expected a non-negative integer');
      } else if (key === 'minimum' || key === 'maximum') {
        if (typeof item !== 'number' || !Number.isFinite(item)) add(path, key, 'Expected a finite number');
      } else if (key === 'pattern') {
        if (typeof item !== 'string') add(path, key, 'Expected a regular expression string');
        else { try { new RegExp(item); } catch (_error) { add(path, key, 'Invalid regular expression'); } }
      } else if (key === 'allOf' || key === 'anyOf' || key === 'oneOf') {
        if (!Array.isArray(item) || (item as Object[]).length === 0) add(path, key, 'Expected a non-empty array of schemas');
        else (item as Object[]).forEach((child: Object, index: number): void => visit(child, `${path}/${key}/${index}`));
      } else if (key === 'properties' || key === '$defs') {
        if (!record(item)) add(path, key, 'Expected a schema map');
        else {
          const children = item as Record<string, Object>;
          for (const name of Object.keys(children)) visit(children[name], `${path}/${key}/${pointer(name)}`);
        }
      } else if (key === 'items') visit(item, `${path}/items`);
      else if (key === 'additionalProperties') {
        if (typeof item !== 'boolean') {
          visit(item, `${path}/additionalProperties`);
          if (record(node['properties']) && Object.keys(node['properties']).length > 0) {
            add(path, key, 'Schema-valued additionalProperties with named properties is not supported');
          }
        }
      } else if (key === 'required') {
        if (!Array.isArray(item) || (item as Object[]).some((entry: Object): boolean => typeof entry !== 'string')) {
          add(path, key, 'Expected an array of property names');
        } else {
          const properties = node['properties'] as Record<string, Object> | undefined;
          for (const name of item as string[]) {
            if (!record(properties) || Object.keys(properties as Object).indexOf(name) === -1) {
              add(path, key, `Required property must have a properties entry: ${name}`);
            }
          }
        }
      } else if (key === '$ref') {
        if (typeof item !== 'string' || (item !== '#' && !item.startsWith('#/$defs/'))) {
          add(path, key, 'Only root and local $defs references are supported');
        } else if (item !== '#') {
          const name = item.substring(8);
          const definitions = root['$defs'];
          if (name.indexOf('/') !== -1 || name.indexOf('~') !== -1 || !record(definitions) ||
            Object.keys(definitions).indexOf(name) === -1) add(path, key, 'Reference target not found (escaped/nested pointers are unsupported)');
        }
      }
    }
    active.pop();
  };
  visit(source, '#');
  return diagnostics;
}
