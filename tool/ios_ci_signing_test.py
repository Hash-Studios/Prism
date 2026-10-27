"""Behavioral fixtures for the CI iOS signing helpers. No network, credentials, signing or builds."""

import base64
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SIGNING = ROOT / 'tool/ios_ci_signing.py'
MANUAL_SIGNING = ROOT / 'tool/ios_ci_manual_signing.rb'
PROJECT = ROOT / 'ios/Runner.xcodeproj'
TEAM = 'X2955Z4CKQ'
APP = 'com.hash.prism'
LIVE = 'com.hash.prism.LiveActivities'
APP_PROFILE = 'Prism App Store'
LIVE_PROFILE = 'Prism Live Activities App Store'
APP_SECRET = 'IOS_PROVISIONING_PROFILE_BASE64'
LIVE_SECRET = 'IOS_LIVE_ACTIVITIES_PROVISIONING_PROFILE_BASE64'
MOBILE_DIR = 'Library/MobileDevice/Provisioning Profiles'
XCODE_DIR = 'Library/Developer/Xcode/UserData/Provisioning Profiles'
DUMP_SETTINGS = '''
project = Xcodeproj::Project.open(ARGV.fetch(0))
keys = %w[CODE_SIGN_STYLE PROVISIONING_PROFILE_SPECIFIER CODE_SIGN_IDENTITY DEVELOPMENT_TEAM]
result = project.native_targets.to_h do |target|
  configs = target.build_configurations.to_h do |config|
    [config.name, keys.to_h { |key| [key, config.build_settings[key]] }]
  end
  [target.name, configs]
end
puts JSON.generate(result)
'''
MANUAL_PROFILES = [
    {'bundle_id': APP, 'name': APP_PROFILE, 'uuid': 'AAAA-1', 'team_id': TEAM},
    {'bundle_id': LIVE, 'name': LIVE_PROFILE, 'uuid': 'BBBB-2', 'team_id': TEAM},
]


def plist_profile(plist):
    return b'\x30\x82junk' + plistlib.dumps(plist) + b'\x00trailer'


def profile_bytes(bundle_id, name, uuid, team=TEAM, **extra):
    return plist_profile({'Name': name, 'UUID': uuid, 'TeamIdentifier': [team],
                          'Entitlements': {'application-identifier': f'{team}.{bundle_id}', 'get-task-allow': False},
                          **extra})


def debug_profile_bytes():
    return plist_profile({'Name': 'Prism Debug', 'UUID': 'DDDD-4', 'TeamIdentifier': [TEAM],
                          'Entitlements': {'application-identifier': f'{TEAM}.{APP}', 'get-task-allow': True}})


def encode(data):
    return base64.b64encode(data).decode()


class IosCiSigningTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='prism-ios-signing-test-')
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.home = self.work / 'home'
        self.home.mkdir()
        self.export_options = self.work / 'ExportOptions.plist'
        self.manifest = self.work / 'm.json'

    def run_signing(self, secrets):
        env = {'PATH': os.environ['PATH'], 'HOME': str(self.home), **secrets}
        return subprocess.run([sys.executable, str(SIGNING), '--export-options', str(self.export_options),
                               '--manifest', str(self.manifest)],
                              cwd=ROOT, env=env, capture_output=True, text=True)

    def test_installs_app_store_profiles_into_both_xcode_dirs(self):
        app = profile_bytes(APP, APP_PROFILE, 'AAAA-1')
        live = profile_bytes(LIVE, LIVE_PROFILE, 'BBBB-2')
        result = self.run_signing({APP_SECRET: encode(app), LIVE_SECRET: encode(live),
                                   'IOS_WIDGETS_PROVISIONING_PROFILE_BASE64': '',
                                   'IOS_NOTIFICATION_PROVISIONING_PROFILE_BASE64': '  \n'})
        self.assertEqual(result.returncode, 0, result.stderr)
        for directory in (MOBILE_DIR, XCODE_DIR):
            self.assertEqual((self.home / directory / 'AAAA-1.mobileprovision').read_bytes(), app)
            self.assertEqual((self.home / directory / 'BBBB-2.mobileprovision').read_bytes(), live)
        self.assertEqual(sorted(p for p in self.home.rglob('*') if p.is_file()), sorted(
            self.home / directory / f'{uuid}.mobileprovision'
            for directory in (MOBILE_DIR, XCODE_DIR) for uuid in ('AAAA-1', 'BBBB-2')))
        self.assertEqual(plistlib.loads(self.export_options.read_bytes()), {
            'method': 'app-store-connect',
            'teamID': TEAM,
            'signingStyle': 'manual',
            'provisioningProfiles': {APP: 'AAAA-1', LIVE: 'BBBB-2'},
        })
        manifest = json.loads(self.manifest.read_text())
        self.assertEqual(sorted(manifest['paths']), sorted(
            str(self.home / directory / f'{uuid}.mobileprovision')
            for directory in (MOBILE_DIR, XCODE_DIR) for uuid in ('AAAA-1', 'BBBB-2')))
        self.assertEqual(sorted(profile['bundle_id'] for profile in manifest['profiles']), [APP, LIVE])

    def test_installs_base64_wrapped_at_76_columns(self):
        app = profile_bytes(APP, APP_PROFILE, 'AAAA-1')
        wrapped = base64.encodebytes(app).decode()
        self.assertIn('\n', wrapped.strip())
        result = self.run_signing({APP_SECRET: wrapped})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / MOBILE_DIR / 'AAAA-1.mobileprovision').read_bytes(), app)

    def test_only_empty_secrets_fails_without_manifest(self):
        result = self.run_signing({APP_SECRET: '', 'IOS_WIDGETS_PROVISIONING_PROFILE_BASE64': '  \n'})
        self.assertEqual(result.returncode, 1)
        self.assertIn('PROVISIONING_PROFILE_BASE64', result.stderr)
        self.assertFalse(self.manifest.exists())

    def test_invalid_base64_names_variable_without_echoing_value(self):
        result = self.run_signing({APP_SECRET: 'not-base64!!secretvalue'})
        self.assertEqual(result.returncode, 1)
        self.assertIn(APP_SECRET, result.stderr)
        self.assertNotIn('secretvalue', result.stderr)
        self.assertNotIn('secretvalue', result.stdout)

    def test_development_profile_is_rejected(self):
        dev = profile_bytes(APP, 'Prism Development', 'CCCC-3', ProvisionedDevices=['00008030-ABC'])
        result = self.run_signing({APP_SECRET: encode(dev)})
        self.assertEqual(result.returncode, 1)
        self.assertIn('not an App Store profile', result.stderr)

    def test_get_task_allow_profile_is_rejected(self):
        result = self.run_signing({APP_SECRET: encode(debug_profile_bytes())})
        self.assertEqual(result.returncode, 1)
        self.assertIn('not an App Store profile', result.stderr)

    def test_two_secrets_for_same_bundle_are_rejected(self):
        result = self.run_signing({
            APP_SECRET: encode(profile_bytes(APP, APP_PROFILE, 'AAAA-1')),
            LIVE_SECRET: encode(profile_bytes(APP, LIVE_PROFILE, 'BBBB-2')),
        })
        self.assertEqual(result.returncode, 1)
        self.assertIn(APP_SECRET, result.stderr)
        self.assertIn(LIVE_SECRET, result.stderr)

    def test_profiles_from_different_teams_are_rejected(self):
        result = self.run_signing({
            APP_SECRET: encode(profile_bytes(APP, APP_PROFILE, 'AAAA-1')),
            LIVE_SECRET: encode(profile_bytes(LIVE, LIVE_PROFILE, 'BBBB-2', team='ABCDE12345')),
        })
        self.assertEqual(result.returncode, 1)
        self.assertIn('span teams', result.stderr)

    def test_names_not_ending_in_suffix_are_ignored(self):
        result = self.run_signing({'OTHER_PROFILE': encode(profile_bytes(APP, APP_PROFILE, 'AAAA-1'))})
        self.assertEqual(result.returncode, 1)
        self.assertIn('No provisioning profile secrets found', result.stderr)
        self.assertFalse(self.manifest.exists())
        self.assertFalse((self.home / 'Library').exists())


