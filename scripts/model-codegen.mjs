import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const identifier = /^[A-Za-z_][A-Za-z0-9_]*$/;
const reserved = new Set(['constructor', '__proto__', 'prototype', 'class', 'interface', 'default', 'new', 'export', 'import', 'extends', 'implements', 'static', 'private', 'public', 'protected', 'readonly', 'function', 'return', 'var', 'let', 'const', 'enum', 'type', 'namespace', 'string', 'number', 'boolean', 'Object', 'Array', 'Date', 'liteV']);
for(const keyword of ['if','else','for','while','do','switch','case','break','continue','try','catch','finally','throw','null','true','false','this','super','delete','in','instanceof','void','typeof','await','async','yield','with','as','is','abstract','declare','any','unknown','never','undefined','symbol','keyof','infer']) reserved.add(keyword);
function fail(at, message) { throw new Error(`${at}: ${message}`); }
function name(value, at) {
  if (typeof value !== 'string' || !identifier.test(value) || reserved.has(value)) fail(at, 'invalid or reserved ArkTS identifier');
  return value;
}

/** Single definition -> input/output interfaces and fresh schema constructor. */
export function generateModel(definition) {
  if (!definition || definition.version !== 1) fail('#/version', 'expected model definition version 1');
  for (const key of Object.keys(definition)) if (!['version','name','schema'].includes(key)) fail(`#/${key}`, 'unsupported definition option');
  const model = name(definition.name, '#/name');
  const declarations = [];
  const usedNames = new Set();
  const define = (node, at, typeName, partial = false) => {
    if (!node || typeof node !== 'object' || Array.isArray(node)) fail(at, 'expected field definition');
    const allowed = new Set(['kind','required','nullable','default','min','max','integer','properties','items','partial','transform']);
    for (const key of Object.keys(node)) if (!allowed.has(key)) fail(`${at}/${key}`, 'unsupported option; no constraints may be silently dropped');
    for (const key of ['required','nullable','integer','partial']) if (node[key] !== undefined && typeof node[key] !== 'boolean') fail(`${at}/${key}`, 'expected boolean');
    const kinds = ['string','number','boolean','object','array'];
    if (!kinds.includes(node.kind)) fail(`${at}/kind`, 'unsupported kind');
    for (const key of ['min','max']) if (node[key] !== undefined && (!Number.isFinite(node[key]) || !['string','number','array'].includes(node.kind) || (node.kind !== 'number' && (!Number.isInteger(node[key]) || node[key] < 0)))) fail(`${at}/${key}`, 'invalid bound');
    if (node.min !== undefined && node.max !== undefined && node.min > node.max) fail(at, 'min exceeds max');
    if (node.integer !== undefined && node.kind !== 'number') fail(`${at}/integer`, 'only numbers support integer');
    if (node.properties !== undefined && node.kind !== 'object') fail(`${at}/properties`, 'only objects support properties');
    if (node.items !== undefined && node.kind !== 'array') fail(`${at}/items`, 'only arrays support items');
    if (node.partial !== undefined && node.kind !== 'object') fail(`${at}/partial`, 'only objects support partial');
    let input = node.kind, output = node.kind, expression;
    const ownPartial = partial || node.partial === true;
    if (node.kind === 'object') {
      if (!node.properties || typeof node.properties !== 'object' || Array.isArray(node.properties)) fail(`${at}/properties`, 'expected object');
      for (const suffix of ['Input','Output']) {
        if (usedNames.has(typeName + suffix)) fail(at, 'generated interface name collision');
        usedNames.add(typeName + suffix);
      }
      const fields = [];
      for (const [key, child] of Object.entries(node.properties)) {
        name(key, `${at}/properties/${key}`);
        const childName = typeName + key[0].toUpperCase() + key.slice(1);
        const item = define(child, `${at}/properties/${key}`, childName);
        fields.push({key, ...item});
      }
      for (const direction of ['Input','Output']) {
        const lines = fields.map(f => {
          const required = !ownPartial && (direction === 'Input' ? f.required && !f.hasDefault : f.required || f.hasDefault);
          return `  ${f.key}${required ? '' : '?'}: ${direction === 'Input' ? f.input : f.output};`;
        });
        declarations.push(`export interface ${typeName}${direction} {\n${lines.join('\n')}\n}`);
      }
      input = typeName + 'Input'; output = typeName + 'Output';
      expression = `liteV.object<${output}>({\n${fields.map(f=>`    '${f.key}': ${f.expression}`).join(',\n')}\n  }).strip()`;
      const optionalKeys=fields.filter(f=>!f.required&&!f.hasDefault).map(f=>f.key);
      if (ownPartial) expression += '.partial()';
      else if(optionalKeys.length) expression += `.partial(${JSON.stringify(optionalKeys)})`;
    } else if (node.kind === 'array') {
      if (node.items?.nullable) fail(`${at}/items/nullable`, 'nullable array elements require a handwritten schema in this generator');
      const item = define(node.items, `${at}/items`, typeName + 'Item');
      if (!item.required && !item.hasDefault) fail(`${at}/items/required`, 'array elements must be required or have a default');
      input = `Array<${item.input}>`; output = `Array<${item.output}>`;
      expression = `liteV.array(${item.expression})`;
    } else expression = `liteV.${node.kind}()`;
    // Optionality belongs to the containing object: supplied null must not pass
    // an optional non-null field merely because native scalars default optional.
    if (node.kind !== 'object') expression += '.required()';
    for (const key of ['min','max']) if (node[key] !== undefined) expression += `.${key}(${node[key]})`;
    if (node.integer) expression += '.integer()';
    if (node.nullable) {expression += '.nullable()'; input += ' | null'; output += ' | null';}
    const hasDefault = Object.hasOwn(node, 'default');
    if (hasDefault) {
      if (!['string','number','boolean'].includes(node.kind) || (node.default !== null && typeof node.default !== node.kind) || (node.default === null && !node.nullable)) fail(`${at}/default`, 'only a matching scalar or explicit nullable null is supported');
      if (typeof node.default === 'number' && !Number.isFinite(node.default)) fail(`${at}/default`, 'expected finite number');
      expression += `.default(${JSON.stringify(node.default)})`;
    }
    if (node.transform !== undefined) {
      if (node.kind !== 'string' || node.nullable || (!node.required && !hasDefault)) fail(`${at}/transform`, 'transform requires a non-null required/default string');
      const transforms = {trim: ['string','value.trim()'],lowercase:['string','value.toLowerCase()'],length:['number','value.length']};
      const selected = transforms[node.transform];
      if (!selected || !Object.hasOwn(transforms, node.transform)) fail(`${at}/transform`, 'unsupported transform; custom callbacks require a handwritten schema');
      output = selected[0];
      expression += `.transform((value: string): ${output} => ${selected[1]})`;
    }
    return {input, output, expression, required:node.required === true, hasDefault};
  };
  if (definition.schema?.kind !== 'object' || definition.schema.required !== true || definition.schema.nullable || definition.schema.partial) fail('#/schema', 'root must be a required non-null full object');
  const root = define(definition.schema, '#/schema', model);
  const full = declarations.slice();
  declarations.length = 0;
  // Generate an update model separately: absent fields are omitted, not defaults.
  const patch = define({...definition.schema, partial:true}, '#/schema', model + 'Patch');
  return `// Generated by scripts/model-codegen.mjs. Edit the source definition.\nimport { liteV, ParsableSchema } from '@hmkit/validator/lite';\n\n${[...full,...declarations].join('\n\n')}\n\nexport function create${model}Schema(): ParsableSchema<${root.output}> {\n  return ${root.expression};\n}\n\nexport function create${model}PatchSchema(): ParsableSchema<${patch.output}> {\n  return ${patch.expression};\n}\n`;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args=process.argv.slice(2);
    const [input, output, flag] = args;
    if (!input || !output || args.length>3 || (flag && flag !== '--check')) throw new Error('Usage: node scripts/model-codegen.mjs definition.json output.ets [--check]');
    const source = generateModel(JSON.parse(fs.readFileSync(input, 'utf8')));
    if (flag === '--check') {
      if (!fs.existsSync(output) || fs.readFileSync(output, 'utf8') !== source) throw new Error('Generated model is stale; regenerate it');
    } else { fs.mkdirSync(path.dirname(output), {recursive:true}); fs.writeFileSync(output,source); }
    console.log(flag === '--check' ? 'Model definition and generated source match.' : `Generated ${output}`);
  } catch(error) {console.error(error.message); process.exitCode=1;}
}
