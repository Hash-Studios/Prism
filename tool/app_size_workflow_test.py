"""Check the app-size workflow builds each APK with that commit's Flutter SDK."""

import json
import os
from pathlib import Path
import subprocess
import unittest

from tool.release_workflows_test import yaml_data


ROOT = Path(__file__).resolve().parents[1]


def workflow():
    return yaml_data((ROOT / '.github/workflows/app_size.yml').read_text())['jobs']['app_size']['steps']


class AppSizeWorkflowTest(unittest.TestCase):
    def test_only_opted_in_prs_or_manual_requests_start_apk_builds(self):
        config = yaml_data((ROOT / '.github/workflows/app_size.yml').read_text())
        # GitHub expressions use the same boolean operators as JavaScript.
        condition = config['jobs']['request']['if'].replace(
            'github.event.pull_request.labels.*.name',
            'github.event.pull_request.labels.map(label => label.name)')
        scenarios = (
            ('pull_request', 'synchronize', [], False, '', False),
            ('pull_request', 'synchronize', ['ci:app-size'], False, '', True),
            ('pull_request', 'labeled', ['ci:app-size'], False, 'ci:app-size', True),
            ('pull_request', 'labeled', ['ci:app-size'], False, 'bug', False),
            ('pull_request', 'unlabeled', [], False, 'ci:app-size', False),
            ('pull_request', 'synchronize', ['ci:app-size'], True, '', False),
            ('workflow_dispatch', '', [], False, '', True),
        )
        for event, action, labels, draft, changed_label, expected in scenarios:
            with self.subTest(event=event, action=action, labels=labels, draft=draft):
                github = {'event_name': event, 'event': {'action': action,
                    'pull_request': {'draft': draft, 'labels': [{'name': name} for name in labels]},
                    'label': {'name': changed_label}}}
                script = ('const github = ' + json.dumps(github) + ';\n'
                          'const contains = (values, value) => values.includes(value);\n'
                          'console.log(Boolean(' + condition + '));')
                result = subprocess.run(['node', '-e', script], capture_output=True, text=True, check=True)
                self.assertEqual(result.stdout.strip(), str(expected).lower())
        self.assertNotIn('ci', config['jobs'])
        self.assertNotIn('pull_request_target', config.get('on', config.get('true')))
        comment = next(step for step in config['jobs']['app_size_comment']['steps']
                       if step.get('name') == 'Upsert app-size PR comment')
        self.assertEqual(comment['with']['number'], '${{ needs.request.outputs.pr_number }}')
        self.assertNotIn('write', config['jobs']['app_size']['permissions'].values())
        self.assertFalse(any('checkout' in step.get('uses', '') or 'run' in step
                             for step in config['jobs']['app_size_comment']['steps']))

    def test_manual_request_resolves_exact_pr_shas_and_rejects_invalid_or_closed_prs(self):
        config = yaml_data((ROOT / '.github/workflows/app_size.yml').read_text())
        command = config['jobs']['request']['steps'][0]['with']['script']
        for number, state, expected in (('827', 'open', 0), ('0', 'open', 1),
                                         ('827; touch OWNED', 'open', 1), ('827', 'closed', 1)):
            with self.subTest(number=number, state=state):
                script = '''
const output = {};
const context = {repo: {owner: 'Hash-Studios', repo: 'Prism'}};
const github = {rest: {pulls: {get: async input => {
  if (input.pull_number !== 827 || input.owner !== 'Hash-Studios' || input.repo !== 'Prism') {
    throw new Error('Wrong PR requested');
  }
  return {data: {state: process.env.PR_STATE, base: {sha: 'base827'}, head: {sha: 'head827'}}};
}}}};
const core = {setOutput: (key, value) => output[key] = value};
(async () => {COMMAND})().then(() => console.log(JSON.stringify(output))).catch(error => {
  console.error(error.message); process.exitCode = 1;
});
'''.replace('COMMAND', command)
                result = subprocess.run(['node', '-e', script], capture_output=True, text=True,
                                        env={**os.environ, 'PR_NUMBER': number, 'PR_STATE': state})
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                if expected == 0:
                    self.assertEqual(json.loads(result.stdout),
                                     {'base_sha': 'base827', 'head_sha': 'head827', 'pr_number': '827'})
                else:
                    self.assertIn('must be', result.stderr)

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
        restore = next(step for step in steps if step.get('name') == 'Restore the base APK')
        save = next(step for step in steps if step.get('name') == 'Cache base APK for this PR')
        self.assertEqual(save['with'], restore['with'])
        self.assertIn("github.event_name == 'pull_request'", save['if'])
        self.assertLess(names.index('Build base APK'), names.index('Cache base APK for this PR'))
        self.assertLess(names.index('Cache base APK for this PR'), names.index('Checkout head for build'))


if __name__ == '__main__':
    unittest.main()
