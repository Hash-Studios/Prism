#!/usr/bin/env python3
"""Compare this checkout (master) with production and print an ordered deploy plan.

Read only. Every live call is a list, get, or describe. See docs/features/backend-deploy.md "Check drift".
Run through `make deploy-drift` (it builds functions/lib first). `--json` prints the same data as JSON.
"""

import argparse
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import textwrap
import tomllib
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
FUNCTIONS = ROOT / 'functions'
WORKER = ROOT / 'infra/cloudflare/worker'
MIGRATION_NOTES = ROOT / 'tool/deploy_drift_migrations.json'
# A change to these files can change every function.
FUNCTIONS_SHARED_FILES = ('functions/package.json', 'functions/package-lock.json', 'functions/tsconfig.json')
HISTORY_PATHS = ('functions', 'firestore.rules', 'firestore.indexes.json', 'infra/cloudflare/worker')

IN_SYNC = 'in sync'
MISSING_LIVE = 'missing live'
DIFFERENT = 'different'
LIVE_ONLY = 'live only'
UNKNOWN = 'unknown'

RULES, INDEX, TTL, FUNCTION, FUNCTION_OPTIONS, WORKER_KIND, REMOTE_CONFIG, MIGRATION = (
    'rules', 'index', 'ttl', 'function', 'function options', 'worker', 'remote config key', 'migration')


@dataclass
class DriftItem:
    kind: str
    name: str
    master: str
    live: str
    status: str
    reason: str = ''
    prs: list = field(default_factory=list)


@dataclass(frozen=True)
class Step:
    title: str
    kinds: tuple
    reason: str
    command: str


# The safe order from .claude/skills/prism-release/SKILL.md (steps 3 to 6) and docs/features/backend-deploy.md.
STEPS = (
    Step('Firestore rules', (RULES,),
         'New functions and client code need the new access first. A change that refuses a write that shipped '
         'clients make waits for the owner (release skill step 6).',
         'make rules-test && firebase deploy --only firestore:rules --project {project} --non-interactive'),
    Step('Firestore indexes and TTL policies', (INDEX, TTL),
         'New queries must work when the functions go live. Wait until each new index is READY. Never --force: '
         'it deletes live indexes that the file does not list.',
         'firebase deploy --only firestore:indexes --project {project} --non-interactive'),
    Step('Cloud Functions', (FUNCTION, FUNCTION_OPTIONS),
         'Deploy before any client build that calls a new or changed callable. Never --force. A live-only '
         'function stops a non-interactive deploy: delete it by hand or deploy with --only functions:<name>.',
         'make functions-deploy FIREBASE_ACCOUNT=<email>'),
    Step('Data migrations', (MIGRATION,),
         'Scripts need the deployed functions and indexes. Dry run first, then --apply only after the owner '
         'says yes for that script. This tool cannot see whether --apply ran.',
         'cd functions && GOOGLE_CLOUD_PROJECT={project} npm run <migrate:script>   # dry run'),
    Step('Cloudflare worker', (WORKER_KIND,),
         'The worker reads data and functions from the steps above.',
         'cd infra/cloudflare/worker && wrangler deploy'),
    Step('Remote Config keys', (REMOTE_CONFIG,),
         'The app uses its built-in default until the key is published. Publish only the keys that need a '
         'non-default value, in the Firebase console, before the client that reads them ships.',
         'Firebase console > Remote Config (owner only)'),
)


# Pure compare logic. Unit tests in tool/deploy_drift_test.py cover these.

def normalize_rules(text):
    # Keep strings and comments intact, including the newline that ends a line comment.
    tokens = re.findall(r""""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|//[^\n]*(?:\n|$)|/\*[\s\S]*?\*/|\w+|==|!=|<=|>=|&&|\|\||[^\s]""", text)
    return tuple(tokens)


def compare_rules(local_text, live_text, live_time, prs):
    if live_text is None:
        return DriftItem(RULES, 'firestore.rules', 'firestore.rules', 'no release', MISSING_LIVE, prs=prs)
    if normalize_rules(local_text) == normalize_rules(live_text):
        return DriftItem(RULES, 'firestore.rules', 'firestore.rules', f'released {live_time}', IN_SYNC)
    local_lines, live_lines = set(local_text.splitlines()), set(live_text.splitlines())
    added = len([line for line in local_text.splitlines() if line not in live_lines])
    removed = len([line for line in live_text.splitlines() if line not in local_lines])
    return DriftItem(RULES, 'firestore.rules', f'+{added} -{removed} lines vs live', f'released {live_time}',
                     DIFFERENT, 'master rules text differs from the live ruleset', prs)


