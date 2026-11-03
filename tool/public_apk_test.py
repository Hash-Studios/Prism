"""Behavioral fixtures for tool/public_apk.py. No network, Play credentials or real releases."""

import base64
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from unittest import mock
import unittest
import urllib.error


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tool'))
import public_apk

TAG = 'v3.18.2+359'
PASSWORD = 'secret1'
MANIFEST = ('<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.hash.prism" '
            'android:versionCode="{code}" android:versionName="3.18.2">'
            '<uses-sdk android:minSdkVersion="24"/></manifest>')
GH_SCRIPT = '''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['GH_LOG'], 'a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:3] == ['release', 'view']:
    print(os.environ.get('GH_ASSETS') or '{"assets": [{"name": "app-release-359.aab"}]}')
sys.exit(0)
'''


def _sdk_homes():
    homes = [os.environ.get('ANDROID_HOME'), os.environ.get('ANDROID_SDK_ROOT'),
             str(Path.home() / 'Library/Android/sdk'), str(Path.home() / 'Android/Sdk')]
    return list(filter(None, homes))


def _newest_android_jar():
    jars = []
    for home in _sdk_homes():
        jars += Path(home).glob('platforms/*/android.jar')
    if not jars:
        return None
    return max(jars, key=lambda p: [int(n) if n.isdigit() else 0 for n in re.split(r'[.-]', p.parent.name)])


def _find_tools_or_none():
    try:
        return public_apk.find_tools()
    except public_apk.ReleaseError:
        return None


TOOLS = _find_tools_or_none()
ANDROID_JAR = _newest_android_jar()
KEYTOOL = shutil.which('keytool')
FIXTURES_OK = bool(TOOLS and ANDROID_JAR and KEYTOOL)
FIXTURES = {}


def _run(cmd):
    return subprocess.run([str(part) for part in cmd], check=True, capture_output=True)


def _keystore(directory, name):
    path = directory / f'{name}.jks'
    _run([KEYTOOL, '-genkeypair', '-keystore', path, '-storepass', PASSWORD, '-keypass', PASSWORD, '-alias', 'a',
          '-keyalg', 'RSA', '-keysize', '2048', '-validity', '1', '-dname', f'CN={name}', '-noprompt'])
    return path


def _cert_digest(keystore):
    der = _run([KEYTOOL, '-exportcert', '-keystore', keystore, '-storepass', PASSWORD, '-alias', 'a']).stdout
    return hashlib.sha256(der).hexdigest()


def _build_apk(directory, name, keystore, version_code):
    manifest = directory / f'{name}-AndroidManifest.xml'
    manifest.write_text(MANIFEST.format(code=version_code))
    unsigned = directory / f'{name}-unsigned.apk'
    signed = directory / f'{name}.apk'
    _run([TOOLS.aapt2, 'link', '-I', ANDROID_JAR, '--manifest', manifest, '-o', unsigned])
    _run([TOOLS.apksigner, 'sign', '--ks', keystore, '--ks-pass', f'pass:{PASSWORD}', '--out', signed, unsigned])
    return signed


def setUpModule():
    if not FIXTURES_OK:
        return
    directory = Path(tempfile.mkdtemp(prefix='public-apk-test-'))
    FIXTURES['dir'] = directory
    right = _keystore(directory, 'right')
    wrong = _keystore(directory, 'wrong')
    FIXTURES['right_digest'] = _cert_digest(right)
    FIXTURES['wrong_digest'] = _cert_digest(wrong)
    FIXTURES['right_apk'] = _build_apk(directory, 'right', right, 359)
    FIXTURES['wrong_apk'] = _build_apk(directory, 'wrong', wrong, 359)
    FIXTURES['old_apk'] = _build_apk(directory, 'old', right, 358)


def tearDownModule():
    if FIXTURES.get('dir'):
        shutil.rmtree(FIXTURES['dir'], ignore_errors=True)
    FIXTURES.clear()


