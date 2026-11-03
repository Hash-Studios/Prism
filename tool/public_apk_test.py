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
import traceback
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


def _build_apk(directory, name, keystore, version_code, stamp=None):
    manifest = directory / f'{name}-AndroidManifest.xml'
    manifest.write_text(MANIFEST.format(code=version_code))
    unsigned = directory / f'{name}-unsigned.apk'
    signed = directory / f'{name}.apk'
    _run([TOOLS.aapt2, 'link', '-I', ANDROID_JAR, '--manifest', manifest, '-o', unsigned])
    # Play adds a source stamp, signed by a Google key, to the APKs it generates.
    stamp_args = ['--stamp-signer', '--ks', stamp, '--ks-pass', f'pass:{PASSWORD}'] if stamp else []
    _run([TOOLS.apksigner, 'sign', '--ks', keystore, '--ks-pass', f'pass:{PASSWORD}', *stamp_args, '--out', signed,
          unsigned])
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
    FIXTURES['stamped_apk'] = _build_apk(directory, 'stamped', right, 359, stamp=wrong)


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

    def test_signer_digests_ignores_source_stamp(self):
        text = ('V3.0 Signer: certificate SHA-256 digest: ' + 'a' * 64
                + '\nSource Stamp Signer: certificate SHA-256 digest: ' + 'b' * 64)
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

    def test_check_apk_accepts_play_source_stamp(self):
        tag = public_apk.parse_tag(TAG)
        cert = public_apk.check_apk(FIXTURES['stamped_apk'], tag, FIXTURES['right_digest'], TOOLS)
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

    def test_check_apk_refuses_wrong_version_name(self):
        tag = public_apk.parse_tag(TAG)
        output = ('Number of signers: 1\nV3.0 Signer: certificate SHA-256 digest: '
                  f'{FIXTURES["right_digest"]}')
        with mock.patch.object(public_apk, 'run', side_effect=[output,
                               "package: name='com.hash.prism' versionCode='359' versionName='3.18.1'"]):
            with self.assertRaisesRegex(public_apk.ReleaseError, 'version is'):
                public_apk.check_apk(Path('test.apk'), tag, FIXTURES['right_digest'], TOOLS)

    def test_check_apk_refuses_wrong_package(self):
        tag = public_apk.parse_tag(TAG)
        output = ('Number of signers: 1\nV3.0 Signer: certificate SHA-256 digest: '
                  f'{FIXTURES["right_digest"]}')
        with mock.patch.object(public_apk, 'run', side_effect=[output,
                               "package: name='com.other.app' versionCode='359' versionName='3.18.2'"]):
            with self.assertRaisesRegex(public_apk.ReleaseError, 'package'):
                public_apk.check_apk(Path('test.apk'), tag, FIXTURES['right_digest'], TOOLS)


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

    def test_real_run_refuses_expected_cert_even_when_it_matches_pin(self):
        code, _, err = self.run_main(['--tag', TAG, '--apk', str(FIXTURES['right_apk']),
                                      '--expected-cert', FIXTURES['right_digest'], '--out-dir', str(self.out)])
        self.assertEqual(code, 1)
        self.assertIn('for dry runs', err)
        self.assertEqual(self.gh_calls(), [])

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
        self.assertNotIn('Invalid JWT Signature.', message)
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