def _field_key(f):
    for mode in ('order', 'arrayConfig', 'vectorConfig'):
        if mode in f:
            value = f[mode]
            return f"{f['fieldPath']}:{json.dumps(value, sort_keys=True) if isinstance(value, dict) else value}"
    return f['fieldPath']


def index_key(collection_group, query_scope, fields):
    # Firestore adds __name__ to live indexes on its own.
    fields = list(fields)
    ordered = [f['order'] for f in fields if f['fieldPath'] != '__name__' and 'order' in f]
    implicit_order = ordered[-1] if ordered else 'ASCENDING'
    if fields and fields[-1] == {'fieldPath': '__name__', 'order': implicit_order}:
        fields.pop()
    parts = [_field_key(f) for f in fields]
    return f"{collection_group} [{query_scope or 'COLLECTION'}] ({', '.join(parts)})"


def live_index_key(index):
    collection_group = index['name'].split('/collectionGroups/')[1].split('/')[0]
    return index_key(collection_group, index.get('queryScope'), index.get('fields', []))


def compare_keyed(kind, local, live, live_ok=lambda value: True, describe_live=lambda value: 'present'):
    """local: {key: master description}. live: {key: live object}. Returns one DriftItem per key."""
    items = []
    for key, master in local.items():
        if key not in live:
            items.append(DriftItem(kind, key, master, '', MISSING_LIVE))
        elif live_ok(live[key]):
            items.append(DriftItem(kind, key, master, describe_live(live[key]), IN_SYNC))
        else:
            items.append(DriftItem(kind, key, master, describe_live(live[key]), DIFFERENT, 'not ready live'))
    items += [DriftItem(kind, key, '', describe_live(value), LIVE_ONLY) for key, value in live.items() if key not in local]
    return items


def compare_indexes(local_json, live_indexes):
    local = {index_key(i['collectionGroup'], i.get('queryScope'), i['fields']): 'listed' for i in local_json['indexes']}
    live = {live_index_key(i): i for i in live_indexes}
    return compare_keyed(INDEX, local, live, lambda i: i.get('state') == 'READY', lambda i: i.get('state', '?'))


def compare_ttls(local_json, live_fields):
    local = {f"{o['collectionGroup']}.{o['fieldPath']}": 'ttl'
             for o in local_json.get('fieldOverrides', []) if o.get('ttl')}
    live = {}
    for f in live_fields:
        if 'ttlConfig' in f:
            parts = f['name'].split('/')
            live[f'{parts[-3]}.{parts[-1]}'] = f['ttlConfig']
    return compare_keyed(TTL, local, live, lambda c: c.get('state') == 'ACTIVE', lambda c: c.get('state', '?'))


def memory_mb(value):
    match = re.fullmatch(r'(\d+(?:\.\d+)?)(Mi|M|Gi|G)?', str(value))
    if not match:
        return None
    number, unit = float(match.group(1)), match.group(2) or ''
    return int(number * 1024) if unit.startswith('G') else int(number)


GEN1_CPU = {128: 0.0833, 256: 0.1666, 512: 0.3333, 1024: 0.5833, 2048: 1, 4096: 2, 8192: 2, 16384: 4, 32768: 8}
GEN2_CPU = {128: 1, 256: 1, 512: 1, 1024: 1, 2048: 1, 4096: 2, 8192: 2, 16384: 4, 32768: 8}


def want_options(endpoint):
    """The options firebase deploy sets, with the same defaults as firebase-tools (backend.js, prepare.js)."""
    memory = endpoint.get('availableMemoryMb')
    memory = memory if isinstance(memory, int) else 256
    cpu = endpoint.get('cpu')
    if cpu == 'gcf_gen1':
        cpu = GEN1_CPU.get(memory)
    elif not isinstance(cpu, (int, float)):
        cpu = GEN2_CPU.get(memory)
    max_instances = endpoint.get('maxInstances')
    # ponytail: an unset maxInstances keeps the live value, so it is not compared. The code-time check still
    # catches a removed setting, because removing it is a code change.
    return {'memory': memory, 'cpu': float(cpu) if cpu is not None else None,
            'maxInstances': max_instances if isinstance(max_instances, int) else None}


