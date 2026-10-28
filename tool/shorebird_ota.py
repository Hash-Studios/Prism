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
import signal
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
    'pubspec.yaml', 'pubspec.lock', 'shorebird.yaml', '.fvmrc', 'lib/firebase_options.dart',
)
# Data that patched code writes must stay readable by the release code after a rollback.
STORAGE_PATHS = ('lib/core/persistence/', 'lib/core/offline/')
STORAGE_SUFFIXES = ('_local_data_source.dart', '_store.dart')
# SettingsLocalDataSource and SharedPreferences writers live outside the canonical persistence folders.
STORAGE_FILES = (
    'lib/core/account/local_account_data_cleaner.dart',
    'lib/core/account/delete_account_service.dart',
    'lib/core/coins/coins_service.dart',
    'lib/core/coins/pending_download.dart',
    'lib/core/debug/perf_autodrive.dart',
    'lib/core/personalization/taste_signals.dart',
    'lib/core/platform/quick_tile_config_service.dart',
    'lib/core/platform/wallpaper_set_feedback.dart',
    'lib/core/purchases/paywall_orchestrator.dart',
    'lib/core/purchases/upload_quota.dart',
    'lib/core/purchases/purchases_service.dart',
    'lib/core/rating/rate_prompt_service.dart',
    'lib/core/updates/ota_update_controller.dart',
    'lib/core/wallpaper/original_access_service.dart',
    'lib/core/wallpaper/anime_content_filter.dart',
    'lib/core/widgets/popup/changelog_pop_up.dart',
    'lib/core/widgets/menu_button/set_wallpaper_button.dart',
    'lib/features/auto_rotate/data/repositories/auto_rotate_repository_impl.dart',
    'lib/features/debug_panel/views/pages/debug_tools_page.dart',
    'lib/features/in_app_notifications/views/widgets/notification_settings_sheet.dart',
    'lib/features/onboarding_v2/src/common/onboarding_v2_keys.dart',
    'lib/features/onboarding_v2/src/data/repo/onboarding_v2_repo_impl.dart',
    'lib/features/onboarding_v2/src/views/onboarding_v2_shell.dart',
    'lib/features/theme_mode/data/legacy_themes.dart',
    'lib/features/theme_mode/views/pages/theme_view_page.dart',
    'lib/features/startup/services/notification_permission_prompt_service.dart',
    'lib/features/startup/data/repositories/startup_repository_impl.dart',
    'lib/features/startup/views/pages/splash_widget.dart',
    'lib/features/quick_tiles/',
    'lib/features/session/views/pages/settings_screen.dart',
    'lib/features/session/data/low_data_mode.dart',
    'lib/features/session/data/app_session_tracker.dart',
    'lib/features/session/data/report_problem_service.dart',
    'lib/features/theme_mode/data/seasonal_announcement.dart',
    'lib/features/theme_mode/data/repositories/theme_repository_impl.dart',
    'lib/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart',
    'lib/features/personalized_feed/data/personalized_feed_repository_impl.dart',
    'lib/features/personalized_feed/data/feed_impression_store.dart',
    'lib/features/profile_completeness/services/profile_completeness_nudge_service.dart',
    'lib/features/wallpaper_detail/data/downloaded_wall_index.dart',
    'lib/features/wallpaper_detail/views/widgets/clock_overlay.dart',
    'lib/features/user_search/data/wallpaper_search_service.dart',
    'lib/notifications/fcm_token_service.dart',
    'lib/notifications/topic_subscription.dart',
    'lib/notifications/notification_signals.dart',
    'lib/main.dart',
)
IOS_MANUAL_SIGNING_PATH = 'ios/Runner.xcodeproj/project.pbxproj'
IOS_MANUAL_SIGNING_KEYS = ('CODE_SIGN_STYLE', 'DEVELOPMENT_TEAM', 'CODE_SIGN_IDENTITY',
                           'CODE_SIGN_IDENTITY[sdk=iphoneos*]', 'PROVISIONING_PROFILE_SPECIFIER')


