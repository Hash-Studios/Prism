"""Run the actual Flutter notification contract against isolated backend fixtures."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest
from urllib.parse import urljoin


ROOT = Path(__file__).resolve().parents[1]


class NotificationContractFixtureTest(unittest.TestCase):
    def test_contract_rejects_unregistered_backend_channel(self):
        with tempfile.TemporaryDirectory(prefix='prism-channel-contract-') as directory:
            work = Path(directory)
            for name in ('pubspec.yaml', 'pubspec.lock', '.fvmrc'):
                shutil.copy(ROOT / name, work)
            for name in ('lib', 'assets', 'fonts', 'shaders'):
                if (ROOT / name).exists():
                    (work / name).symlink_to(ROOT / name, target_is_directory=True)
            (work / '.dart_tool').mkdir()
            source = ROOT / '.dart_tool/package_config.json'
            config = json.loads(source.read_text())
            for package in config['packages']:
                package['rootUri'] = work.as_uri() + '/' if package['name'] == 'Prism' else urljoin(source.as_uri(), package['rootUri'])
            (work / '.dart_tool/package_config.json').write_text(json.dumps(config))
            if (ROOT / '.dart_tool/package_graph.json').exists():
                shutil.copy(ROOT / '.dart_tool/package_graph.json', work / '.dart_tool')
            backend = work / 'functions/src'
            backend.mkdir(parents=True)
            channels = ('moderation', 'followers', 'posts', 'wall_of_the_day', 'streak_reminder')
            source = backend / 'fixture.ts'
            source.write_text('\n'.join(f"const push{i} = {{channelId: '{channel}'}};"
                                        for i, channel in enumerate(channels)))
            test = work / 'test/core/startup/notification_channels_test.dart'
            test.parent.mkdir(parents=True)
            shutil.copy(ROOT / 'test/core/startup/notification_channels_test.dart', test)
            command = shlex.split(os.environ.get('FLUTTER', 'fvm flutter')) + [
                'test', '--no-pub', '--reporter', 'expanded', str(test)]
            valid = subprocess.run(command, cwd=work, capture_output=True, text=True)
            self.assertEqual(valid.returncode, 0, valid.stdout + valid.stderr)
            with source.open('a') as output:
                output.write("\nconst missing = {channelId: 'synthetic_backend_only_channel'};\n")
            invalid = subprocess.run(command, cwd=work, capture_output=True, text=True)
            self.assertNotEqual(invalid.returncode, 0)
            self.assertIn('synthetic_backend_only_channel', invalid.stdout + invalid.stderr)
            self.assertIn('every channel id in the backend has a channel', invalid.stdout + invalid.stderr)


if __name__ == '__main__':
    unittest.main()