def live_options(fn):
    config = fn.get('serviceConfig', {})
    cpu = config.get('availableCpu')
    return {'memory': memory_mb(config.get('availableMemory')), 'cpu': float(cpu) if cpu else None,
            'maxInstances': config.get('maxInstanceCount')}


def option_diff(want, have):
    out = []
    for key, value in want.items():
        if value is None:
            continue
        live_value = have.get(key)
        same = live_value is not None and abs(float(live_value) - float(value)) < 0.01
        if not same:
            out.append(f'{key} {live_value} -> {value}')
    return out


def fmt_options(options):
    return ' '.join(f'{k}={v}' for k, v in options.items() if v is not None)


def parse_time(value):
    """RFC 3339 with up to 9 fraction digits, as the Google and Cloudflare APIs return it."""
    value = re.sub(r'(\.\d{6})\d+', r'\1', value.replace('Z', '+00:00'))
    return datetime.fromisoformat(value)


def compare_functions(endpoints, live_fns, code_times, prs_since):
    """endpoints: manifest endpoints. live_fns: gcloud v2 list. code_times: {function: unix time the code last
    landed}. prs_since: f(function, unix time) -> PRs that landed after it."""
    live = {}
    for fn in live_fns:
        parts = fn['name'].split('/')
        live[f'{parts[3]}/{parts[5]}'] = fn
    items = []
    for name, endpoint in sorted(endpoints.items()):
        want = want_options(endpoint)
        if not endpoint.get('region'):
            items.append(DriftItem(FUNCTION, name, '', '', UNKNOWN, 'manifest has no resolved region'))
        for region in endpoint.get('region', []):
            key = f'{region}/{name}'
            if key not in live:
                items.append(DriftItem(FUNCTION, key, fmt_options(want), '', MISSING_LIVE))
                continue
            fn = live.pop(key)
            have = live_options(fn)
            deployed = parse_time(fn['updateTime'])
            landed = code_times.get(name)
            if fn.get('state') != 'ACTIVE':
                items.append(DriftItem(FUNCTION, key, fmt_options(want), fn.get('state', '?'), DIFFERENT,
                                       'live function is not ACTIVE'))
            elif landed is None:
                items.append(DriftItem(FUNCTION, key, '', f'deployed {_iso(deployed)}', UNKNOWN,
                                       'function history is not available'))
            elif landed > deployed.timestamp():
                landed_text = _iso(landed)
                items.append(DriftItem(FUNCTION, key, f'code landed {landed_text}', f'deployed {_iso(deployed)}',
                                       DIFFERENT, 'code landed on master after the live deploy',
                                       prs_since(name, deployed.timestamp())))
            else:
                items.append(DriftItem(FUNCTION, key, f'code landed {_iso(landed)}', f'deployed {_iso(deployed)}',
                                       IN_SYNC))
            diff = option_diff(want, have)
            if diff:
                items.append(DriftItem(FUNCTION_OPTIONS, key, fmt_options(want), fmt_options(have), DIFFERENT,
                                       '; '.join(diff)))
    items += [DriftItem(FUNCTION, key, '', f'deployed {_iso(parse_time(fn["updateTime"]))}', LIVE_ONLY,
                        'not exported on master') for key, fn in sorted(live.items())]
    return items


def compare_worker(name, live_deployed, landed, prs):
    if live_deployed is None:
        return DriftItem(WORKER_KIND, name, f'changed {_iso(landed) if landed is not None else UNKNOWN}', 'no deployment', MISSING_LIVE, prs=prs)
    if landed is None:
        return DriftItem(WORKER_KIND, name, '', '', UNKNOWN, 'worker history is not available')
    deployed = parse_time(live_deployed)
    if landed > deployed.timestamp():
        return DriftItem(WORKER_KIND, name, f'changed {_iso(landed)}', f'deployed {_iso(deployed)}', DIFFERENT,
                         'worker code landed on master after the live deploy', prs)
    return DriftItem(WORKER_KIND, name, f'changed {_iso(landed)}', f'deployed {_iso(deployed)}', IN_SYNC)


def compare_remote_config(read_keys, template_keys):
    """read_keys: {key: where the app or functions read it}. template_keys: published template keys."""
    items = []
    for key, where in sorted(read_keys.items()):
        if key in template_keys:
            items.append(DriftItem(REMOTE_CONFIG, key, where, 'published', IN_SYNC))
        else:
            items.append(DriftItem(REMOTE_CONFIG, key, where, '', MISSING_LIVE, 'not in the template, so the code '
                                   'default applies'))
    items += [DriftItem(REMOTE_CONFIG, key, '', 'published', LIVE_ONLY,
                         'no resolved code read on master; old app builds may')
              for key in sorted(template_keys) if key not in read_keys]
    return items


