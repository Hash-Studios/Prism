import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const router = read('lib/core/router/app_router.dart');
const catalog = read('lib/core/router/deep_link_route_catalog.dart');
const parser = read('lib/core/router/deep_link_parser.dart');
const worker = read('infra/cloudflare/worker/src/index.ts');
const associations = read('infra/cloudflare/worker/src/association_files.ts');
const wrangler = read('infra/cloudflare/worker/wrangler.toml');
const manifest = read('android/app/src/main/AndroidManifest.xml');
const entitlements = read('ios/Runner/Runner.entitlements');
const infoPlist = read('ios/Runner/Info.plist');

const fail = (message) => assert.fail(`Deep-link contract: ${message}`);
const quotedValues = (source) => [...source.matchAll(/'([^']+)'/g)].map((match) => match[1]);
const arrayBody = (source, name) => {
  const match = new RegExp(`const ${name} = \\[([\\s\\S]*?)\\];`).exec(source);
  if (!match) fail(`cannot read ${name}`);
  return match[1];
};

const catalogExamples = [...catalog.matchAll(/DeepLinkRouteExample\(\s*'([^']+)'/g)].map((match) => match[1]);
if (catalogExamples.length === 0) fail('DeepLinkRouteCatalog.examples is empty or changed shape');
const exampleUrls = catalogExamples.map((value) => new URL(value, 'https://prismwalls.com'));
const examplePaths = exampleUrls.map((url) => url.pathname);
const workerPaths = new Set(quotedValues(arrayBody(worker, 'APP_PAGE_PATHS')));
const workerRoots = new Set([
  ...quotedValues(arrayBody(worker, 'APP_LINK_PATHS')),
  ...workerPaths,
]);
const aasaPaths = new Set(quotedValues(arrayBody(associations, 'APP_LINK_PATHS')));

const dynamicWorkerRoots = new Set([
  '/share', '/user', '/fprofile', '/follower-profile', '/profile', '/setup', '/share-setup', '/refer', '/referral',
  '/l', '/drops', '/collection', '/category', '/wallpaper', '/folder', '/mood',
]);
const pathFits = (path, roots, dynamicRoots) => {
  if (roots.has(path)) return true;
  return [...dynamicRoots].some((rootPath) => path.startsWith(`${rootPath}/`));
};

for (const path of examplePaths) {
  if (path === '/') continue; // The marketing home page remains owned by Next.js.
  if (!pathFits(path, workerPaths, dynamicWorkerRoots)) fail(`worker does not allow catalog example ${path}`);
  if (!pathFits(path, workerRoots, dynamicWorkerRoots)) fail(`worker landing dispatch misses catalog example ${path}`);
  if (!aasaMatches(path, aasaPaths)) fail(`AASA does not cover catalog example ${path}`);
}

const routerPaths = [...router.matchAll(/\b(?:AutoRoute|RedirectRoute|CustomRoute)\s*\([\s\S]*?\bpath:\s*'([^']+)'/g)]
  .map((match) => match[1])
  .filter((path) => path.startsWith('/') && path !== '/' && path !== '/*');
for (const routePath of routerPaths) {
  const routeParts = routePath.split('/').filter(Boolean);
  const hasExample = examplePaths.some((example) => {
    const parts = example.split('/').filter(Boolean);
    return routeParts.length === parts.length && routeParts.every((part, index) => part.startsWith(':') || part === parts[index]);
  });
  if (!hasExample) fail(`AppRouter path ${routePath} has no catalog example`);
}

const aliases = [
  ...quotedValues(/const Set<String> _shareRoots = <String>\{([^}]+)\}/.exec(parser)?.[1] ?? ''),
  ...quotedValues(/const Set<String> _userRoots = <String>\{([^}]+)\}/.exec(parser)?.[1] ?? ''),
  ...quotedValues(/const Set<String> _setupRoots = <String>\{([^}]+)\}/.exec(parser)?.[1] ?? ''),
  ...quotedValues(/const Set<String> _referRoots = <String>\{([^}]+)\}/.exec(parser)?.[1] ?? ''),
  ...quotedValues(/const Set<String> _shortCodeRoots = <String>\{([^}]+)\}/.exec(parser)?.[1] ?? ''),
];
for (const alias of aliases) {
  const path = `/${alias}`;
  if (!workerRoots.has(path)) fail(`worker landing dispatch misses native alias ${path}`);
  if (!aasaMatches(path, aasaPaths)) fail(`AASA misses native alias ${path}`);
}