def validate_version(version):
    if not isinstance(version, str) or not re.fullmatch(r'\d+\.\d+\.\d+\+\d+', version):
        raise ValueError('Shorebird: pass an exact x.y.z+build release version.')


def option(command, *names):
    found = []
    for index, arg in enumerate(command):
        for name in names:
            if arg.startswith(name + '='):
                found.append(arg.split('=', 1)[1])
                break
            if arg == name and index + 1 < len(command):
                found.append(command[index + 1])
                break
    if len(found) > 1:
        raise ValueError(f'Shorebird: duplicate option {names[0]}.')
    return found[0] if found else None


def validate_command(command, action):
    if '--' in command:
        raise ValueError('Shorebird: an inner -- option separator is not supported.')
    if len(command) < 3 or command[1] != action or command[2] not in PLATFORMS:
        raise ValueError('Shorebird: command must be shorebird release|patch android|ios followed by options.')
    forbidden = {'--dart-define', '--dart-define-from-file', '--public-key-path', '--public-key-cmd',
                 '--private-key-path', '--private-key-cmd', '--sign-cmd', '--no-patch-signing'}
    values = {'--target', '-t', '--flavor', '--split-debug-info', '--export-options-plist', '--export-method'}
    booleans = {'--codesign', '--no-codesign', '--dry-run', '-n', '--no-confirm'}
    if action == 'release':
        values |= {'--flutter-version', '--build-name', '--build-number', '--artifact', '--target-platform'}
        booleans.add('--obfuscate')
    else:
        values |= {'--release-version', '--track', '--channel'}
        forbidden |= {'--build-name', '--build-number', '--target-platform', '--obfuscate', '--flutter-version',
                      '--allow-native-diffs', '--allow-asset-diffs'}
    args = command[3:]
    index = 0
    while index < len(args):
        arg = args[index]
        flag, separator, inline_value = arg.partition('=')
        if flag in forbidden:
            if flag in ('--allow-native-diffs', '--allow-asset-diffs'):
                raise ValueError('Shorebird: native or asset diffs need a store build, not a patch.')
            if action == 'patch' and flag == '--flutter-version':
                raise ValueError('Shorebird: --flutter-version is not supported by the pinned patch CLI.')
            if action == 'patch' and flag in ('--build-name', '--build-number', '--target-platform', '--obfuscate'):
                raise ValueError(f'Shorebird: {flag} is release-managed and cannot be overridden for a patch.')
            raise ValueError('Shorebird: define and signing options are wrapper-managed; do not pass them directly.')
        if flag in booleans:
            if separator:
                raise ValueError(f'Shorebird: {flag} does not take a value.')
        elif flag in values:
            if separator:
                if not inline_value:
                    raise ValueError(f'Shorebird: {flag} needs a value.')
                option_value = inline_value
            else:
                if index + 1 >= len(args) or args[index + 1].startswith('-'):
                    raise ValueError(f'Shorebird: {flag} needs a value.')
                option_value = args[index + 1]
                index += 1
            if any(char in option_value for char in ('\0', '\r', '\n')):
                raise ValueError(f'Shorebird: {flag} has an invalid value.')
        else:
            if flag.startswith('-'):
                raise ValueError(f'Shorebird: unsupported {action} option.')
            raise ValueError(f'Shorebird: unsupported positional argument for {action}.')
        index += 1
    for options in (('--track', '--channel'), ('--release-version',), ('--target', '-t'), ('--flavor',),
                    ('--split-debug-info',), ('--target-platform',), ('--build-name',), ('--build-number',),
                    ('--flutter-version',)):
        option(command, *options)


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
            'flavor': option(command, '--flavor'),
            'target_platform': option(command, '--target-platform')}


def define_fingerprint(define_args):
    pairs = sorted(arg.removeprefix('--dart-define=').split('=', 1) for arg in define_args)
    return {'names': [name for name, _ in pairs],
            'sha256': hashlib.sha256(json.dumps(pairs).encode()).hexdigest()}