def migration_items(scripts, notes):
    items = []
    for script in scripts:
        note = notes.get(script, {})
        prs = [note['pr']] if note.get('pr') else []
        items.append(DriftItem(MIGRATION, script, note.get('npm') or 'node lib/...', 'cannot be read',
                               UNKNOWN, f"ask the owner. {note.get('note', 'No note in a PR or the docs.')}", prs))
    return items


def build_plan(items, project):
    plan = []
    for step in STEPS:
        todo = [i for i in items if i.kind in step.kinds and i.status != IN_SYNC]
        if todo:
            plan.append({'step': len(plan) + 1, 'title': step.title, 'reason': step.reason,
                         'command': step.command.format(project=project), 'items': [asdict(i) for i in todo]})
    return plan


def _iso(value):
    if isinstance(value, (int, float)):
        value = datetime.fromtimestamp(value, timezone.utc)
    return value.astimezone(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')


# Local reads.

class History:
    """First-parent history of HEAD, so a time is when a change landed on master, not when it was written."""

    def __init__(self):
        # A shallow boundary commit lists every file as added at its own time. That time is later than the true
        # landing, so a shallow checkout can show a false "different" but never a false "in sync".
        out = git('log', '--first-parent', '--diff-merges=first-parent', '--format=%x00%ct%x09%H%x09%s', '--name-only', 'HEAD', '--',
                  *HISTORY_PATHS)
        self.commits = []
        for chunk in out.split('\x00')[1:]:
            head, *files = chunk.strip('\n').split('\n')
            stamp, sha, subject = head.split('\t', 2)
            self.commits.append((int(stamp), sha, pr_label(subject, sha), {f for f in files if f}))

    def landed(self, paths):
        return next((c[0] for c in self.commits if c[3] & paths), None)

    def prs_since(self, paths, since):
        return _unique(c[2] for c in self.commits if c[0] > since and c[3] & paths)

    def landed_under(self, prefix, exclude=()):
        for stamp, _, _, files in self.commits:
            if any(f.startswith(prefix) and not f.startswith(exclude) for f in files):
                return stamp
        return None

    def prs_since_under(self, prefix, since, exclude=()):
        return _unique(c[2] for c in self.commits
                       if c[0] > since and any(f.startswith(prefix) and not f.startswith(exclude) for f in c[3]))


def pr_label(subject, sha):
    match = re.search(r'Merge pull request #(\d+)|\(#(\d+)\)$', subject)
    return f'#{match.group(1) or match.group(2)}' if match else sha[:9]


def _unique(values):
    return list(dict.fromkeys(values))


def git(*args):
    return run(['git', *args])


def _pr_for_line(path, line):
    """The PR that last changed this line, through the merge that brought its commit onto master."""
    blame = git('blame', '--porcelain', '-L', f'{line},{line}', 'HEAD', '--', path)
    sha = blame.split()[0]
    first_parent = git('rev-list', '--first-parent', 'HEAD').split()
    if sha not in first_parent:
        descendants = set(git('rev-list', '--ancestry-path', f'{sha}..HEAD').split())
        sha = [c for c in first_parent if c in descendants][-1]
    return pr_label(git('log', '-1', '--format=%s', sha).strip(), sha)


def pr_for_line(path, line):
    try:
        return _pr_for_line(path, line) if line else ''
    except Exception:
        return ''


def line_of(path, pattern, nth=0):
    text = (ROOT / path).read_text()
    matches = list(re.finditer(pattern, text))
    return text.count('\n', 0, matches[nth].start()) + 1 if len(matches) > nth else None


def function_modules():
    """{export name: module path} from functions/src/index.ts."""
    text = (FUNCTIONS / 'src/index.ts').read_text()
    out = {}
    for names, module in re.findall(r"export\s*\{([^}]*)\}\s*from\s*['\"]([^'\"]+)['\"]", text):
        for name in names.split(','):
            name = name.strip()
            if name:
                out[name.split(' as ')[-1].strip()] = resolve_ts(FUNCTIONS / 'src', module)
    return out


def resolve_ts(base, module):
    path = (base / module).resolve()
    for candidate in (path if path.suffix == '.ts' else Path(str(path) + '.ts'),
                      path.with_suffix('.ts') if path.suffix == '.js' else path / 'index.ts'):
        if candidate.exists():
            return candidate
    return None


def import_closure(start):
    seen, todo = set(), [start and start.resolve()]
    while todo:
        path = todo.pop()
        if path is None or path in seen:
            continue
        seen.add(path)
        text = path.read_text()
        for call in re.finditer(r'\b(?:import|require)\s*\(', text):
            if not re.match(r'''\s*(['"])[^'"]+\1\s*\)''', text[call.end():]):
                raise DriftError('dynamic import could not be resolved')
        for module in re.findall(r"(?:\bfrom\s*|\bimport\s*(?:\(\s*)?|\brequire\s*\(\s*)['\"](\.{1,2}/[^'\"]+)['\"]", path.read_text()):
            resolved = resolve_ts(path.parent, module)
            if resolved is None:
                raise DriftError('relative import could not be resolved')
            todo.append(resolved)
    return {str(p.relative_to(ROOT.resolve())) for p in seen}


def require_clean(paths):
    if git('diff', '--name-only', 'HEAD', '--', *paths).strip() or git(
            'ls-files', '--others', '--exclude-standard', '--', *paths).strip():
        raise DriftError('source differs from HEAD')


def functions_manifest():
    """The endpoint manifest that firebase deploy reads, built from functions/lib without a network call."""
    if not (FUNCTIONS / 'lib/index.js').exists():
        raise DriftError('functions/lib is missing. Run `make deploy-drift`, which builds it first.')
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / 'manifest.json'
        env = {'PATH': os.environ.get('PATH', ''), 'HOME': os.environ.get('HOME', ''),
               'FUNCTIONS_MANIFEST_OUTPUT_PATH': str(out)}
        run(['node', 'node_modules/firebase-functions/lib/bin/firebase-functions.js', '.'], cwd=FUNCTIONS, env=env)
        return json.loads(out.read_text())['endpoints']


RC_TOKEN = r"(?:'[^'\n]*'|\"[^\"\n]*\"|[\w.]+)"
RC_START = r'(?:[Rr]emote[Cc]onfig\w*|\brc)\??\.get(?:String|Bool|Int|Double|Value)\('
RC_READ = re.compile(RC_START + r'\s*(' + RC_TOKEN + r')\s*\)')
RC_DEFAULT = re.compile(r'^\s*(' + RC_TOKEN + r')\s*:', re.M)
# A call through a function value named for Remote Config, such as `_remoteConfig(remoteEnabledKey)`.
RC_CALL = re.compile(r'\b\w*[Rr]emote[Cc]onfig\w*\(\s*(' + RC_TOKEN + r')\s*\)')
SERVER_RC = re.compile(r"parameters\?*\.(\w+)|parameters\??\.?(?:\[)\s*['\"]([^'\"]+)['\"]\s*\]")


class RemoteConfigReads(dict):
    def __init__(self):
        super().__init__()
        self.unresolved = []


def remote_config_reads():
    """Resolve static literals, constants, conditional literals, and wrapper calls.

    Unresolved reads remain visible, rather than proving that a template key is unused.
    """
    files = [p for p in (ROOT / 'lib').rglob('*.dart') if '/generated/' not in str(p) and not p.name.endswith('.g.dart')]
    texts = {p: p.read_text() for p in files}
    consts, local = {}, {}
    for path, text in texts.items():
        local[path] = {}
        classes = list(re.finditer(r'\bclass\s+(\w+)', text))
        for match in re.finditer(r'\b(\w+)\s*=\s*([^;]+);', text):
            name, expression = match.group(1), match.group(2).strip()
            values = re.findall(r"['\"]([^'\"$]+)['\"]", expression)
            literal = re.fullmatch(r"['\"][^'\"$]+['\"]", expression)
            conditional = re.fullmatch(r"[^?]+\?\s*['\"][^'\"$]+['\"]\s*:\s*['\"][^'\"$]+['\"]", expression)
            if not (literal or conditional):
                continue
            local[path].setdefault(name, set()).update(values)
            consts.setdefault(name, set()).update(values)
            preceding = [c for c in classes if c.start() < match.start()]
            if preceding:
                consts.setdefault(preceding[-1].group(1) + '.' + name, set()).update(values)
    keys = RemoteConfigReads()
    wrappers = set()

    def add(token, path, pos):
        text = texts[path]
        if token.startswith(("'", '\"')):
            values = {token[1:-1]} if '$' not in token else set()
        else:
            values = local[path].get(token, set()) if '.' not in token else set()
            values = values or consts.get(token, set())
            if len(values) > 1 and token not in local[path]:
                values = set()
        for value in values:
            keys.setdefault(value, f'{path.relative_to(ROOT)}:{text.count(chr(10), 0, pos) + 1}')
        return bool(values)

    def unresolved(token, path, pos):
        text = texts[path]
        declarations = list(re.finditer(r'\b(\w+)\(\s*String\s+' + re.escape(token) + r'\b', text[:pos]))
        if declarations and not re.search(r'[};]', text[declarations[-1].end():pos]):
            name = declarations[-1].group(1)
            wrappers.add((path if name.startswith('_') else None, name))
        else:
            location = f'{path.relative_to(ROOT)}:{text.count(chr(10), 0, pos) + 1}'
            if location not in keys.unresolved:
                keys.unresolved.append(location)

    for path, text in texts.items():
        resolved_calls = {m.start() for m in RC_READ.finditer(text)}
        for match in re.finditer(RC_START, text):
            if match.start() not in resolved_calls:
                keys.unresolved.append(f'{path.relative_to(ROOT)}:{text.count(chr(10), 0, match.start()) + 1}')
        for match in [*RC_READ.finditer(text), *RC_CALL.finditer(text)]:
            if not add(match.group(1), path, match.start()):
                unresolved(match.group(1), path, match.start())
        for block in re.finditer(r'setDefaults\(<String, dynamic>\{(.*?)\}\)', text, re.S):
            for match in RC_DEFAULT.finditer(block.group(1)):
                if not add(match.group(1), path, block.start(1) + match.start()):
                    unresolved(match.group(1), path, block.start(1) + match.start())
    processed = set()
    while wrappers - processed:
        scope, name = next(iter(wrappers - processed))
        processed.add((scope, name))
        call = re.compile(r'\b' + re.escape(name) + r'\(\s*(' + RC_TOKEN + r')\s*\)')
        for path, text in texts.items():
            if scope is not None and scope != path:
                continue
            for match in call.finditer(text):
                if not add(match.group(1), path, match.start()):
                    unresolved(match.group(1), path, match.start())
    for path in (FUNCTIONS / 'src').rglob('*.ts'):
        if '__tests__' in path.parts:
            continue
        text = path.read_text()
        for match in SERVER_RC.finditer(text):
            key = match.group(1) or match.group(2)
            keys.setdefault(key, f'{path.relative_to(ROOT)}:{text.count(chr(10), 0, match.start()) + 1}')
        if re.search(r'parameters\??\.?\[\s*[^\s\"\']', text):
            keys.unresolved.append(str(path.relative_to(ROOT)))
    return keys


def apply_scripts():
    out = []
    for path in sorted((FUNCTIONS / 'src').rglob('*.ts')):
        if '__tests__' not in path.parts and '--apply' in path.read_text():
            out.append(str(path.relative_to(ROOT)))
    return out


# Live reads. Each one is a list, get, or describe call.

class DriftError(Exception):
    pass


def run(cmd, cwd=ROOT, env=None):
    # The program and subcommand names only. Command output and arguments never go into the message.
    program = ' '.join([Path(cmd[0]).name, *cmd[1:2]])
    try:
        proc = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)
    except Exception:
        raise DriftError(f'{program} could not start') from None
    if proc.returncode != 0:
        raise DriftError(f'{program} exited {proc.returncode}') from None
    return proc.stdout