for (const host of ['prismwalls.com', 'www.prismwalls.com']) {
  if (!entitlements.includes(`applinks:${host}`)) fail(`iOS associated domains omit ${host}`);
  const queryExamples = exampleUrls.flatMap((url) => url.pathname === '/' ? [] : [
    `${url.pathname}${url.search}`,
    `${url.pathname}?utm_source=contract`,
    `${url.pathname}?utm_medium=contract`,
    `${url.pathname}?utm_campaign=contract`,
    `${url.pathname}?utm_source=contract&utm_medium=contract&utm_campaign=contract`,
  ]);
  const queryOnlyAliases = [
    '/share?id=x',
    '/user?identifier=x',
    '/fprofile?username=x',
    '/follower-profile?username=x',
    '/profile?user=x',
    '/setup?name=x',
    '/share-setup?setupName=x',
    '/refer?userID=x',
    '/referral?id=x',
    '/l?code=x',
  ];
  queryExamples.push(...queryOnlyAliases);
  for (const alias of queryOnlyAliases) {
    const separator = alias.includes('?') ? '&' : '?';
    queryExamples.push(
      `${alias}${separator}utm_source=contract`,
      `${alias}${separator}utm_medium=contract`,
      `${alias}${separator}utm_campaign=contract`,
      `${alias}${separator}utm_source=contract&utm_medium=contract&utm_campaign=contract`,
    );
  }
  for (const url of new Set(queryExamples)) {
    if (!workerRouteMatches(host, url, wrangler)) fail(`Cloudflare route for ${host}${url} is missing`);
  }
}

const androidComponents = [...manifest.matchAll(/<(?:activity|activity-alias)\b[\s\S]*?<\/\s*(?:activity|activity-alias)\s*>/g)]
  .map((match) => match[0])
  .filter((component) => component.includes('android:autoVerify="true"'));
if (androidComponents.length !== 5) fail(`expected main activity plus four icon aliases, found ${androidComponents.length}`);
if (!infoPlist.includes('<string>prism</string>')) fail('iOS URL types do not register the prism scheme');
for (const component of androidComponents) {
  if (!component.includes('android:host="prismwalls.com"') || !component.includes('android:host="www.prismwalls.com"')) {
    fail('an Android activity or icon alias does not declare both HTTPS hosts');
  }
  if (!component.includes('android:scheme="prism"')) fail('an Android activity or icon alias lacks the prism scheme');
  const exact = new Set([...component.matchAll(/android:path="([^"]+)"/g)].map((match) => match[1]));
  const prefixes = [...component.matchAll(/android:pathPrefix="([^"]+)"/g)].map((match) => match[1]);
  for (const path of examplePaths.filter((value) => value !== '/')) {
    if (!exact.has(path) && !prefixes.some((prefix) => path.startsWith(prefix))) {
      fail(`Android activity or icon alias does not match catalog example ${path}`);
    }
  }
}

console.log(`Deep-link contract passed: ${catalogExamples.length} catalog examples, ${aliases.length} native aliases, ${androidComponents.length} Android components.`);

function aasaMatches(path, patterns) {
  for (const pattern of patterns) {
    if (pattern.endsWith('/*')) {
      if (path.startsWith(`${pattern.slice(0, -1)}`)) return true;
    } else if (path === pattern) {
      return true;
    }
  }
  return false;
}

function workerRouteMatches(host, pathAndQuery, source) {
  const requestUrl = `${host}${pathAndQuery}`;
  const patterns = [...source.matchAll(/pattern = "([^"]+)"/g)].map((match) => match[1]);
  return patterns.some((pattern) => {
    if (!pattern.startsWith(`${host}/`)) return false;
    return pattern.endsWith('*')
      ? requestUrl.startsWith(pattern.slice(0, -1))
      : requestUrl === pattern;
  });
}

const exactLibraryRoute = '[[routes]]\npattern = "prismwalls.com/library"\n';
const wildcardLibraryRoute = '[[routes]]\npattern = "prismwalls.com/library*"\n';
if (workerRouteMatches('prismwalls.com', '/library?tab=downloads', exactLibraryRoute)) {
  fail('route matcher incorrectly lets an exact /library pattern match a query string');
}
if (!workerRouteMatches('prismwalls.com', '/library?tab=downloads', wildcardLibraryRoute)) {
  fail('route matcher does not let a trailing wildcard match a query string');
}
