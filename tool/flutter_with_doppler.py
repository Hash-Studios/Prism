#!/usr/bin/env python3
"""Run Flutter with allowlisted Doppler values passed directly as argv."""

import argparse
import json
import os
import subprocess
import sys

from prepare_release_firebase import prepare
from check_ios_admob import validate


# Only shipping app settings read by Env. Exclude backend credentials and
# development switches. Keep this list in sync with Env.
APP_KEYS = (
    'GH_REPO_WALLS', 'GH_USERNAME', 'R2_PREVIEW_BASE_URL',
    'RC_API_KEY', 'RC_ANDROID_API_KEY', 'RC_IOS_API_KEY', 'PEXELS_API_KEY', 'META_APP_ID',
    'SENTRY_DSN', 'SENTRY_ENV', 'SENTRY_RELEASE', 'SENTRY_DIST', 'SENTRY_ENABLED',
    'MIXPANEL_TOKEN', 'MIXPANEL_ENABLED',
    'ADMOB_IOS_REWARDED_AD_UNIT_ID',
)
SENTRY_OVERRIDES = ('SENTRY_DSN', 'SENTRY_ENV', 'SENTRY_RELEASE', 'SENTRY_DIST', 'SENTRY_ENABLED')


def defines(release_platform):
    result = subprocess.run([
        'doppler', 'secrets', 'download', '--no-file', '--no-fallback', '--format', 'json',
        '--project', os.environ.get('DOPPLER_PROJECT', 'prism'),
        '--config', os.environ.get('DOPPLER_CONFIG', 'dev'),
    ], capture_output=True)
    if result.returncode:
        print('App configuration failed: Doppler download failed.', file=sys.stderr)
        raise SystemExit(result.returncode)
    try:
        payload = json.loads(result.stdout)
        if not isinstance(payload, dict):
            raise ValueError()
        args = []
        for key in APP_KEYS:
            value = payload.get(key, '')
            if key in SENTRY_OVERRIDES and os.environ.get(key):
                value = os.environ[key]
            if not isinstance(value, str) or '\0' in value:
                raise ValueError()
            if value:
                args.append(f'--dart-define={key}={value}')
    except (ValueError, TypeError):
        raise ValueError('App configuration failed: invalid Doppler JSON or app value.') from None
    native_app_id = payload.get('ADMOB_IOS_APP_ID', '')
    if release_platform == 'ios':
        validate(native_app_id, payload.get('ADMOB_IOS_REWARDED_AD_UNIT_ID', ''))
    return args, native_app_id


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release-platform', choices=('android', 'ios'))
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command[:1] == ['--']:
        command = command[1:]
    if not command:
        parser.error('a command is required after --')
    if args.release_platform:
        if any(arg.startswith(('--dart-define=SKIP_FIREBASE_INIT=', '--dart-define-from-file'))
               or arg == '--dart-define' for arg in command):
            raise ValueError('Release configuration failed: unchecked define files and Firebase skip flags are forbidden.')
        prepare(args.release_platform)
    dart_defines, app_id = defines(args.release_platform)
    env = os.environ.copy()
    if args.release_platform == 'ios':
        env['PRISM_ADMOB_IOS_APP_ID'] = app_id
    return subprocess.run(command + dart_defines, env=env).returncode


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        message = str(error) if isinstance(error, ValueError) else 'App configuration failed: required command or file unavailable.'
        print(message, file=sys.stderr)
        sys.exit(1)
