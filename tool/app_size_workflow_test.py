"""Check the app-size workflow builds each APK with that commit's Flutter SDK."""

from pathlib import Path
import unittest

from tool.release_workflows_test import yaml_data


ROOT = Path(__file__).resolve().parents[1]


def workflow():
    return yaml_data((ROOT / '.github/workflows/ci.yml').read_text())['jobs']['app_size']['steps']


class AppSizeWorkflowTest(unittest.TestCase):
    def test_base_cache_miss_uses_base_sdk_then_head_sdk(self):
        steps = workflow()
        names = [step.get('name') for step in steps]
        base_setup = next((step for step in steps if step.get('name') == 'Setup base Flutter'), None)
        head_setup = next((step for step in steps if step.get('name') == 'Setup head Flutter'), None)
        self.assertIsNotNone(base_setup, 'cache misses need a base Flutter setup')
        self.assertIsNotNone(head_setup, 'head build needs its own Flutter setup')
        self.assertEqual(base_setup['if'], "steps.base_apk.outputs.cache-hit != 'true'")
        self.assertNotIn('if', head_setup)
        self.assertIn('steps.base_fvm.outputs.version', base_setup['with']['flutter-version'])
        self.assertIn('steps.head_fvm.outputs.version', head_setup['with']['flutter-version'])
        self.assertIn('steps.base_fvm.outputs.version', base_setup['with']['cache-key'])
        self.assertIn('steps.head_fvm.outputs.version', head_setup['with']['cache-key'])
        self.assertLess(names.index('Checkout base for build'), names.index('Read base Flutter version from .fvmrc'))
        self.assertLess(names.index('Checkout head for build'), names.index('Read head Flutter version from .fvmrc'))
        self.assertLess(names.index('Setup base Flutter'), names.index('Build base APK'))
        self.assertLess(names.index('Build base APK'), names.index('Setup head Flutter'))
        self.assertLess(names.index('Setup head Flutter'), names.index('Build head APK'))


if __name__ == '__main__':
    unittest.main()