class ReleaseSafetyRegressionTest(unittest.TestCase):
    token = 'oauth-token-that-must-stay-private'
    key = 'private-key-that-must-stay-private'

    def assert_safe_failure(self, operation):
        with self.assertRaises(public_apk.ReleaseError) as caught:
            operation()
        rendered = ''.join(traceback.format_exception(caught.exception))
        self.assertNotIn(self.token, rendered)
        self.assertNotIn(self.key, rendered)
        self.assertNotIn('assertion=private-jwt', rendered)

    def test_google_error_does_not_echo_server_messages_or_credentials(self):
        for body in ({'error': {'message': self.token + self.key}},
                     {'error': 'invalid_grant', 'error_description': 'assertion=private-jwt'},
                     {'error': self.token}):
            with self.subTest(body=body):
                error = urllib.error.HTTPError('https://example.test', 403, 'Forbidden', None,
                                               io.BytesIO(json.dumps(body).encode()))
                rendered = public_apk.google_error(error)
                self.assertIn('HTTP 403', rendered)
                self.assertNotIn(self.token, rendered)
                self.assertNotIn(self.key, rendered)
                self.assertNotIn('assertion=private-jwt', rendered)

    def test_unexpected_token_request_error_is_safe_including_traceback(self):
        account = {'client_email': 'ci@example.test', 'private_key': self.key,
                   'token_uri': 'https://oauth2.googleapis.com/token'}
        with mock.patch.object(public_apk, 'sign_rs256', return_value=b'signature'), \
                mock.patch('public_apk.urllib.request.urlopen', side_effect=RuntimeError(self.key)):
            self.assert_safe_failure(lambda: public_apk.access_token(account))

    def test_unexpected_play_get_error_is_safe_including_traceback(self):
        with mock.patch('public_apk.urllib.request.urlopen', side_effect=RuntimeError(self.token)):
            self.assert_safe_failure(lambda: public_apk.play_get('https://example.test', self.token, what='Download'))

    def test_unexpected_signing_error_is_safe_including_traceback(self):
        with mock.patch('public_apk.subprocess.run', side_effect=RuntimeError(self.key)):
            self.assert_safe_failure(lambda: public_apk.sign_rs256(b'message', self.key))

    def test_oversized_key_cannot_block_before_openssl_starts(self):
        program = ("import sys; sys.path.insert(0, 'tool'); import public_apk; "
                   "public_apk.sign_rs256(b'message', sys.stdin.read())")
        try:
            result = subprocess.run([sys.executable, '-c', program], input='x' * (1 << 20),
                                    capture_output=True, text=True, timeout=5, cwd=ROOT)
        except subprocess.TimeoutExpired:
            self.fail('signing blocked while writing a key before openssl could read it')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('x' * 100, result.stderr)

    def test_main_unexpected_error_has_no_traceback_or_secret(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with mock.patch.object(public_apk, 'find_tools', side_effect=RuntimeError(self.token)), \
                contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            code = public_apk.main(['--tag', TAG, '--dry-run'])
        self.assertEqual(code, 1)
        self.assertNotIn(self.token, stdout.getvalue() + stderr.getvalue())
        self.assertNotIn('Traceback', stderr.getvalue())

    def test_multiple_signers_with_same_certificate_are_rejected(self):
        cert = 'a' * 64
        output = (f'Number of signers: 2\nV3.0 Signer: certificate SHA-256 digest: {cert}\n'
                  f'V3.0 Signer: certificate SHA-256 digest: {cert}\n')
        with mock.patch.object(public_apk, 'run', side_effect=[output,
                               "package: name='com.hash.prism' versionCode='359'"]):
            with self.assertRaisesRegex(public_apk.ReleaseError, 'sign'):
                public_apk.check_apk(Path('test.apk'), public_apk.parse_tag(TAG), cert,
                                     public_apk.Tools(Path('apksigner'), Path('aapt2')))

    def test_download_rejects_truncated_content_and_preserves_target(self):
        self.check_failed_download(short_content=True)

    def test_download_removes_partial_file_after_stream_error(self):
        self.check_failed_download(short_content=False)

    def check_failed_download(self, *, short_content):
        class Response(io.BytesIO):
            headers = {'Content-Length': '100'}

            def read(inner, size=-1):
                if not short_content and inner.tell():
                    raise RuntimeError(self.token)
                return super().read(size)

        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'release.apk'
            target.write_bytes(b'previous verified APK')
            listing = {'generatedApks': [{'certificateSha256Hash': 'a' * 64,
                                         'generatedUniversalApk': {'downloadId': 'X'}}]}
            with mock.patch.object(public_apk, 'load_service_account', return_value={}), \
                    mock.patch.object(public_apk, 'access_token', return_value=self.token), \
                    mock.patch.object(public_apk, 'play_get', side_effect=[
                        io.BytesIO(json.dumps(listing).encode()), Response(b'truncated')]):
                self.assert_safe_failure(lambda: public_apk.download_play_apk(
                    public_apk.parse_tag(TAG), Path('credentials.json'), 'a' * 64, target))
            self.assertEqual(target.read_bytes(), b'previous verified APK')
            self.assertFalse(target.with_name(target.name + '.part').exists())


if __name__ == '__main__':
    unittest.main()