def changed_paths(commit):
    if git('cat-file', '-e', f'{commit}^{{commit}}', check=False).returncode:
        raise ValueError(f'Shorebird: release commit {commit} is not in this clone. Fetch full history first.')
    tracked = git('diff', '--no-renames', '--name-only', '-z', commit, '--').stdout.split('\0')
    untracked = git('ls-files', '--others', '--exclude-standard', '-z').stdout.split('\0')
    return sorted({path for path in tracked + untracked if path})


def unsafe_paths(paths):
    native = [p for p in paths if any(p == n or (n.endswith('/') and p.startswith(n)) for n in NATIVE_PATHS)]
    storage = [p for p in paths if p.startswith(STORAGE_PATHS) or p in STORAGE_FILES
               or any(item.endswith('/') and p.startswith(item) for item in STORAGE_FILES)
               or (p.startswith('lib/') and p.endswith(STORAGE_SUFFIXES))]
    return native, storage


def firebase_options_fingerprint(platform):
    options = Path('lib/firebase_options.dart')
    config = Path('android/app/google-services.json' if platform == 'android'
                  else 'ios/Runner/GoogleService-Info.plist')
    if not options.is_file() or not config.is_file():
        raise ValueError('Shorebird: prepared Firebase options are missing.')
    inputs = {'firebase_options.dart': hashlib.sha256(options.read_bytes()).hexdigest(),
              config.name: hashlib.sha256(config.read_bytes()).hexdigest()}
    return hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()


def release_worktree_changes():
    paths = changed_paths('HEAD')
    if not paths:
        return []
    # TestFlight changes only signing settings; xcodeproj also reorders its unchanged object records on save.
    if paths == [IOS_MANUAL_SIGNING_PATH] and ios_manual_signing_only():
        return []
    return paths


def ios_manual_signing_only():
    result = git('diff', 'HEAD', '--no-ext-diff', '--unified=0', '--', IOS_MANUAL_SIGNING_PATH)
    if result.returncode:
        return False
    additions = []
    removals = []
    signing_changes = []
    for line in result.stdout.splitlines():
        if line[:1] not in ('+', '-') or line.startswith(('+++', '---')):
            continue
        content = line[1:].strip()
        if any(content.startswith(prefix + key + prefix + ' =')
               for key in IOS_MANUAL_SIGNING_KEYS for prefix in ('', '"')):
            signing_changes.append(content)
        elif line.startswith('+'):
            additions.append(content)
        else:
            removals.append(content)
    is_xcodeproj_reorder = all(
        re.match(r'^[0-9A-F]{24} /\* [^*]+ \*/ = \{isa = PBX(?:BuildFile|FileReference);', line)
        for line in additions + removals)
    return bool(signing_changes) and sorted(additions) == sorted(removals) and is_xcodeproj_reorder


def effective_sentry(define_args):
    sentry = {}
    for arg in define_args:
        if not arg.startswith('--dart-define='):
            continue
        key, value = arg.removeprefix('--dart-define=').split('=', 1)
        if key in SENTRY_RECORDED and any(char in value for char in ('\0', '\r', '\n')):
            raise ValueError('Shorebird: Sentry values cannot contain line breaks or NUL bytes.')
        if key in SENTRY_RECORDED and value:
            sentry[key] = value
    return sentry


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
    if not isinstance(value, str) or 'KEY-----' not in value or '\0' in value:
        raise ValueError(f'Shorebird: Doppler has no PEM value for {name}.')
    path = Path(directory) / f'{name.lower()}.pem'
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'w') as output:
            output.write(value if value.endswith('\n') else value + '\n')
    except (OSError, UnicodeError):
        raise ValueError(f'Shorebird: invalid PEM value for {name}.') from None
    return str(path)