class TagTest(unittest.TestCase):
    def test_parse_tag_reads_version_code_and_asset_names(self):
        tag = public_apk.parse_tag('v3.18.2+359')
        self.assertEqual(tag.version, '3.18.2')
        self.assertEqual(tag.code, 359)
        self.assertEqual(tag.apk_name, 'prism-3.18.2-359.apk')
        self.assertEqual(tag.sha_name, 'prism-3.18.2-359.apk.sha256')

    def test_parse_tag_refuses_missing_v_prefix(self):
        with self.assertRaises(public_apk.ReleaseError):
            public_apk.parse_tag('3.18.2+359')

    def test_parse_tag_refuses_missing_patch_number(self):
        with self.assertRaises(public_apk.ReleaseError):
            public_apk.parse_tag('v3.18+359')


class DigestTest(unittest.TestCase):
    def test_normalize_sha256_strips_colons_and_lowercases_hex(self):
        colon_hex = ':'.join(f'{i:02X}' for i in range(32))
        self.assertEqual(public_apk.normalize_sha256(colon_hex), bytes(range(32)).hex())

    def test_normalize_sha256_decodes_base64_digest(self):
        encoded = base64.b64encode(bytes(range(32))).decode()
        self.assertEqual(public_apk.normalize_sha256(encoded), bytes(range(32)).hex())

    def test_normalize_sha256_refuses_text_that_is_not_a_digest(self):
        with self.assertRaises(public_apk.ReleaseError):
            public_apk.normalize_sha256('nope')

    def test_signer_digests_deduplicates_one_certificate(self):
        text = ('V3.0 Signer: certificate SHA-256 digest: ' + 'a' * 64
                + '\nSigner #1 certificate SHA-256 digest: ' + 'a' * 64)
        self.assertEqual(public_apk.signer_digests(text), {'a' * 64})

    def test_signer_digests_keeps_each_distinct_certificate(self):
        text = ('Signer #1 certificate SHA-256 digest: ' + 'a' * 64
                + '\nSigner #2 certificate SHA-256 digest: ' + 'b' * 64)
        self.assertEqual(len(public_apk.signer_digests(text)), 2)


class PickTest(unittest.TestCase):
    listing = {'generatedApks': [
        {'certificateSha256Hash': 'a' * 64, 'generatedUniversalApk': {'downloadId': 'X'}},
        {'certificateSha256Hash': 'b' * 64, 'generatedUniversalApk': {'downloadId': 'Y'}},
    ]}

    def test_pick_universal_apk_selects_expected_certificate(self):
        self.assertEqual(public_apk.pick_universal_apk(self.listing, 'b' * 64), ('Y', 'b' * 64))

    def test_pick_universal_apk_refuses_unknown_certificate(self):
        with self.assertRaises(public_apk.ReleaseError):
            public_apk.pick_universal_apk(self.listing, 'c' * 64)

    def test_pick_universal_apk_refuses_ambiguous_listing_without_expected_certificate(self):
        with self.assertRaises(public_apk.ReleaseError):
            public_apk.pick_universal_apk(self.listing, None)

    def test_pick_universal_apk_refuses_entry_without_universal_apk(self):
        listing = {'generatedApks': [{'certificateSha256Hash': 'a' * 64}]}
        with self.assertRaisesRegex(public_apk.ReleaseError, 'universal APK'):
            public_apk.pick_universal_apk(listing, 'a' * 64)


@unittest.skipUnless(FIXTURES_OK, 'needs Android build-tools and keytool')
class SignatureCheckTest(unittest.TestCase):
    def test_check_apk_returns_digest_of_expected_signing_key(self):
        tag = public_apk.parse_tag(TAG)
        cert = public_apk.check_apk(FIXTURES['right_apk'], tag, FIXTURES['right_digest'], TOOLS)
        self.assertEqual(cert, FIXTURES['right_digest'])

    def test_check_apk_refuses_other_signing_key_and_names_both_digests(self):
        tag = public_apk.parse_tag(TAG)
        with self.assertRaises(public_apk.ReleaseError) as context:
            public_apk.check_apk(FIXTURES['wrong_apk'], tag, FIXTURES['right_digest'], TOOLS)
        message = str(context.exception)
        self.assertIn(FIXTURES['wrong_digest'], message)
        self.assertIn(FIXTURES['right_digest'], message)

    def test_check_apk_refuses_older_version_code(self):
        tag = public_apk.parse_tag(TAG)
        with self.assertRaises(public_apk.ReleaseError) as context:
            public_apk.check_apk(FIXTURES['old_apk'], tag, FIXTURES['right_digest'], TOOLS)
        self.assertIn('version code is 358', str(context.exception))


class GhCliTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='public-apk-gh-')
        self.addCleanup(temp.cleanup)
        self.work = Path(temp.name)
        self.bin = self.work / 'bin'
        self.bin.mkdir()
        gh = self.bin / 'gh'
        gh.write_text(GH_SCRIPT)
        gh.chmod(0o755)
        self.gh_log = self.work / 'gh.log'
        self.out = self.work / 'out'

    def run_main(self, argv, gh_assets=''):
        out, err = io.StringIO(), io.StringIO()
        env = {'PATH': f'{self.bin}{os.pathsep}{os.environ["PATH"]}', 'GH_LOG': str(self.gh_log),
               'GH_ASSETS': gh_assets}
        with mock.patch.dict(os.environ, env), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = public_apk.main(argv)
        return code, out.getvalue(), err.getvalue()

    def gh_calls(self):
        if not self.gh_log.exists():
            return []
        return [json.loads(line) for line in self.gh_log.read_text().splitlines()]

    @staticmethod
    def upload_calls(calls):
        return [call for call in calls if call[:2] == ['release', 'upload']]


@unittest.skipUnless(FIXTURES_OK, 'needs Android build-tools and keytool')
class DryRunTest(GhCliTest):
    def test_dry_run_checks_apk_writes_sha_file_and_attaches_nothing(self):
        code, out, _ = self.run_main(['--tag', TAG, '--dry-run', '--apk', str(FIXTURES['right_apk']),
                                      '--expected-cert', FIXTURES['right_digest'], '--out-dir', str(self.out)])
        self.assertEqual(code, 0)
        calls = self.gh_calls()
        self.assertEqual(len(calls), 1, f'dry run made gh calls {calls}')
        self.assertEqual(calls[0][:3], ['release', 'view', TAG])
        self.assertEqual(self.upload_calls(calls), [], 'dry run must not upload')
        apk = self.out / 'prism-3.18.2-359.apk'
        sha_file = self.out / 'prism-3.18.2-359.apk.sha256'
        digest = hashlib.sha256(apk.read_bytes()).hexdigest()
        self.assertEqual(sha_file.read_text(), f'{digest}  prism-3.18.2-359.apk\n')
        self.assertIn('attached nothing', out)


@unittest.skipUnless(FIXTURES_OK, 'needs Android build-tools and keytool')
class RealRunTest(GhCliTest):
    def setUp(self):
        super().setUp()
        patcher = mock.patch.object(public_apk, 'PLAY_APP_SIGNING_CERT_SHA256', FIXTURES['right_digest'])
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_real_run_refuses_apk_signed_by_other_key_without_upload(self):
        code, _, err = self.run_main(['--tag', TAG, '--apk', str(FIXTURES['wrong_apk']), '--out-dir', str(self.out)])
        self.assertEqual(code, 1)
        self.assertIn('signed by certificate', err)
        self.assertEqual(self.upload_calls(self.gh_calls()), [], 'wrong-key APK must not upload')

    def test_real_run_uploads_apk_and_sha_file_last(self):
        code, _, err = self.run_main(['--tag', TAG, '--apk', str(FIXTURES['right_apk']), '--out-dir', str(self.out)])
        self.assertEqual(code, 0, err)
        calls = self.gh_calls()
        self.assertEqual(calls[-1][:3], ['release', 'upload', TAG])
        self.assertIn(str(self.out / 'prism-3.18.2-359.apk'), calls[-1])
        self.assertIn(str(self.out / 'prism-3.18.2-359.apk.sha256'), calls[-1])

    def test_real_run_without_pinned_certificate_makes_no_gh_call(self):
        with mock.patch.object(public_apk, 'PLAY_APP_SIGNING_CERT_SHA256', ''):
            code, _, err = self.run_main(['--tag', TAG, '--apk', str(FIXTURES['right_apk']),
                                          '--out-dir', str(self.out)])
        self.assertEqual(code, 1)
        self.assertFalse(self.gh_log.exists(), 'no gh call may run before the pin is set')
        self.assertIn('PLAY_APP_SIGNING_CERT_SHA256 is not set', err)

    def test_real_run_refuses_expected_cert_override_that_differs_from_pin(self):
        code, _, err = self.run_main(['--tag', TAG, '--apk', str(FIXTURES['right_apk']), '--expected-cert', 'c' * 64,
                                      '--out-dir', str(self.out)])
        self.assertEqual(code, 1)
        self.assertIn('for dry runs', err)
        self.assertEqual(self.upload_calls(self.gh_calls()), [], 'override must not upload')

    def test_real_run_skips_upload_when_release_already_has_both_files(self):
        assets = json.dumps({'assets': [{'name': 'prism-3.18.2-359.apk'}, {'name': 'prism-3.18.2-359.apk.sha256'}]})
        code, _, err = self.run_main(['--tag', TAG, '--apk', str(FIXTURES['right_apk']), '--out-dir', str(self.out)],
                                     gh_assets=assets)
        self.assertEqual(code, 0, err)
        self.assertEqual(self.upload_calls(self.gh_calls()), [], 'already attached, so no upload')


class SecretHandlingTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='public-apk-secret-')
        self.addCleanup(temp.cleanup)
        self.work = Path(temp.name)
        self.pem = _run(['openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048']).stdout.decode()

    def test_sign_rs256_signature_verifies_with_public_key(self):
        signature = public_apk.sign_rs256(b'hello', self.pem)
        self.assertIsInstance(signature, bytes)
        public_key = subprocess.run(['openssl', 'pkey', '-pubout'], input=self.pem.encode(), capture_output=True,
                                    check=True).stdout
        pub, sig, data = self.work / 'pub.pem', self.work / 'sig.bin', self.work / 'data.bin'
        pub.write_bytes(public_key)
        sig.write_bytes(signature)
        data.write_bytes(b'hello')
        result = subprocess.run(['openssl', 'dgst', '-sha256', '-verify', str(pub), '-signature', str(sig), str(data)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Verified OK', result.stdout)

    def test_sign_rs256_refuses_bad_key_without_echoing_it(self):
        with self.assertRaises(public_apk.ReleaseError) as context:
            public_apk.sign_rs256(b'x', 'not a key')
        self.assertNotIn('not a key', str(context.exception))

    def test_access_token_refusal_leaks_neither_key_nor_request(self):
        path = self.work / 'service-account.json'
        path.write_text(json.dumps({'type': 'service_account', 'client_email': 'ci@example.iam.gserviceaccount.com',
                                    'private_key': self.pem, 'token_uri': 'https://oauth2.googleapis.com/token'}))
        captured = []

        def refuse(request, *args, **kwargs):
            captured.append(request.data.decode())
            raise urllib.error.HTTPError(
                request.full_url, 400, 'Bad Request', hdrs=None,
                fp=io.BytesIO(json.dumps({'error': 'invalid_grant',
                                          'error_description': 'Invalid JWT Signature.'}).encode()))

        with mock.patch('public_apk.urllib.request.urlopen', side_effect=refuse):
            with self.assertRaises(public_apk.ReleaseError) as context:
                public_apk.access_token(public_apk.load_service_account(path))
        message = str(context.exception)
        self.assertIn('HTTP 400', message)
        self.assertIn('invalid_grant', message)
        middle = len(self.pem) // 2
        self.assertNotIn(self.pem[middle:middle + 40], message)
        self.assertNotIn('assertion', message)
        self.assertEqual(len(captured), 1)
        self.assertNotIn(captured[0], message)

    def test_load_service_account_rejects_incomplete_key_without_echoing_file(self):
        path = self.work / 'partial.json'
        contents = json.dumps({'type': 'service_account', 'client_email': 'x'})
        path.write_text(contents)
        with self.assertRaises(public_apk.ReleaseError) as context:
            public_apk.load_service_account(path)
        self.assertNotIn(contents, str(context.exception))

    def test_load_service_account_names_missing_credentials_path(self):
        with self.assertRaisesRegex(public_apk.ReleaseError, 'Play credentials not found'):
            public_apk.load_service_account(self.work / 'missing.json')


if __name__ == '__main__':
    unittest.main()
