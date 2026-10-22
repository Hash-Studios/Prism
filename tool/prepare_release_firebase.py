#!/usr/bin/env python3
"""Validate native Firebase config and derive selected-platform Dart options."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys


PROJECT = 'prism-wallpapers'
APP = 'com.hash.prism'
NATIVE = {'android': Path('android/app/google-services.json'),
          'ios': Path('ios/Runner/GoogleService-Info.plist')}


def require(condition):
    if not condition:
        raise ValueError('Release Firebase configuration is invalid for prism-wallpapers / com.hash.prism / selected platform.')


def options(platform, content):
    try:
        if platform == 'android':
            data = json.loads(content)
            info = data['project_info']
            clients = [client for client in data['client']
                       if client['client_info']['android_client_info']['package_name'] == APP]
            require(len(clients) == 1)
            client = clients[0]
            result = {'apiKey': client['api_key'][0]['current_key'],
                      'appId': client['client_info']['mobilesdk_app_id'],
                      'messagingSenderId': info['project_number'], 'projectId': info['project_id'],
                      'storageBucket': info['storage_bucket']}
        else:
            data = plistlib.loads(content)
            require(data['BUNDLE_ID'] == APP)
            result = {'apiKey': data['API_KEY'], 'appId': data['GOOGLE_APP_ID'],
                      'messagingSenderId': data['GCM_SENDER_ID'], 'projectId': data['PROJECT_ID'],
                      'storageBucket': data['STORAGE_BUCKET'], 'iosBundleId': data['BUNDLE_ID']}
            if data.get('CLIENT_ID'):
                result['iosClientId'] = data['CLIENT_ID']
        require(all(isinstance(value, str) and value for value in result.values()))
        require(result['projectId'] == PROJECT)
        sender = result['messagingSenderId']
        require(re.fullmatch(r'[1-9][0-9]{5,}', sender))
        require(re.fullmatch(rf'1:{sender}:{platform}:[0-9a-f]{{16,}}', result['appId']))
        require(set(result['appId'].rsplit(':', 1)[1]) != {'0'})
        require(re.fullmatch(r'AIza[A-Za-z0-9_-]{35}', result['apiKey']))
        require(result['storageBucket'] in (f'{PROJECT}.appspot.com', f'{PROJECT}.firebasestorage.app'))
        return result
    except (KeyError, IndexError, TypeError, ValueError, AttributeError, plistlib.InvalidFileException):
        raise ValueError('Release Firebase configuration is invalid for prism-wallpapers / com.hash.prism / selected platform.') from None


def dart_string(value):
    return "'" + value.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n').replace('\r', '\\r') + "'"


def private_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('wb') as output:
        os.chmod(path, 0o600)
        output.write(content)


def prepare(platform, source=None):
    path = NATIVE[platform]
    if source == 'doppler':
        require(platform == 'android')
        result = subprocess.run([
            'doppler', 'secrets', 'get', 'FIREBASE_SECRET', '--plain',
            '--project', os.environ.get('DOPPLER_PROJECT', 'prism'),
            '--config', os.environ.get('DOPPLER_CONFIG', 'prd'),
        ], capture_output=True)
        if result.returncode:
            print('Release Firebase preparation failed: cannot read FIREBASE_SECRET.', file=sys.stderr)
            raise SystemExit(result.returncode)
        content = result.stdout
    elif source == 'environment':
        require(platform == 'ios')
        value = os.environ.get('IOS_GOOGLE_SERVICE_INFO_PLIST', '')
        if not value.strip():
            raise ValueError('Release Firebase prerequisite missing: IOS_GOOGLE_SERVICE_INFO_PLIST must contain the real iOS plist.')
        content = value.encode()
    else:
        if not path.is_file():
            raise ValueError(f'Release Firebase prerequisite missing: {path}. See docs/development/doppler.md.')
        content = path.read_bytes()
    values = options(platform, content)
    fields = '\n'.join(f'    {key}: {dart_string(value)},' for key, value in values.items())
    dart_platform = 'iOS' if platform == 'ios' else platform  # Dart's enum value is TargetPlatform.iOS.
    dart = f'''// Generated from validated native Firebase config. Do not commit.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {{
  static FirebaseOptions get currentPlatform {{
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.{dart_platform}) {{
      return {platform};
    }}
    throw UnsupportedError('Firebase configuration was prepared only for {platform}.');
  }}

  static const FirebaseOptions {platform} = FirebaseOptions(
{fields}
  );
}}
'''
    # Parse and validate everything before replacing either generated file.
    private_write(path, content)
    private_write(Path('lib/firebase_options.dart'), dart.encode())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=('android', 'ios'))
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--from-doppler', action='store_true', help='Android FIREBASE_SECRET only')
    group.add_argument('--from-environment', action='store_true', help='iOS IOS_GOOGLE_SERVICE_INFO_PLIST only')
    args = parser.parse_args()
    prepare(args.platform, 'doppler' if args.from_doppler else 'environment' if args.from_environment else None)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print(str(error) if isinstance(error, ValueError) else 'Release Firebase preparation failed: configuration file unavailable.',
              file=sys.stderr)
        sys.exit(1)
