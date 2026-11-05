#!/usr/bin/env node
import {execFileSync, spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {cpus, loadavg} from 'node:os';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

// Generate isolated baseline sources. Never swap files in the working tree.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const base = process.argv[2];
if (!base) {
  console.error('Usage: node tool/perf/async_hot_paths.mjs <baseline-ref> [output.json]');
  process.exit(1);
}
const output = resolve(root, process.argv[3] ?? '.dart_tool/async-hot-paths/results.json');
const scratch = resolve(root, '.dart_tool/async-hot-paths');
const sources = {
  analytics: 'lib/core/analytics/providers/composite_analytics_provider.dart',
  favourites: 'lib/features/favourite_walls/data/repositories/favourite_counts_repository_impl.dart',
  search: 'lib/features/user_search/data/repositories/user_search_repository_impl.dart',
};
mkdirSync(scratch, {recursive: true});
mkdirSync(dirname(output), {recursive: true});
for (const [name, path] of Object.entries(sources)) {
  writeFileSync(resolve(scratch, `${name}_before.dart`), execFileSync('git', ['show', `${base}:${path}`], {cwd: root}));
}
writeFileSync(resolve(scratch, 'benchmark_test.dart'),
  readFileSync(resolve(root, 'tool/perf/async_hot_paths_benchmark.dart.template')));
const revision = execFileSync('git', ['rev-parse', base], {cwd: root, encoding: 'utf8'}).trim();
const sourceHashes = Object.fromEntries(Object.entries(sources).map(([name, path]) =>
  [name, createHash('sha256').update(readFileSync(resolve(root, path))).digest('hex')]));
const metadata = {base: revision, measuredAt: new Date().toISOString(), cpus: cpus().length, loadAverage: loadavg(), sourceHashes};
const result = spawnSync('fvm', ['flutter', 'test', '--no-pub', '--concurrency=1', '--reporter=expanded',
  `--dart-define=BENCH_OUTPUT=${output}`, resolve(scratch, 'benchmark_test.dart')], {cwd: root, stdio: 'inherit'});
if (result.status !== 0) process.exit(result.status ?? 1);
const data = JSON.parse(readFileSync(output, 'utf8'));
writeFileSync(output, `${JSON.stringify({...metadata, ...data}, null, 2)}\n`);
console.log(`Results: ${output}`);
