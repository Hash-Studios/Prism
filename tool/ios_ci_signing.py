"""Install CI App Store provisioning profiles and write the matching ExportOptions.plist.

Every non-empty environment variable whose name ends in PROVISIONING_PROFILE_BASE64 is one profile.
Secret values are never printed.
"""

import argparse
import base64
import json
import os
from pathlib import Path
import plistlib
import re
import sys
from xml.parsers.expat import ExpatError


SUFFIX = 'PROVISIONING_PROFILE_BASE64'
# Xcode 16 and newer read UserData. Older Xcode reads MobileDevice.
PROFILE_DIRS = ('Library/MobileDevice/Provisioning Profiles', 'Library/Developer/Xcode/UserData/Provisioning Profiles')


class SigningError(Exception):
    pass


def read_profile(secret, value):
    try:
        data = base64.b64decode(''.join(value.split()), validate=True)
        match = re.search(rb'<\?xml.*?</plist>', data, re.DOTALL)
        profile = plistlib.loads(match.group())
        team = profile['TeamIdentifier'][0]
        entitlements = profile['Entitlements']
        # The App ID prefix can differ from the team ID on older App IDs.
        bundle_id = entitlements['application-identifier'].split('.', 1)[1]
        info = {'secret': secret, 'bundle_id': bundle_id, 'name': profile['Name'], 'uuid': profile['UUID'],
                'team_id': team}
    except (AttributeError, ExpatError, KeyError, IndexError, TypeError, ValueError) as error:
        raise SigningError(f'{secret} is not a base64 provisioning profile ({type(error).__name__}).') from None
    if profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices') or entitlements.get('get-task-allow'):
        raise SigningError(f'{secret} holds "{info["name"]}", which is not an App Store profile.')
    return info, data


def install(environ, home, export_options, manifest):
    profiles = [read_profile(name, environ[name]) for name in sorted(environ)
                if name.endswith(SUFFIX) and environ[name].strip()]
    if not profiles:
        raise SigningError(f'No provisioning profile secrets found (environment names ending in {SUFFIX}).')
    by_bundle = {}
    for info, _ in profiles:
        if info['bundle_id'] in by_bundle:
            raise SigningError(f'{by_bundle[info["bundle_id"]]["secret"]} and {info["secret"]} both sign '
                               f'{info["bundle_id"]}.')
        by_bundle[info['bundle_id']] = info
    teams = {info['team_id'] for info, _ in profiles}
    if len(teams) != 1:
        raise SigningError(f'Provisioning profiles span teams {sorted(teams)}.')

    files = [(Path(home) / directory / f'{info["uuid"]}.mobileprovision', data)
             for directory in PROFILE_DIRS for info, data in profiles]
    entries = [{key: info[key] for key in ('bundle_id', 'name', 'uuid', 'team_id')} for info, _ in profiles]
    # The manifest goes first so that cleanup finds every profile file, even after a partial install.
    Path(manifest).write_text(json.dumps({'profiles': entries, 'paths': [str(path) for path, _ in files]},
                                         indent=2) + '\n')
    for path, data in files:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    Path(export_options).write_bytes(plistlib.dumps({
        'method': 'app-store-connect',
        'teamID': teams.pop(),
        'signingStyle': 'manual',
        'provisioningProfiles': {bundle: info['uuid'] for bundle, info in sorted(by_bundle.items())},
    }))
    for info in entries:
        print(f'Installed "{info["name"]}" for {info["bundle_id"]}.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export-options', required=True, help='ExportOptions.plist to write')
    parser.add_argument('--manifest', required=True, help='JSON list of installed profiles and files to write')
    args = parser.parse_args()
    try:
        install(os.environ, Path.home(), args.export_options, args.manifest)
    except SigningError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
