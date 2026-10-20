#!/usr/bin/env python3
"""Exercise the build phase with real Mach-O frameworks. Requires macOS/Xcode."""

import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('strip_embedded_frameworks.sh')


def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs).stdout


class StripEmbeddedFrameworksTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixtures = tempfile.TemporaryDirectory(prefix='prism-strip-fixture-')
        cls.source = Path(cls.fixtures.name) / 'SDK.framework'
        cls.source.mkdir()
        source_file = Path(cls.fixtures.name) / 'sdk.c'
        source_file.write_text(
            'static int local_answer(void) { return 42; }\n'
            'int sdk_answer(void) { return local_answer(); }\n'
        )
        run('xcrun', 'clang', '-dynamiclib', '-g', '-O0', '-Wl,-no_adhoc_codesign',
            '-install_name', '@rpath/SDK.framework/SDK', str(source_file), '-o', str(cls.source / 'SDK'))
        with (cls.source / 'Info.plist').open('wb') as stream:
            plistlib.dump({'CFBundleExecutable': 'SDK', 'CFBundleIdentifier': 'com.prism.strip-fixture',
                          'CFBundlePackageType': 'FMWK', 'CFBundleVersion': '1'}, stream)

    @classmethod
    def tearDownClass(cls):
        cls.fixtures.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='prism-strip-test-')
        self.addCleanup(self.temp.cleanup)
        self.build = Path(self.temp.name) / 'Build Products'
        self.frameworks = self.build / 'Runner.app' / 'Frameworks'
        self.frameworks.mkdir(parents=True)
        self.sdk = self.frameworks / 'SDK.framework'
        shutil.copytree(self.source, self.sdk)
        self.binary = self.sdk / 'SDK'
        self.env = dict(os.environ, CONFIGURATION='Release', PLATFORM_NAME='iphoneos',
                        TARGET_BUILD_DIR=str(self.build), WRAPPER_NAME='Runner.app',
                        FRAMEWORKS_FOLDER_PATH='Runner.app/Frameworks', CODE_SIGNING_ALLOWED='NO',
                        CODE_SIGNING_REQUIRED='NO', EXPANDED_CODE_SIGN_IDENTITY='')

    def phase(self, **changes):
        return subprocess.run(['/bin/bash', str(SCRIPT)], env=dict(self.env, **changes),
                              capture_output=True, text=True)

    def test_release_removes_local_symbols_but_preserves_exports_uuid_and_source(self):
        original = self.binary.read_bytes()
        exports = run('xcrun', 'nm', '-gjU', str(self.binary))
        uuid = run('xcrun', 'dwarfdump', '--uuid', str(self.binary))
        self.assertIn('_local_answer', run('xcrun', 'nm', '-j', str(self.binary)))
        result = self.phase()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLess(self.binary.stat().st_size, len(original))
        self.assertNotIn('_local_answer', run('xcrun', 'nm', '-j', str(self.binary)))
        self.assertEqual(run('xcrun', 'nm', '-gjU', str(self.binary)), exports)
        self.assertEqual(run('xcrun', 'dwarfdump', '--uuid', str(self.binary)), uuid)
        self.assertEqual((self.source / 'SDK').read_bytes(), original)

    def test_required_signing_without_identity_fails_before_modifying_binaries(self):
        original = self.binary.read_bytes()
        result = self.phase(CODE_SIGNING_ALLOWED='YES', CODE_SIGNING_REQUIRED='YES')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.binary.read_bytes(), original)

    def test_debug_profile_simulator_and_unset_environment_do_not_change_binaries(self):
        original = self.binary.read_bytes()
        for changes in ({'CONFIGURATION': 'Debug'}, {'CONFIGURATION': 'Profile'},
                        {'PLATFORM_NAME': 'iphonesimulator'}, {'CONFIGURATION': ''},
                        {'PLATFORM_NAME': ''}):
            with self.subTest(changes=changes):
                # The guard must run even when signing/path settings are absent.
                result = self.phase(**dict(changes, TARGET_BUILD_DIR='', WRAPPER_NAME=''))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.binary.read_bytes(), original)

    def test_flutter_app_and_swift_runtime_are_unchanged(self):
        excluded = []
        for name in ('Flutter', 'App'):
            framework = self.frameworks / f'{name}.framework'
            shutil.copytree(self.source, framework)
            (framework / 'SDK').rename(framework / name)
            excluded.append(framework / name)
        runtime = self.frameworks / 'libswiftCore.dylib'
        shutil.copyfile(self.source / 'SDK', runtime)
        excluded.append(runtime)
        originals = {path: path.read_bytes() for path in excluded}
        result = self.phase()
        self.assertEqual(result.returncode, 0, result.stderr)
        for path, original in originals.items():
            self.assertEqual(path.read_bytes(), original, str(path))

    def test_repeated_stripping_is_idempotent(self):
        self.assertEqual(self.phase().returncode, 0)
        first = self.binary.read_bytes()
        result = self.phase()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.binary.read_bytes(), first)

    def test_resigned_framework_keeps_identifier_entitlements_and_runs(self):
        entitlements = Path(self.temp.name) / 'entitlements.plist'
        with entitlements.open('wb') as stream:
            plistlib.dump({'com.prism.strip-fixture': True}, stream)
        run('/usr/bin/codesign', '--force', '--sign', '-', '--identifier', 'com.prism.fixture-signed',
            '--entitlements', str(entitlements), str(self.sdk))
        before = run('/usr/bin/codesign', '-d', '--entitlements', ':-', str(self.sdk))
        result = self.phase(CODE_SIGNING_ALLOWED='YES', CODE_SIGNING_REQUIRED='YES',
                            EXPANDED_CODE_SIGN_IDENTITY='-', OTHER_CODE_SIGN_FLAGS='--timestamp=none')
        self.assertEqual(result.returncode, 0, result.stderr)
        # Xcode also supplies empty flags. Exercise Bash 3's empty-array behavior.
        result = self.phase(CODE_SIGNING_ALLOWED='YES', CODE_SIGNING_REQUIRED='YES',
                            EXPANDED_CODE_SIGN_IDENTITY='-', OTHER_CODE_SIGN_FLAGS='')
        self.assertEqual(result.returncode, 0, result.stderr)
        run('/usr/bin/codesign', '--verify', '--strict', str(self.sdk))
        self.assertEqual(run('/usr/bin/codesign', '-d', '--entitlements', ':-', str(self.sdk)), before)
        metadata = subprocess.run(['/usr/bin/codesign', '-dv', str(self.sdk)], capture_output=True, text=True)
        self.assertIn('Identifier=com.prism.fixture-signed', metadata.stderr)
        # Host fixture only. This is not runtime proof for the actual iOS SDKs.
        value = run('python3', '-c', 'import ctypes, sys; print(ctypes.CDLL(sys.argv[1]).sdk_answer())',
                    str(self.binary))
        self.assertEqual(value.strip(), '42')

    def test_disabled_signing_does_not_use_an_available_identity(self):
        for flag in ('CODE_SIGNING_ALLOWED', 'CODE_SIGNING_REQUIRED'):
            with self.subTest(flag=flag):
                changes = dict(CODE_SIGNING_ALLOWED='YES', CODE_SIGNING_REQUIRED='YES',
                               EXPANDED_CODE_SIGN_IDENTITY='not-a-real-identity')
                changes[flag] = 'NO'
                result = self.phase(**changes)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_signing_failure_fails_the_phase(self):
        result = self.phase(CODE_SIGNING_ALLOWED='YES', CODE_SIGNING_REQUIRED='YES',
                            EXPANDED_CODE_SIGN_IDENTITY='prism-no-such-signing-identity')
        self.assertNotEqual(result.returncode, 0)

    def test_invalid_macho_fails_the_phase(self):
        self.binary.write_text('not a Mach-O binary')
        self.assertNotEqual(self.phase().returncode, 0)

    def test_paths_outside_the_embedded_app_are_rejected(self):
        original = self.binary.read_bytes()
        for changes in ({'FRAMEWORKS_FOLDER_PATH': '../Pods'}, {'WRAPPER_NAME': '../Runner.app'},
                        {'WRAPPER_NAME': 'Pods'}):
            with self.subTest(changes=changes):
                self.assertNotEqual(self.phase(**changes).returncode, 0)
                self.assertEqual(self.binary.read_bytes(), original)

    def test_symlinked_framework_or_binary_cannot_modify_cached_source(self):
        original = (self.source / 'SDK').read_bytes()
        shutil.rmtree(self.sdk)
        self.sdk.symlink_to(self.source, target_is_directory=True)
        self.assertNotEqual(self.phase().returncode, 0)
        self.sdk.unlink()
        shutil.copytree(self.source, self.sdk)
        self.binary.unlink()
        self.binary.symlink_to(self.source / 'SDK')
        self.assertNotEqual(self.phase().returncode, 0)
        self.assertEqual((self.source / 'SDK').read_bytes(), original)

    def test_empty_frameworks_directory_is_supported(self):
        shutil.rmtree(self.sdk)
        result = self.phase()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_runner_phase_runs_after_all_framework_and_resource_embedding(self):
        project = SCRIPT.parents[1] / 'Runner.xcodeproj' / 'project.pbxproj'
        objects = json.loads(run('plutil', '-convert', 'json', '-o', '-', str(project)))['objects']
        runner = next(obj for obj in objects.values() if obj.get('isa') == 'PBXNativeTarget'
                      and obj.get('name') == 'Runner')
        phases = [objects[key] for key in runner['buildPhases']]
        strip_phase = next(phase for phase in phases if phase.get('name') == 'Strip embedded SDK symbols')
        self.assertEqual(phases[-1], strip_phase)
        self.assertEqual(strip_phase['alwaysOutOfDate'], '1')
        self.assertIn('scripts/strip_embedded_frameworks.sh', strip_phase['shellScript'])

    def prepare_archive(self):
        products = Path(self.temp.name) / 'Unstripped Products'
        shutil.copytree(self.source, products / 'SDK.framework')
        dsym = products / 'SDK.framework.dSYM'
        run('xcrun', 'dsymutil', str(products / 'SDK.framework/SDK'), '-o', str(dsym))
        result = self.phase()
        self.assertEqual(result.returncode, 0, result.stderr)
        archive = Path(self.temp.name) / 'After.xcarchive'
        shutil.copytree(self.frameworks.parent, archive / 'Products/Applications/Runner.app')
        shutil.copytree(dsym, archive / 'dSYMs/SDK.framework.dSYM')
        return archive, products

    def verify_archive(self, archive, products):
        return subprocess.run(['python3', str(SCRIPT.with_name('verify_stripped_archive.py')),
                               str(archive), str(products)], capture_output=True, text=True)

    def test_archive_verifier_measures_savings_and_rejects_changed_exports(self):
        archive, products = self.prepare_archive()
        result = self.verify_archive(archive, products)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report['saved_sdk_bytes'], (self.source / 'SDK').stat().st_size - self.binary.stat().st_size)
        self.assertEqual(report['dsyms_unchanged'], 1)
        binary = archive / 'Products/Applications/Runner.app/Frameworks/SDK.framework/SDK'
        binary.write_bytes(binary.read_bytes().replace(b'_sdk_answer', b'_bad_answer'))
        result = self.verify_archive(archive, products)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('exports changed', result.stderr)

    def test_archive_verifier_rejects_modified_dsyms(self):
        archive, products = self.prepare_archive()
        dwarf = archive / 'dSYMs/SDK.framework.dSYM/Contents/Resources/DWARF/SDK'
        dwarf.write_bytes(dwarf.read_bytes() + b'changed debug symbols')
        result = self.verify_archive(archive, products)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('dSYM changed', result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