def environment(payload):
    env = dict(os.environ)
    if not env.get(TOKEN) and isinstance(payload.get(TOKEN), str) and payload[TOKEN]:
        env[TOKEN] = payload[TOKEN]
    token = env.get(TOKEN, '')
    if token and (not token.isascii() or any(not 0x21 <= ord(char) <= 0x7e for char in token)):
        raise ValueError('Shorebird: invalid SHOREBIRD_TOKEN; use a printable ASCII token without whitespace.')
    return env


def release(command, platform, payload, defines, keys):
    validate_command(command, 'release')
    dirty = release_worktree_changes()
    if dirty:
        raise ValueError('Shorebird: release requires a clean working tree; changed inputs:\n  ' + '\n  '.join(dirty))
    version = release_version(command)
    validate_version(version)
    tag = tag_name(platform, version)
    if git('rev-parse', '-q', '--verify', f'refs/tags/{tag}', check=False).returncode == 0:
        raise ValueError(f'Shorebird: {tag} already exists. Release {version} was already made for {platform}.')
    flutter = option(command, '--flutter-version')
    if flutter != pinned_flutter():
        raise ValueError(f'Shorebird: pass --flutter-version={pinned_flutter()} (the .fvmrc pin).')
    define_args = defines(payload)
    sentry = effective_sentry(define_args)
    firebase_options = firebase_options_fingerprint(platform)
    signing = [f'--public-key-path={key_file(keys, payload, PUBLIC_KEY)}']
    code = subprocess.run(command + signing + define_args, env=environment(payload)).returncode
    if code:
        return code
    if '--dry-run' in command or '-n' in command:
        return 0
    record = {'schema': 2, 'platform': platform, 'release_version': version,
              'commit': git('rev-parse', 'HEAD').stdout.strip(), 'cli_version': CLI_VERSION,
              'obfuscate': '--obfuscate' in command, 'config': build_config(command, flutter),
              'defines': define_fingerprint(define_args),
              'firebase_options_sha256': firebase_options,
              'sentry': sentry}
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
    validate_version(version)
    tag = tag_name(platform, version)
    ref = f'refs/tags/{tag}'
    if git('show-ref', '--verify', '--quiet', ref, check=False).returncode:
        raise ValueError(f"Shorebird: no release record {tag}. Run: git fetch origin 'refs/tags/shorebird/*:refs/tags/shorebird/*'")
    if git('cat-file', '-t', ref).stdout.strip() != 'tag':
        raise ValueError(f'Shorebird: {tag} is not an annotated release record.')
    body = git('tag', '-l', '--format=%(contents)', tag).stdout
    try:
        record = json.loads(body)
    except (ValueError, TypeError):
        raise ValueError(f'Shorebird: {tag} is not a release record.') from None
    validate_record(record, platform, version, tag)
    return record