def gcloud_json(*args):
    return json.loads(run(['gcloud', *args, '--format=json']) or '[]')


def google_get(url, project):
    token = run(['gcloud', 'auth', 'print-access-token']).strip()
    request = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}', 'x-goog-user-project': project})
    for attempt in range(2):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code < 500 or attempt:
                raise DriftError(f'GET returned HTTP {error.code}') from None
        except Exception:
            raise DriftError('GET failed') from None


def live_rules(project):
    release = google_get(f'https://firebaserules.googleapis.com/v1/projects/{project}/releases/cloud.firestore', project)
    ruleset = google_get(f"https://firebaserules.googleapis.com/v1/{release['rulesetName']}", project)
    return ruleset['source']['files'][0]['content'], parse_time(release['updateTime'])


def live_functions(project):
    # Only these fields: the list never returns environment variables to this process.
    return json.loads(run(['gcloud', 'functions', 'list', '--v2', f'--project={project}',
                           '--format=json(name,state,updateTime,serviceConfig.availableMemory,'
                           'serviceConfig.availableCpu,serviceConfig.maxInstanceCount)']) or '[]')


def live_template_keys(project):
    template = google_get(f'https://firebaseremoteconfig.googleapis.com/v1/projects/{project}/remoteConfig', project)
    keys = set(template.get('parameters', {}))
    for group in template.get('parameterGroups', {}).values():
        keys |= set(group.get('parameters', {}))
    return keys


