'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {createRequire} = require('node:module');
const assert = require('node:assert/strict');
assert.equal(process.argv[2], 'demo-prism');
assert.equal(process.argv.length, 3);
const root = path.resolve(__dirname, '../..');
const requireFunctions = createRequire(path.join(root, 'functions/package.json'));
const ts = requireFunctions('typescript');
const target = path.join(__dirname, '.runtime');
fs.mkdirSync(target, {recursive: true});
for (const name of ['firestore.rules', 'firestore.indexes.json']) {
  fs.copyFileSync(path.join(root, name), path.join(target, name));
}
fs.rmSync(path.join(target, 'lib'), {recursive: true, force: true});
fs.mkdirSync(path.join(target, 'lib'));
const compile = (name, source) => {
  const result = ts.transpileModule(source, {fileName: name + '.ts', reportDiagnostics: true,
    compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2017, esModuleInterop: true}});
  assert.equal((result.diagnostics ?? []).length, 0, `Transpile diagnostics: ${name}`);
  fs.writeFileSync(path.join(target, 'lib', name + '.js'), result.outputText);
};
for (const name of ['creatorStats', 'creatorStatsHistory', 'creatorStatsDaily', 'common', 'notificationCatalog']) {
  compile(name, fs.readFileSync(path.join(root, 'functions/src', name + '.ts'), 'utf8'));
}
// viewStats also imports economy and asset delivery. Extract its exact normalizer and constant
// with the TS parser rather than loading those unrelated modules or duplicating their behavior.
const source = fs.readFileSync(path.join(root, 'functions/src/viewStats.ts'), 'utf8');
const parsed = ts.createSourceFile('viewStats.ts', source, ts.ScriptTarget.Latest, true);
const selected = parsed.statements.filter(statement =>
  ts.isFunctionDeclaration(statement) && statement.name?.text === 'normalizeId' ||
  ts.isVariableStatement(statement) && statement.declarationList.declarations.some(d => d.name.getText(parsed) === 'MAX_ID_LEN'));
assert.equal(selected.length, 2, 'Normalizer source structure changed. Review bundle preparation.');
compile('viewStats', 'import {HttpsError} from "firebase-functions/v2/https";\n' + selected.map(s => s.getText(parsed)).join('\n'));
// tipCreator imports most of the backend, so the whole current source is transpiled for it, tests and scripts left out.
const fnlib = path.join(target, 'fnlib');
fs.rmSync(fnlib, {recursive: true, force: true});
const transpileTree = (dir, out) => {
  for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
    if (entry.name === '__tests__' || entry.name === 'scripts') continue;
    const from = path.join(dir, entry.name);
    if (entry.isDirectory()) transpileTree(from, path.join(out, entry.name));
    else if (entry.name.endsWith('.ts')) {
      const result = ts.transpileModule(fs.readFileSync(from, 'utf8'), {fileName: entry.name, compilerOptions:
        {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2017, esModuleInterop: true}});
      fs.mkdirSync(out, {recursive: true});
      fs.writeFileSync(path.join(out, entry.name.replace(/\.ts$/, '.js')), result.outputText);
    }
  }
};
transpileTree(path.join(root, 'functions/src'), fnlib);
fs.copyFileSync(path.join(__dirname, 'bundle/index.cjs'), path.join(target, 'index.cjs'));
fs.writeFileSync(path.join(target, 'package.json'), JSON.stringify({name: 'prism-local-stats', private: true,
  main: 'index.cjs', engines: {node: '24'}, dependencies: {
    'firebase-admin': requireFunctions('./package.json').dependencies['firebase-admin'],
    'firebase-functions': requireFunctions('./package.json').dependencies['firebase-functions'],
  }}));
const modules = path.join(target, 'node_modules');
if (!fs.existsSync(modules)) fs.symlinkSync(path.join(root, 'functions/node_modules'), modules, 'dir');
console.log('Prepared six local modules from current backend source. No broad build or dependency installation.');
