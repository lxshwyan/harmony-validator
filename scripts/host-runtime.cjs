'use strict';
// Test/tool runtime only: .ets transpilation is not an ArkTS compatibility test.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const deveco = process.env.DEVECO_ROOT || '/Applications/DevEco-Studio.app/Contents';
const ts = require(path.join(deveco, 'tools/hvigor/hvigor/node_modules/typescript'));
require.extensions['.ets'] = (mod, filename) => {
  const result = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    fileName: filename + '.ts', reportDiagnostics: true,
    compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021}
  });
  const errors = (result.diagnostics || []).filter(d => d.category === ts.DiagnosticCategory.Error);
  if (errors.length) throw new Error(ts.formatDiagnosticsWithColorAndContext(errors, {
    getCanonicalFileName: f => f, getCurrentDirectory: () => root, getNewLine: () => '\n'
  }));
  mod._compile(result.outputText, filename);
};
module.exports = {root, ts, load: name => require(path.join(root, name))};