def live_worker():
    config = tomllib.loads((WORKER / 'wrangler.toml').read_text())
    executable = ROOT / 'web/node_modules/.bin/wrangler'
    if not executable.is_file():
        raise DriftError('install the web packages before the check')
    env = dict(os.environ)
    # BROWSER_RENDERING_ACCOUNT_ID is the Cloudflare account that owns this worker.
    env.setdefault('CLOUDFLARE_ACCOUNT_ID', config.get('vars', {}).get('BROWSER_RENDERING_ACCOUNT_ID', ''))
    # WRANGLER_LOG=none also hides the JSON on stdout, and a WRANGLER_LOG_PATH of /dev/null makes Wrangler fail.
    env.update(WRANGLER_SEND_METRICS='false', NO_UPDATE_NOTIFIER='1')
    out = run([str(executable), 'deployments', 'list', '--json', '--name', config['name']],
              cwd=WORKER, env=env)
    deployments = json.loads(out)
    return config['name'], max((d['created_on'] for d in deployments), default=None)


# Assembly.

def collect(project):
    items, errors = [], []
    try:
        history = History()
    except Exception:
        history = None

    def attempt(label, fn):
        try:
            fn()
        except DriftError as error:
            # DriftError text is built in this file from fixed strings, never from command or API output.
            errors.append(f'{label}: {error}')
            items.append(DriftItem(label, '*', '', '', UNKNOWN, f'could not read source: {error}'))
        except Exception:
            errors.append(f'{label}: could not read source')
            items.append(DriftItem(label, '*', '', '', UNKNOWN, 'could not read source'))

    def rules():
        text, released = live_rules(project)
        prs = history.prs_since({'firestore.rules'}, released.timestamp()) if history else []
        items.append(compare_rules((ROOT / 'firestore.rules').read_text(), text, _iso(released), prs))

    def indexes():
        local = json.loads((ROOT / 'firestore.indexes.json').read_text())
        found = compare_indexes(local, gcloud_json('firestore', 'indexes', 'composite', 'list', f'--project={project}'))
        keys = [index_key(i['collectionGroup'], i.get('queryScope'), i['fields']) for i in local['indexes']]
        for item in found:
            if item.status == MISSING_LIVE and item.kind == INDEX:
                item.prs = [pr_for_line('firestore.indexes.json',
                                        line_of('firestore.indexes.json', r'"collectionGroup"', keys.index(item.name)))]
        items.extend(found)

    def ttls():
        local = json.loads((ROOT / 'firestore.indexes.json').read_text())
        found = compare_ttls(local, gcloud_json('firestore', 'fields', 'ttls', 'list', f'--project={project}'))
        overrides = [f"{o['collectionGroup']}.{o['fieldPath']}" for o in local.get('fieldOverrides', [])]
        for item in found:
            if item.status == MISSING_LIVE:
                nth = len(local['indexes']) + overrides.index(item.name)
                item.prs = [pr_for_line('firestore.indexes.json', line_of('firestore.indexes.json', r'"collectionGroup"', nth))]
        items.extend(found)

    def functions():
        if history is None:
            raise DriftError('function history is not available')
        require_clean(('functions/src', *FUNCTIONS_SHARED_FILES))
        endpoints = functions_manifest()
        modules = function_modules()
        entrypoint_paths = import_closure(FUNCTIONS / 'src/index.ts')
        closures = {name: import_closure(modules.get(name) or FUNCTIONS / 'src/index.ts') |
                          entrypoint_paths | set(FUNCTIONS_SHARED_FILES) for name in endpoints}
        code_times = {name: history.landed(paths) for name, paths in closures.items()}
        found = compare_functions(endpoints, live_functions(project), code_times,
                                  lambda name, since: history.prs_since(closures[name], since))
        for item in found:
            if item.status == MISSING_LIVE:
                line = line_of('functions/src/index.ts', r'\b' + re.escape(item.name.split('/')[1]) + r'\b')
                item.prs = [pr_for_line('functions/src/index.ts', line)] if line else []
        items.extend(found)

    def worker():
        if history is None:
            raise DriftError('worker history is not available')
        require_clean(('infra/cloudflare/worker',))
        name, deployed = live_worker()
        prefix, exclude = 'infra/cloudflare/worker/', ('infra/cloudflare/worker/test/',)
        landed = history.landed_under(prefix, exclude)
        since = parse_time(deployed).timestamp() if deployed else 0
        items.append(compare_worker(name, deployed, landed, history.prs_since_under(prefix, since, exclude)))

    def remote_config():
        reads = remote_config_reads()
        found = compare_remote_config(reads, live_template_keys(project))
        if getattr(reads, 'unresolved', []):
            found.append(DriftItem(REMOTE_CONFIG, '*', '', '', UNKNOWN, 'some key reads could not be resolved: ' + ', '.join(reads.unresolved)))
        for item in found:
            if item.status == MISSING_LIVE:
                path, line = item.master.rsplit(':', 1)
                item.prs = [pr_for_line(path, int(line))]
        items.extend(found)

    def migrations():
        notes = json.loads(MIGRATION_NOTES.read_text())
        items.extend(migration_items(apply_scripts(), notes))

    attempt(RULES, rules)
    attempt(INDEX, indexes)
    attempt(TTL, ttls)
    attempt(FUNCTION, functions)
    attempt(WORKER_KIND, worker)
    attempt(REMOTE_CONFIG, remote_config)
    attempt(MIGRATION, migrations)
    return items, errors