def ruby_has_xcodeproj():
    try:
        return subprocess.run(['ruby', '-rxcodeproj', '-e', ''], capture_output=True).returncode == 0
    except FileNotFoundError:
        return False


XCODEPROJ_INSTALLED = ruby_has_xcodeproj()


@unittest.skipUnless(XCODEPROJ_INSTALLED, 'xcodeproj gem not installed')
class IosCiManualSigningTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='prism-ios-manual-signing-test-')
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.project = self.work / 'Runner.xcodeproj'
        shutil.copytree(PROJECT, self.project)
        self.manifest = self.work / 'profiles.json'

    def write_manifest(self, profiles):
        self.manifest.write_text(json.dumps({'profiles': profiles, 'paths': []}))

    def run_manual_signing(self):
        return subprocess.run(['ruby', str(MANUAL_SIGNING), str(self.project), str(self.manifest)],
                              cwd=ROOT, capture_output=True, text=True)

    def dump_settings(self, project):
        result = subprocess.run(['ruby', '-rxcodeproj', '-rjson', '-e', DUMP_SETTINGS, str(project)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_release_configs_switch_to_manual_signing(self):
        original = self.dump_settings(PROJECT)
        self.write_manifest(MANUAL_PROFILES)
        result = self.run_manual_signing()
        self.assertEqual(result.returncode, 0, result.stderr)
        settings = self.dump_settings(self.project)
        for target, profile in (('Runner', APP_PROFILE), ('PrismLiveActivities', LIVE_PROFILE)):
            release = settings[target]['Release']
            self.assertEqual(release['CODE_SIGN_STYLE'], 'Manual')
            self.assertEqual(release['PROVISIONING_PROFILE_SPECIFIER'], profile)
            self.assertEqual(release['CODE_SIGN_IDENTITY'], 'iPhone Distribution')
            self.assertEqual(release['DEVELOPMENT_TEAM'], TEAM)
            debug = settings[target]['Debug']
            self.assertEqual(debug, original[target]['Debug'])
            self.assertNotEqual(debug['CODE_SIGN_STYLE'], 'Manual')
            self.assertIsNone(debug['PROVISIONING_PROFILE_SPECIFIER'])
        for config in ('Debug', 'Release'):
            self.assertIsNone(settings['RunnerTests'][config]['PROVISIONING_PROFILE_SPECIFIER'])

    def test_missing_profile_aborts_without_saving(self):
        original_pbxproj = (PROJECT / 'project.pbxproj').read_bytes()
        self.write_manifest(MANUAL_PROFILES[:1])
        result = self.run_manual_signing()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('PrismLiveActivities', result.stderr)
        self.assertIn(LIVE, result.stderr)
        self.assertEqual((self.project / 'project.pbxproj').read_bytes(), original_pbxproj)


if __name__ == '__main__':
    unittest.main()
