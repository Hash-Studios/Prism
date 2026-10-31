'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {requireFunctions} = require('./local.cjs');

async function main() {
  const ts = requireFunctions('typescript');
  const profiles = ts.createSourceFile('profiles.ts',
    fs.readFileSync(path.resolve(__dirname, '../../functions/src/profiles.ts'), 'utf8'), ts.ScriptTarget.Latest, true);
  const names = new Set(['PROFILE_FIELDS', 'PROFILE_LINK_KEYS', 'nonEmptyStrings', 'cleanCount', 'projectedProfile']);
  const declarations = profiles.statements.filter(s =>
    ts.isFunctionDeclaration(s) && names.has(s.name?.text) ||
    ts.isVariableStatement(s) && s.declarationList.declarations.some(d => names.has(d.name.getText(profiles))));
  assert.equal(declarations.length, names.size, 'Public profile projection changed. Review the fixture contract.');
  const compiled = ts.transpileModule(declarations.map(s => s.getText(profiles)).join('\n'), {
    compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2017},
  });
  const exports = {};
  vm.runInNewContext(compiled.outputText, {exports});

  const documents = new Map();
  const db = {doc: documentPath => ({
    path: documentPath,
    set: async data => documents.set(documentPath, data),
    create: async data => documents.set(documentPath, data),
    get: async () => ({ref: {path: documentPath}, exists: documents.has(documentPath),
      data: () => documents.get(documentPath)}),
  })};
  const context = {
    process: {env: {QA_IMAGE_HOST: '127.0.0.1'}, exitCode: 0},
    console: {log() {}, error: error => { throw error; }},
    require: name => {
      assert.equal(name, './local.cjs');
      return {connect: () => ({
        admin: {auth: () => ({createUser: async () => {}}), app: () => ({delete: async () => {}})}, db,
        history: {weekWindows: () => [{week: '2026-W43', start: 1792368000000}], METRICS: ['views'],
          incarnation: () => 'fixture-incarnation', historyRef: wall => db.doc(`history/${wall.ref.path}`)},
        backend: {deliverCreatorWeek: async () => {}},
      })};
    },
  };
  await vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'seed.cjs'), 'utf8'), context, {filename: 'seed.cjs'});
  assert.equal(context.process.exitCode, 0);
  assert.deepEqual([...documents.keys()].filter(p => p.startsWith('profiles/')).sort(),
    ['profiles/qa-stats-creator', 'profiles/qa-stats-empty', 'profiles/qa-stats-other']);
  for (const account of ['creator', 'other', 'empty']) {
    const source = documents.get(`usersv2/qa-stats-${account}`);
    const profile = JSON.parse(JSON.stringify(documents.get(`profiles/qa-stats-${account}`)));
    assert.deepEqual(profile, JSON.parse(JSON.stringify(exports.projectedProfile(source, 0, 0))));
    assert.equal(profile.username, `qa${account}`);
    assert.equal(profile.profilePhoto, 'http://127.0.0.1:9198/avatar.png');
  }
  console.log('PASS: seed writes all three public profiles matching the real projectedProfile, without Firebase.');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