def render_table(items):
    drift = [i for i in items if i.status != IN_SYNC]
    rows = [('KIND', 'NAME', 'STATUS', 'MASTER', 'LIVE', 'PR')]
    rows += [(i.kind, i.name, i.status, i.master, i.live, ' '.join(i.prs)) for i in drift]
    widths = [min(max(len(r[c]) for r in rows), 48) for c in range(len(rows[0]))]
    lines = ['  '.join(cell[:48].ljust(widths[c]) for c, cell in enumerate(row)).rstrip() for row in rows]
    counts = {}
    for i in items:
        counts.setdefault(i.kind, {}).setdefault(i.status, 0)
        counts[i.kind][i.status] += 1
    lines.append('')
    lines += [f'{kind}: ' + ', '.join(f'{n} {s}' for s, n in sorted(c.items())) for kind, c in counts.items()]
    return '\n'.join(lines)


def render_plan(plan):
    if not plan:
        return 'Deploy plan: nothing to deploy.'
    lines = ['Deploy plan (run each step only after the owner says yes):']
    for step in plan:
        lines += ['', f"{step['step']}. {step['title']} ({len(step['items'])} items)", f"   Why: {step['reason']}",
                  f"   Command: {step['command']}"]
        groups = {}
        for item in step['items']:
            groups.setdefault((item['kind'], item['status'], item['reason'], tuple(item['prs'])), []).append(item['name'])
        for (kind, status, reason, prs), names in groups.items():
            prs = f" [{' '.join(prs)}]" if prs else ''
            reason = f": {reason}" if reason else ''
            label = names[0] if len(names) == 1 else f'{len(names)} {kind} items'
            lines.append(f'   - {label} ({status}){prs}{reason}')
            if len(names) > 1:
                lines += textwrap.wrap(', '.join(names), 116, initial_indent='       ', subsequent_indent='       ',
                                       break_on_hyphens=False)
    return '\n'.join(lines)


def _main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default=json.loads((ROOT / '.firebaserc').read_text())['projects']['default'])
    parser.add_argument('--json', action='store_true', help='print the same data as JSON')
    args = parser.parse_args(argv)
    items, errors = collect(args.project)
    plan = build_plan(items, args.project)
    head = git('rev-parse', '--short', 'HEAD').strip()
    if args.json:
        print(json.dumps({'project': args.project, 'head': head, 'items': [asdict(i) for i in items],
                          'plan': plan, 'errors': errors}, indent=2))
    else:
        print(f'Deploy drift: {args.project} vs {head}\n')
        print(render_table(items))
        print()
        print(render_plan(plan))
        for error in errors:
            print(f'\nCould not read {error}', file=sys.stderr)
    return 1 if errors else 0


def main(argv=None):
    try:
        return _main(argv)
    except Exception:
        print('Deploy drift: could not complete the check.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