def validate_record(record, platform, version, tag):
    expected_keys = {'schema', 'platform', 'release_version', 'commit', 'cli_version', 'obfuscate', 'config',
                     'defines', 'firebase_options_sha256', 'sentry'}
    if not isinstance(record, dict) or set(record) != expected_keys \
            or record.get('schema') != 2 or record.get('platform') != platform \
            or record.get('release_version') != version or record.get('cli_version') != CLI_VERSION:
        raise ValueError('invalid release record')
    commit = record.get('commit')
    if not isinstance(commit, str) or not re.fullmatch(r'[0-9a-f]{40,64}', commit):
        raise ValueError('invalid release record')
    if git('rev-parse', f'refs/tags/{tag}^{{commit}}').stdout.strip() != commit:
        raise ValueError('record commit does not match the annotated release tag')
    if git('merge-base', '--is-ancestor', commit, 'HEAD', check=False).returncode:
        raise ValueError('release record commit is not an ancestor of HEAD')
    config = record.get('config')
    if not isinstance(config, dict) or set(config) != {'flutter_version', 'split_debug_info', 'target', 'flavor',
                                                      'target_platform'} \
            or not isinstance(config['flutter_version'], str) or not isinstance(config['split_debug_info'], bool) \
            or any(char in config['flutter_version'] for char in ('\0', '\r', '\n')) \
            or not isinstance(config['target'], str) \
            or any(char in config['target'] for char in ('\0', '\r', '\n')) \
            or (config['flavor'] is not None
                                                          and not isinstance(config['flavor'], str)) \
            or (isinstance(config['flavor'], str)
                and any(char in config['flavor'] for char in ('\0', '\r', '\n'))) \
            or (config['target_platform'] is not None and not isinstance(config['target_platform'], str)) \
            or (isinstance(config['target_platform'], str)
                and any(char in config['target_platform'] for char in ('\0', '\r', '\n'))):
        raise ValueError('invalid release record')
    defines = record.get('defines')
    if not isinstance(defines, dict) or set(defines) != {'names', 'sha256'} \
            or not isinstance(defines.get('names'), list) \
            or any(not isinstance(name, str) for name in defines['names']) \
            or not isinstance(defines.get('sha256'), str) \
            or not re.fullmatch(r'[0-9a-f]{64}', defines['sha256']):
        raise ValueError('invalid release record')
    if len(defines['names']) != len(set(defines['names'])):
        raise ValueError('invalid release record')
    if not isinstance(record.get('obfuscate'), bool):
        raise ValueError('invalid release record')
    sentry = record.get('sentry')
    if not isinstance(sentry, dict) or any(key not in SENTRY_RECORDED or not isinstance(value, str)
                                           or any(char in value for char in ('\0', '\r', '\n'))
                                           for key, value in sentry.items()):
        raise ValueError('invalid release record')
    firebase_options = record.get('firebase_options_sha256')
    if not isinstance(firebase_options, str) or not re.fullmatch(r'[0-9a-f]{64}', firebase_options):
        raise ValueError('invalid release record')


def patch(command, platform, payload, defines, keys, allow_storage):
    validate_command(command, 'patch')
    version = option(command, '--release-version')
    if not version or version == 'latest':
        raise ValueError('Shorebird: pass the exact --release-version of the store build (not latest).')
    validate_version(version)
    track = option(command, '--track', '--channel')
    if not track or track == 'stable':
        raise ValueError('Shorebird: patch to a test track such as staging. Promote to stable as a separate step.')
    record = read_record(platform, version)
    define_args = defines(payload, sentry_overrides=record['sentry'])
    if firebase_options_fingerprint(platform) != record['firebase_options_sha256']:
        raise ValueError('Shorebird: prepared Firebase options differ from the release.')
    expected = (record['config'], record['defines']['sha256'])
    actual_config = build_config(command, pinned_flutter())
    # The pinned CLI inherits a release's target architectures; patch exposes no target-platform override.
    actual_config['target_platform'] = record['config']['target_platform']
    actual = (actual_config, define_fingerprint(define_args)['sha256'])
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
    if action.startswith('-') and action not in ('--help', '--version'):
        raise ValueError('Shorebird: global CLI options before the command are not allowed.')
    if action not in ('release', 'patch'):
        if any(arg in ('release', 'patch') for arg in command[2:]):
            raise ValueError('Shorebird: global CLI options before release or patch are not allowed.')
        return subprocess.run(command, env=environment(payload)).returncode
    platform = command[2] if len(command) > 2 else ''
    if platform not in PLATFORMS or platform != release_platform:
        raise ValueError('Shorebird: pass one platform, android or ios, and the same --release-platform.')
    check_environment(command[0])
    old_sigterm_handler = signal.getsignal(signal.SIGTERM)

    def terminate(signum, frame):
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGTERM, terminate)
    try:
        with tempfile.TemporaryDirectory(prefix='prism-shorebird-') as keys:
            if action == 'release':
                return release(command, platform, payload, defines, keys)
            return patch(command, platform, payload, defines, keys, allow_storage)
    finally:
        signal.signal(signal.SIGTERM, old_sigterm_handler)


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
