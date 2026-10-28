#!/usr/bin/env python3
"""Shorebird release records and patch safety checks. tool/flutter_with_doppler.py runs every shorebird command here.

A release is recorded in an annotated git tag, shorebird/<platform>/<release version>, on the release commit. The
tag message is JSON: the build config fingerprint and the Sentry values. A patch reads that tag, refuses a different
build config, and refuses a diff since the release that a patch cannot ship.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


CLI_VERSION = '1.6.133'
PLACEHOLDER_APP_ID = 'REPLACE_WITH_SHOREBIRD_APP_ID'
PUBLIC_KEY = 'SHOREBIRD_PATCH_PUBLIC_KEY'
PRIVATE_KEY = 'SHOREBIRD_PATCH_PRIVATE_KEY'
TOKEN = 'SHOREBIRD_TOKEN'
SENTRY_RECORDED = ('SENTRY_ENV', 'SENTRY_RELEASE', 'SENTRY_DIST', 'SENTRY_ENABLED')
PLATFORMS = ('android', 'ios')

# A patch replaces Dart code only. A change under these paths needs a store build.
NATIVE_PATHS = (
    'android/', 'ios/', 'packages/', 'pigeons/', 'lib/core/platform/pigeon/', 'assets/', 'shaders/',
    'pubspec.yaml', 'pubspec.lock', 'shorebird.yaml', '.fvmrc',
)
# Data that patched code writes must stay readable by the release code after a rollback.
STORAGE_PATHS = ('lib/core/persistence/', 'lib/core/offline/')
STORAGE_SUFFIXES = ('_local_data_source.dart', '_store.dart')


def option(command, *names):
    for index, arg in enumerate(command):
        for name in names:
            if arg.startswith(name + '='):
                return arg.split('=', 1)[1]
            if arg == name and index + 1 < len(command):
                return command[index + 1]
    return None


def git(*args, check=True):
    result = subprocess.run(['git', *args], capture_output=True, text=True)
    if check and result.returncode:
        raise ValueError(f'Shorebird: git {args[0]} failed: {result.stderr.strip()}')
    return result


def pinned_flutter():
    return json.loads(Path('.fvmrc').read_text())['flutter']


def release_version(command):
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', Path('pubspec.yaml').read_text(), re.MULTILINE)
    if not match:
        raise ValueError('Shorebird: pubspec.yaml has no x.y.z+n version.')
    return f"{option(command, '--build-name') or match[1]}+{option(command, '--build-number') or match[2]}"


def tag_name(platform, version):
    return f'shorebird/{platform}/{version}'


def build_config(command, flutter_version):
    """The settings a patch must share with its release. Shorebird copies --obfuscate to patches by itself."""
    return {'flutter_version': flutter_version,
            'split_debug_info': option(command, '--split-debug-info') is not None,
            'target': option(command, '--target', '-t') or 'lib/main.dart',
            'flavor': option(command, '--flavor')}


def define_fingerprint(define_args):
    pairs = sorted(arg.removeprefix('--dart-define=').split('=', 1) for arg in define_args)
    return {'names': [name for name, _ in pairs],
            'sha256': hashlib.sha256(json.dumps(pairs).encode()).hexdigest()}


def changed_paths(commit):
    if git('cat-file', '-e', f'{commit}^{{commit}}', check=False).returncode:
        raise ValueError(f'Shorebird: release commit {commit} is not in this clone. Fetch full history first.')
    tracked = git('diff', '--name-only', commit, '--').stdout.split('\n')
    untracked = git('ls-files', '--others', '--exclude-standard').stdout.split('\n')
    return sorted({path for path in tracked + untracked if path})


def unsafe_paths(paths):
    native = [p for p in paths if any(p == n or (n.endswith('/') and p.startswith(n)) for n in NATIVE_PATHS)]
    storage = [p for p in paths if p.startswith(STORAGE_PATHS) or (p.startswith('lib/') and p.endswith(STORAGE_SUFFIXES))]
    return native, storage


def check_environment(shorebird):
    result = subprocess.run([shorebird, '--version'], capture_output=True, text=True)
    found = re.search(r'Shorebird (\S+)', result.stdout)
    if result.returncode or not found or found[1] != CLI_VERSION:
        raise ValueError(f'Shorebird: CLI {CLI_VERSION} is required (pinned in tool/shorebird_ota.py).')
    app_id = re.search(r'^app_id:\s*(\S+)', Path('shorebird.yaml').read_text(), re.MULTILINE)
    if not app_id or app_id[1] == PLACEHOLDER_APP_ID:
        raise ValueError('Shorebird: shorebird.yaml has no app_id. Put the Shorebird Cloud app id there first.')


def key_file(directory, payload, name):
    value = payload.get(name, '')
    if not isinstance(value, str) or 'KEY-----' not in value:
        raise ValueError(f'Shorebird: Doppler has no PEM value for {name}.')
    path = Path(directory) / f'{name.lower()}.pem'
    with path.open('w') as output:
        os.chmod(path, 0o600)
        output.write(value if value.endswith('\n') else value + '\n')
    return str(path)


def environment(payload):
    env = dict(os.environ)
    if not env.get(TOKEN) and isinstance(payload.get(TOKEN), str) and payload[TOKEN]:
        env[TOKEN] = payload[TOKEN]
    return env


def release(command, platform, payload, defines, keys):
    version = release_version(command)
    tag = tag_name(platform, version)
    if git('rev-parse', '-q', '--verify', f'refs/tags/{tag}', check=False).returncode == 0:
        raise ValueError(f'Shorebird: {tag} already exists. Release {version} was already made for {platform}.')
    flutter = option(command, '--flutter-version')
    if flutter != pinned_flutter():
        raise ValueError(f'Shorebird: pass --flutter-version={pinned_flutter()} (the .fvmrc pin).')
    define_args = defines(payload)
    signing = [f'--public-key-path={key_file(keys, payload, PUBLIC_KEY)}']
    code = subprocess.run(command + signing + define_args, env=environment(payload)).returncode
    if code:
        return code
    record = {'schema': 1, 'platform': platform, 'release_version': version,
              'commit': git('rev-parse', 'HEAD').stdout.strip(), 'cli_version': CLI_VERSION,
              'obfuscate': '--obfuscate' in command, 'config': build_config(command, flutter),
              'defines': define_fingerprint(define_args),
              'sentry': {key: os.environ[key] for key in SENTRY_RECORDED if os.environ.get(key)}}
    env = dict(os.environ)
    if not git('config', 'user.email', check=False).stdout.strip():
        env.setdefault('GIT_COMMITTER_NAME', 'Prism release')
        env.setdefault('GIT_COMMITTER_EMAIL', 'release@prism.invalid')
    tagged = subprocess.run(['git', 'tag', '-a', tag, '-m', json.dumps(record, indent=2, sort_keys=True), 'HEAD'],
                            env=env, capture_output=True, text=True)
    if tagged.returncode:
        raise ValueError(f'Shorebird: release uploaded, but tag {tag} failed: {tagged.stderr.strip()}')
    out = Path('build/shorebird')
    out.mkdir(parents=True, exist_ok=True)
    (out / f'release-tag-{platform}').write_text(tag + '\n')
    return 0


def read_record(platform, version):
    tag = tag_name(platform, version)
    if git('rev-parse', '-q', '--verify', f'refs/tags/{tag}', check=False).returncode:
        raise ValueError(f"Shorebird: no release record {tag}. Run: git fetch origin 'refs/tags/shorebird/*:refs/tags/shorebird/*'")
    body = git('tag', '-l', '--format=%(contents)', tag).stdout
    try:
        return json.loads(body)
    except ValueError:
        raise ValueError(f'Shorebird: {tag} is not a release record.') from None


def patch(command, platform, payload, defines, keys, allow_storage):
    version = option(command, '--release-version')
    if not version or version == 'latest':
        raise ValueError('Shorebird: pass the exact --release-version of the store build (not latest).')
    track = option(command, '--track', '--channel')
    if not track or track == 'stable':
        raise ValueError('Shorebird: patch to a test track such as staging. Promote to stable as a separate step.')
    if {'--allow-native-diffs', '--allow-asset-diffs'} & set(command):
        raise ValueError('Shorebird: native or asset diffs need a store build, not a patch.')
    record = read_record(platform, version)
    for key, value in record.get('sentry', {}).items():
        os.environ[key] = value
    define_args = defines(payload)
    expected = (record['config'], record['defines']['sha256'])
    actual = (build_config(command, pinned_flutter()), define_fingerprint(define_args)['sha256'])
    if actual != expected:
        changed = [key for key in expected[0] if expected[0][key] != actual[0].get(key)]
        if expected[1] != actual[1]:
            changed.append('dart-define names or values')
        raise ValueError(f"Shorebird: build config differs from release {version}: {', '.join(changed)}.")
    native, storage = unsafe_paths(changed_paths(record['commit']))
    if native:
        raise ValueError('Shorebird: these changes since the release need a store build:\n  ' + '\n  '.join(native))
    if storage and not allow_storage:
        raise ValueError('Shorebird: these changes touch local storage. A rollback runs the release code on data this '
                         'patch writes. Check that both read it, then pass --allow-storage-changes:\n  '
                         + '\n  '.join(storage))
    if storage:
        print('WARNING: this patch changes local storage code. Release code must still read its data after a '
              'rollback:\n  ' + '\n  '.join(storage), file=sys.stderr)
    signing = [f'--public-key-path={key_file(keys, payload, PUBLIC_KEY)}',
               f'--private-key-path={key_file(keys, payload, PRIVATE_KEY)}']
    return subprocess.run(command + signing + define_args, env=environment(payload)).returncode


def run(command, release_platform, payload, defines, allow_storage=False):
    """Runs a shorebird command with signing keys, the CI token and the app defines from the Doppler payload."""
    action = command[1] if len(command) > 1 else ''
    if action not in ('release', 'patch'):
        return subprocess.run(command, env=environment(payload)).returncode
    platform = command[2] if len(command) > 2 else ''
    if platform not in PLATFORMS or platform != release_platform:
        raise ValueError('Shorebird: pass one platform, android or ios, and the same --release-platform.')
    check_environment(command[0])
    with tempfile.TemporaryDirectory(prefix='prism-shorebird-') as keys:
        if action == 'release':
            return release(command, platform, payload, defines, keys)
        return patch(command, platform, payload, defines, keys, allow_storage)


def main():
    parser = argparse.ArgumentParser(description='Shorebird helpers for the Makefile and CI.')
    sub = parser.add_subparsers(dest='action', required=True)
    sub.add_parser('cli-version')
    check = sub.add_parser('check-paths', help='List changes since a release commit that a patch cannot ship.')
    check.add_argument('commit')
    args = parser.parse_args()
    if args.action == 'cli-version':
        print(CLI_VERSION)
        return 0
    native, storage = unsafe_paths(changed_paths(args.commit))
    for path in native:
        print(f'store build: {path}')
    for path in storage:
        print(f'storage: {path}')
    return 1 if native else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except ValueError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
