#!/usr/bin/env python3
"""Validate the iOS AdMob identifiers before a release build."""

import base64
import os
import re
import sys


def validate(app_id, unit_id):
    for value, separator, android_id in (
        (app_id, '~', 'ca-app-pub-4649644680694757~6175744196'),
        (unit_id, '/', 'ca-app-pub-4649644680694757/3358009164'),
    ):
        if (not isinstance(value, str)
            or not re.fullmatch(r'ca-app-pub-[0-9]{16}' + separator + r'[0-9]{10}', value)
            or value.startswith('ca-app-pub-3940256099942544')
            or value == android_id):
            raise ValueError('Release configuration failed: valid iOS AdMob app and rewarded unit IDs are required.')


def main():
    if os.environ.get('CONFIGURATION') != 'Release':
        return
    try:
        defines = [base64.b64decode(value, validate=True).decode('utf-8')
                   for value in os.environ.get('DART_DEFINES', '').split(',') if value]
        prefix = 'ADMOB_IOS_REWARDED_AD_UNIT_ID='
        units = [value[len(prefix):] for value in defines if value.startswith(prefix)]
        validate(os.environ.get('ADMOB_IOS_APP_ID', ''), units[0] if len(units) == 1 else '')
    except (ValueError, UnicodeError):
        print('error: Release requires valid iOS AdMob app and rewarded unit IDs.', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
