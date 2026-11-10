"""Fixture tests for deploy drift. Subprocess and network reads are mocked."""

from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from contextlib import ExitStack, redirect_stderr, redirect_stdout
import io
import json
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch
import urllib.error


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tool'))
import deploy_drift

DriftItem = deploy_drift.DriftItem
IN_SYNC = deploy_drift.IN_SYNC
MISSING_LIVE = deploy_drift.MISSING_LIVE
DIFFERENT = deploy_drift.DIFFERENT
LIVE_ONLY = deploy_drift.LIVE_ONLY
UNKNOWN = deploy_drift.UNKNOWN
RULES = deploy_drift.RULES
INDEX = deploy_drift.INDEX
TTL = deploy_drift.TTL
FUNCTION = deploy_drift.FUNCTION
FUNCTION_OPTIONS = deploy_drift.FUNCTION_OPTIONS
WORKER_KIND = deploy_drift.WORKER_KIND
REMOTE_CONFIG = deploy_drift.REMOTE_CONFIG
MIGRATION = deploy_drift.MIGRATION

# updateTime of the live function fixtures: 2026-11-09 14:48:21.838834 UTC.
UPDATE_TIME = '2026-11-09T14:48:21.838834602Z'
DEPLOYED = datetime(2026, 11, 9, 14, 48, 21, 838834, tzinfo=timezone.utc).timestamp()
HOUR = 3600


def prs_900(name, since):
    return ['#900']


def endpoint(regions=('asia-south1',), memory=None, cpu=None, max_instances=None):
    return {'region': list(regions), 'availableMemoryMb': memory, 'cpu': cpu, 'maxInstances': max_instances}


def live_fn(name, region='asia-south1', state='ACTIVE', memory='256Mi', cpu='1', max_instances=20):
    return {'name': f'projects/p/locations/{region}/functions/{name}', 'state': state, 'updateTime': UPDATE_TIME,
            'serviceConfig': {'availableMemory': memory, 'availableCpu': cpu, 'maxInstanceCount': max_instances}}


def run_functions(endpoints, live, code_times=None):
    if code_times is None:
        code_times = {name: DEPLOYED - HOUR for name in endpoints}
    return deploy_drift.compare_functions(endpoints, live, code_times, prs_900)


def summary(items):
    return [(i.kind, i.name, i.status, i.master, i.live, i.reason, i.prs) for i in items]


class CompareRulesTest(unittest.TestCase):
    def test_whitespace_that_separates_tokens_is_not_discarded(self):
        item = deploy_drift.compare_rules('allow read: if a in b;', 'allow read: if ainb;', '', [])
        self.assertEqual(item.status, DIFFERENT)

    def test_whitespace_inside_strings_changes_rules(self):
        item = deploy_drift.compare_rules("allow read: if x == 'a b';", "allow read: if x == 'a  b';", '', [])
        self.assertEqual(item.status, DIFFERENT)

    def test_newline_after_line_comment_changes_rules(self):
        item = deploy_drift.compare_rules('allow read; // comment\nallow write;',
                                          'allow read; // comment allow write;', '', [])
        self.assertEqual(item.status, DIFFERENT)

    def test_whitespace_only_differences_are_in_sync(self):
        local = 'rules_version = "2";\nservice cloud.firestore {\n  match /walls/{id} {\n    allow read;\n  }\n}\n'
        live = 'rules_version = "2";\n\n\tservice   cloud.firestore {\n\tmatch /walls/{id} {\n\t\tallow\tread;\n\t}\n}'
        item = deploy_drift.compare_rules(local, live, '2026-11-09 14:48 UTC', ['#900'])
        self.assertEqual(item.status, IN_SYNC)
        self.assertEqual(item.kind, RULES)
        self.assertEqual(item.master, 'firestore.rules')
        self.assertEqual(item.live, 'released 2026-11-09 14:48 UTC')

    def test_real_change_counts_changed_lines_and_passes_prs_through(self):
        local = 'allow read;\nallow write;\nallow delete;'
        live = 'allow read;\nallow write;\nallow update;'
        item = deploy_drift.compare_rules(local, live, '2026-11-09 14:48 UTC', ['#900'])
        self.assertEqual(item.status, DIFFERENT)
        self.assertEqual(item.master, '+1 -1 lines vs live')
        self.assertEqual(item.live, 'released 2026-11-09 14:48 UTC')
        self.assertEqual(item.reason, 'master rules text differs from the live ruleset')
        self.assertEqual(item.prs, ['#900'])

    def test_no_live_text_is_missing_live(self):
        item = deploy_drift.compare_rules('allow read;', None, '2026-11-09 14:48 UTC', ['#900'])
        self.assertEqual(item.status, MISSING_LIVE)
        self.assertEqual(item.master, 'firestore.rules')
        self.assertEqual(item.live, 'no release')
        self.assertEqual(item.prs, ['#900'])


class CompareIndexesTest(unittest.TestCase):
    def test_explicit_name_direction_is_not_ignored(self):
        fields = [{'fieldPath': 'author', 'order': 'ASCENDING'},
                  {'fieldPath': '__name__', 'order': 'DESCENDING'}]
        local = {'indexes': [{'collectionGroup': 'walls', 'fields': fields}]}
        live = [{'name': 'projects/p/databases/(default)/collectionGroups/walls/indexes/W1',
                 'fields': [dict(f, order='ASCENDING') for f in fields], 'state': 'READY'}]
        self.assertEqual([i.status for i in deploy_drift.compare_indexes(local, live)],
                         [MISSING_LIVE, LIVE_ONLY])

    def test_field_order_and_array_mode_are_not_interchangeable(self):
        fields = [{'fieldPath': 'a', 'arrayConfig': 'CONTAINS'}, {'fieldPath': 'b', 'order': 'ASCENDING'}]
        local = {'indexes': [{'collectionGroup': 'walls', 'fields': fields}]}
        for changed in (list(reversed(fields)), [{'fieldPath': 'a', 'order': 'ASCENDING'}, fields[1]]):
            with self.subTest(fields=changed):
                live = [{'name': 'projects/p/databases/(default)/collectionGroups/walls/indexes/W1',
                         'fields': changed, 'state': 'READY'}]
                self.assertEqual([i.status for i in deploy_drift.compare_indexes(local, live)],
                                 [MISSING_LIVE, LIVE_ONLY])

    local = {'indexes': [
        {'collectionGroup': 'walls', 'queryScope': 'COLLECTION',
         'fields': [{'fieldPath': 'tags', 'arrayConfig': 'CONTAINS'}, {'fieldPath': 'createdAt', 'order': 'DESCENDING'}]},
        {'collectionGroup': 'walls', 'queryScope': 'COLLECTION',
         'fields': [{'fieldPath': 'author', 'order': 'ASCENDING'}, {'fieldPath': 'createdAt', 'order': 'DESCENDING'}]},
        {'collectionGroup': 'folders', 'queryScope': 'COLLECTION_GROUP',
         'fields': [{'fieldPath': 'ownerId', 'order': 'ASCENDING'}, {'fieldPath': 'updatedAt', 'order': 'DESCENDING'}]},
    ]}
    live = [
        # In sync: Firestore adds a trailing __name__ field to live indexes.
        {'name': 'projects/p/databases/(default)/collectionGroups/walls/indexes/W1', 'queryScope': 'COLLECTION',
         'fields': [{'fieldPath': 'tags', 'arrayConfig': 'CONTAINS'}, {'fieldPath': 'createdAt', 'order': 'DESCENDING'},
                    {'fieldPath': '__name__', 'order': 'DESCENDING'}],
         'state': 'READY'},
        {'name': 'projects/p/databases/(default)/collectionGroups/folders/indexes/F1',
         'queryScope': 'COLLECTION_GROUP',
         'fields': [{'fieldPath': 'ownerId', 'order': 'ASCENDING'}, {'fieldPath': 'updatedAt', 'order': 'DESCENDING'}],
         'state': 'CREATING'},
        {'name': 'projects/p/databases/(default)/collectionGroups/logs/indexes/L1', 'queryScope': 'COLLECTION',
         'fields': [{'fieldPath': 'level', 'order': 'ASCENDING'}], 'state': 'READY'},
    ]

    def test_compares_by_key_with_missing_creating_and_live_only_cases(self):
        items = deploy_drift.compare_indexes(self.local, self.live)
        self.assertEqual(summary(items), [
            (INDEX, 'walls [COLLECTION] (tags:CONTAINS, createdAt:DESCENDING)', IN_SYNC, 'listed', 'READY', '', []),
            (INDEX, 'walls [COLLECTION] (author:ASCENDING, createdAt:DESCENDING)', MISSING_LIVE, 'listed', '', '', []),
            (INDEX, 'folders [COLLECTION_GROUP] (ownerId:ASCENDING, updatedAt:DESCENDING)', DIFFERENT, 'listed',
             'CREATING', 'not ready live', []),
            (INDEX, 'logs [COLLECTION] (level:ASCENDING)', LIVE_ONLY, '', 'READY', '', []),
        ])

    def test_item_name_matches_index_key(self):
        items = deploy_drift.compare_indexes(self.local, self.live)
        self.assertEqual(items[0].name, deploy_drift.index_key(
            'walls', 'COLLECTION', [{'fieldPath': 'tags', 'arrayConfig': 'CONTAINS'},
                                    {'fieldPath': 'createdAt', 'order': 'DESCENDING'}]))
        self.assertEqual(items[0].name, 'walls [COLLECTION] (tags:CONTAINS, createdAt:DESCENDING)')


class CompareTtlsTest(unittest.TestCase):
    def test_in_sync_missing_live_creating_and_live_only(self):
        local_json = {'fieldOverrides': [
            {'collectionGroup': 'viewRate', 'fieldPath': 'expireAt', 'ttl': True},
            {'collectionGroup': 'sessions', 'fieldPath': 'expireAt', 'ttl': True},
            {'collectionGroup': 'events', 'fieldPath': 'expireAt', 'ttl': True},
            {'collectionGroup': 'cache', 'fieldPath': 'updatedAt', 'ttl': False},
        ]}
        live_fields = [
            {'name': 'projects/p/databases/(default)/collectionGroups/viewRate/fields/expireAt',
             'ttlConfig': {'state': 'ACTIVE'}},
            {'name': 'projects/p/databases/(default)/collectionGroups/events/fields/expireAt',
             'ttlConfig': {'state': 'CREATING'}},
            {'name': 'projects/p/databases/(default)/collectionGroups/archive/fields/expireAt',
             'ttlConfig': {'state': 'ACTIVE'}},
            # A field with no ttlConfig is not a TTL policy, so it is ignored.
            {'name': 'projects/p/databases/(default)/collectionGroups/cache/fields/updatedAt'},
        ]
        items = deploy_drift.compare_ttls(local_json, live_fields)
        self.assertEqual(summary(items), [
            (TTL, 'viewRate.expireAt', IN_SYNC, 'ttl', 'ACTIVE', '', []),
            (TTL, 'sessions.expireAt', MISSING_LIVE, 'ttl', '', '', []),
            (TTL, 'events.expireAt', DIFFERENT, 'ttl', 'CREATING', 'not ready live', []),
            (TTL, 'archive.expireAt', LIVE_ONLY, '', 'ACTIVE', '', []),
        ])


class CompareFunctionsTest(unittest.TestCase):
    def test_manifest_without_region_is_unknown(self):
        items = run_functions({'fnA': {}}, [])
        self.assertEqual([(i.kind, i.status) for i in items], [(FUNCTION, UNKNOWN)])

    def test_removed_memory_and_cpu_use_defaults(self):
        items = run_functions({'fnA': endpoint()}, [live_fn('fnA', memory='512Mi', cpu='2')])
        options = [i for i in items if i.kind == FUNCTION_OPTIONS]
        self.assertEqual([i.reason for i in options], ['memory 512 -> 256; cpu 2.0 -> 1.0'])

    def test_two_live_regions_are_compared_separately(self):
        old = live_fn('fnA', region='us-central1')
        old['updateTime'] = '2026-11-09T12:48:21Z'
        items = run_functions({'fnA': endpoint(regions=('asia-south1', 'us-central1'))}, [live_fn('fnA'), old])
        self.assertEqual([(i.name, i.status) for i in items],
                         [('asia-south1/fnA', IN_SYNC), ('us-central1/fnA', DIFFERENT)])

    def test_in_sync_when_code_landed_before_deploy_and_defaults_match(self):
        items = run_functions({'fnA': endpoint()}, [live_fn('fnA')])
        self.assertEqual(summary(items), [
            (FUNCTION, 'asia-south1/fnA', IN_SYNC, 'code landed 2026-11-09 13:48 UTC',
             'deployed 2026-11-09 14:48 UTC', '', []),
        ])

    def test_same_name_with_code_landed_after_live_deploy_is_not_in_sync(self):
        items = run_functions({'fnA': endpoint()}, [live_fn('fnA')], {'fnA': DEPLOYED + HOUR})
        self.assertEqual(summary(items), [
            (FUNCTION, 'asia-south1/fnA', DIFFERENT, 'code landed 2026-11-09 15:48 UTC',
             'deployed 2026-11-09 14:48 UTC', 'code landed on master after the live deploy', ['#900']),
        ])

    def test_unknown_code_time_is_unknown(self):
        items = run_functions({'fnA': endpoint()}, [live_fn('fnA')], {})
        self.assertEqual(summary(items), [
            (FUNCTION, 'asia-south1/fnA', UNKNOWN, '', 'deployed 2026-11-09 14:48 UTC',
             'function history is not available', []),
        ])

    def test_memory_difference_adds_function_options_item(self):
        items = run_functions({'fnA': endpoint(memory=512)}, [live_fn('fnA')])
        options = [i for i in items if i.kind == FUNCTION_OPTIONS]
        self.assertEqual(summary(options), [
            (FUNCTION_OPTIONS, 'asia-south1/fnA', DIFFERENT, 'memory=512 cpu=1.0',
             'memory=256 cpu=1.0 maxInstances=20', 'memory 256 -> 512', []),
        ])
        self.assertEqual(items[0].status, IN_SYNC)

    def test_gen1_cpu_for_256_mb_matches_live_fraction(self):
        items = run_functions({'fnA': endpoint(memory=256, cpu='gcf_gen1')}, [live_fn('fnA', cpu='0.1666')])
        self.assertEqual([i for i in items if i.kind == FUNCTION_OPTIONS], [])
        self.assertEqual(items[0].status, IN_SYNC)

    def test_max_instances_difference_adds_options_item(self):
        items = run_functions({'fnA': endpoint(max_instances=10)}, [live_fn('fnA')])
        options = [i for i in items if i.kind == FUNCTION_OPTIONS]
        self.assertEqual(summary(options), [
            (FUNCTION_OPTIONS, 'asia-south1/fnA', DIFFERENT, 'memory=256 cpu=1.0 maxInstances=10',
             'memory=256 cpu=1.0 maxInstances=20', 'maxInstances 20 -> 10', []),
        ])

    def test_unset_max_instances_never_adds_options_item(self):
        items = run_functions({'fnA': endpoint(max_instances=None)}, [live_fn('fnA', max_instances=20)])
        self.assertEqual([i for i in items if i.kind == FUNCTION_OPTIONS], [])

    def test_live_memory_in_gi_parses_as_1024_mb(self):
        same = run_functions({'fnA': endpoint(memory=1024)}, [live_fn('fnA', memory='1Gi')])
        self.assertEqual([i for i in same if i.kind == FUNCTION_OPTIONS], [])
        differ = run_functions({'fnA': endpoint(memory=512)}, [live_fn('fnA', memory='1Gi')])
        options = [i for i in differ if i.kind == FUNCTION_OPTIONS]
        self.assertEqual([i.reason for i in options], ['memory 1024 -> 512'])

    def test_region_in_manifest_but_not_live_is_missing_live(self):
        items = run_functions({'fnA': endpoint()}, [])
        self.assertEqual(summary(items), [
            (FUNCTION, 'asia-south1/fnA', MISSING_LIVE, 'memory=256 cpu=1.0', '', '', []),
        ])

    def test_live_function_not_in_manifest_is_live_only(self):
        items = run_functions({}, [live_fn('fnOld')])
        self.assertEqual(summary(items), [
            (FUNCTION, 'asia-south1/fnOld', LIVE_ONLY, '', 'deployed 2026-11-09 14:48 UTC', 'not exported on master',
             []),
        ])

    def test_failed_live_function_is_different(self):
        items = run_functions({'fnA': endpoint()}, [live_fn('fnA', state='FAILED')])
        self.assertEqual(summary(items), [
            (FUNCTION, 'asia-south1/fnA', DIFFERENT, 'memory=256 cpu=1.0', 'FAILED',
             'live function is not ACTIVE', []),
        ])

    def test_two_regions_with_one_live_gives_one_missing_and_one_other_item(self):
        items = run_functions({'fnB': endpoint(regions=('asia-south1', 'us-central1'))}, [live_fn('fnB')])
        self.assertEqual(summary(items), [
            (FUNCTION, 'asia-south1/fnB', IN_SYNC, 'code landed 2026-11-09 13:48 UTC',
             'deployed 2026-11-09 14:48 UTC', '', []),
            (FUNCTION, 'us-central1/fnB', MISSING_LIVE, 'memory=256 cpu=1.0', '', '', []),
        ])


class CompareWorkerTest(unittest.TestCase):
    def test_unknown_local_history_is_not_a_crash_or_in_sync(self):
        item = deploy_drift.compare_worker('prism-worker', UPDATE_TIME, None, [])
        self.assertEqual(item.status, UNKNOWN)

    def test_in_sync_when_worker_changed_before_deploy(self):
        item = deploy_drift.compare_worker('prism-worker', UPDATE_TIME, DEPLOYED - HOUR, ['#901'])
        self.assertEqual(summary([item]), [
            (WORKER_KIND, 'prism-worker', IN_SYNC, 'changed 2026-11-09 13:48 UTC',
             'deployed 2026-11-09 14:48 UTC', '', []),
        ])

    def test_different_when_worker_changed_after_deploy(self):
        item = deploy_drift.compare_worker('prism-worker', UPDATE_TIME, DEPLOYED + HOUR, ['#901'])
        self.assertEqual(summary([item]), [
            (WORKER_KIND, 'prism-worker', DIFFERENT, 'changed 2026-11-09 15:48 UTC',
             'deployed 2026-11-09 14:48 UTC', 'worker code landed on master after the live deploy', ['#901']),
        ])

    def test_no_live_deployment_is_missing_live(self):
        item = deploy_drift.compare_worker('prism-worker', None, DEPLOYED - HOUR, ['#901'])
        self.assertEqual(summary([item]), [
            (WORKER_KIND, 'prism-worker', MISSING_LIVE, 'changed 2026-11-09 13:48 UTC', 'no deployment', '', ['#901']),
        ])


class CompareRemoteConfigTest(unittest.TestCase):
    def test_in_sync_missing_live_and_live_only(self):
        items = deploy_drift.compare_remote_config(
            {'streak_enabled': 'lib/streak.dart:12', 'walls_limit': 'functions/src/limits.ts:7'},
            {'streak_enabled', 'old_banner'})
        self.assertEqual(summary(items), [
            (REMOTE_CONFIG, 'streak_enabled', IN_SYNC, 'lib/streak.dart:12', 'published', '', []),
            (REMOTE_CONFIG, 'walls_limit', MISSING_LIVE, 'functions/src/limits.ts:7', '',
             'not in the template, so the code default applies', []),
            (REMOTE_CONFIG, 'old_banner', LIVE_ONLY, '', 'published',
             'no resolved code read on master; old app builds may', []),
        ])


class MigrationItemsTest(unittest.TestCase):
    def test_every_script_is_unknown_and_notes_come_from_the_dict(self):
        notes = {'src/a.ts': {'npm': 'npm run migrate:a', 'pr': '#880', 'note': 'Backfills walls.'}}
        items = deploy_drift.migration_items(['src/a.ts', 'src/b.ts'], notes)
        self.assertEqual(summary(items), [
            (MIGRATION, 'src/a.ts', UNKNOWN, 'npm run migrate:a', 'cannot be read',
             'ask the owner. Backfills walls.', ['#880']),
            (MIGRATION, 'src/b.ts', UNKNOWN, 'node lib/...', 'cannot be read',
             'ask the owner. No note in a PR or the docs.', []),
        ])
        for item in items:
            self.assertTrue(item.reason.startswith('ask the owner'))


class BuildPlanTest(unittest.TestCase):
    def test_steps_follow_release_order_and_skip_in_sync_items(self):
        items = [
            DriftItem(WORKER_KIND, 'prism-worker', 'changed 2026-11-09 15:48 UTC', 'no deployment', MISSING_LIVE,
                      prs=['#901']),
            DriftItem(RULES, 'firestore.rules', '+0 -0 lines vs live', 'released 2026-11-09 14:48 UTC', IN_SYNC),
            DriftItem(FUNCTION, 'asia-south1/fnA', 'code landed 2026-11-09 15:48 UTC',
                      'deployed 2026-11-09 14:48 UTC', DIFFERENT, 'code landed on master after the live deploy',
                      ['#900']),
            DriftItem(REMOTE_CONFIG, 'walls_limit', 'functions/src/limits.ts:7', '', MISSING_LIVE,
                      'not in the template, so the code default applies'),
            DriftItem(RULES, 'firestore.rules', '+1 -1 lines vs live', 'released 2026-11-09 14:48 UTC', DIFFERENT,
                      'master rules text differs from the live ruleset', ['#899']),
        ]
        plan = deploy_drift.build_plan(items, 'prism-wallpapers')
        self.assertEqual([s['title'] for s in plan],
                         ['Firestore rules', 'Cloud Functions', 'Cloudflare worker', 'Remote Config keys'])
        self.assertEqual([s['step'] for s in plan], [1, 2, 3, 4])
        self.assertEqual([i['name'] for i in plan[0]['items']], ['firestore.rules'])
        self.assertEqual(plan[0]['items'][0]['status'], DIFFERENT)
        self.assertEqual(plan[0]['items'][0]['prs'], ['#899'])
        self.assertEqual(plan[0]['command'],
                         'make rules-test && firebase deploy --only firestore:rules --project prism-wallpapers '
                         '--non-interactive')
        self.assertEqual([i['name'] for i in plan[1]['items']], ['asia-south1/fnA'])
        self.assertEqual([i['name'] for i in plan[2]['items']], ['prism-worker'])
        self.assertEqual([i['name'] for i in plan[3]['items']], ['walls_limit'])


class ParseTimeTest(unittest.TestCase):
    def test_nine_fraction_digits_with_z(self):
        parsed = deploy_drift.parse_time('2026-11-09T14:48:21.838834602Z')
        self.assertEqual(parsed, datetime(2026, 11, 9, 14, 48, 21, 838834, tzinfo=timezone.utc))
        self.assertEqual(parsed.utcoffset().total_seconds(), 0)

    def test_whole_seconds_with_z(self):
        parsed = deploy_drift.parse_time('2026-11-09T14:48:21Z')
        self.assertEqual(parsed, datetime(2026, 11, 9, 14, 48, 21, tzinfo=timezone.utc))


class RenderPlanTest(unittest.TestCase):
    def test_items_with_same_kind_status_reason_and_prs_share_one_line(self):
        plan = [{
            'step': 1, 'title': 'Cloud Functions', 'reason': 'Deploy first.', 'command': 'make functions-deploy',
            'items': [
                asdict(DriftItem(FUNCTION, 'asia-south1/fnA', 'm', 'l', DIFFERENT,
                                 'code landed on master after the live deploy', ['#900'])),
                asdict(DriftItem(FUNCTION, 'asia-south1/fnB', 'm', 'l', DIFFERENT,
                                 'code landed on master after the live deploy', ['#900'])),
            ],
        }]
        lines = deploy_drift.render_plan(plan).splitlines()
        self.assertIn('1. Cloud Functions (2 items)', lines)
        self.assertIn('   - 2 function items (different) [#900]: code landed on master after the live deploy', lines)
        self.assertIn('       asia-south1/fnA, asia-south1/fnB', lines)
        self.assertEqual(len([line for line in lines if line.startswith('   - ')]), 1)


class SourceFixtureTest(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.root = Path(self.stack.enter_context(tempfile.TemporaryDirectory()))
        self.stack.enter_context(patch.object(deploy_drift, 'ROOT', self.root))
        self.stack.enter_context(patch.object(deploy_drift, 'FUNCTIONS', self.root / 'functions'))
        self.stack.enter_context(patch.object(deploy_drift, 'WORKER', self.root / 'infra/cloudflare/worker'))
        self.stack.enter_context(patch.object(deploy_drift, 'MIGRATION_NOTES', self.root / 'notes.json'))

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
        return target

    def test_import_closure_includes_all_literal_relative_import_forms(self):
        start = self.write('functions/src/a.ts', '''
import './side';
export * from './star';
import x = require('./equal');
const later = import('./dynamic');
import {value} from "./static";
''')
        for module in ('side', 'star', 'equal', 'dynamic', 'static'):
            self.write(f'functions/src/{module}.ts', 'export const value = 1;')
        self.assertEqual(deploy_drift.import_closure(start), {
            'functions/src/a.ts', 'functions/src/side.ts', 'functions/src/star.ts',
            'functions/src/equal.ts', 'functions/src/dynamic.ts', 'functions/src/static.ts'})

    def test_unresolved_relative_import_is_not_silently_ignored(self):
        start = self.write('functions/src/a.ts', "export * from './missing';")
        with self.assertRaises(deploy_drift.DriftError):
            deploy_drift.import_closure(start)

    def test_dynamic_import_without_literal_is_unknown(self):
        start = self.write('functions/src/a.ts', 'const module = import(computePath());')
        with self.assertRaises(deploy_drift.DriftError):
            deploy_drift.import_closure(start)

    def test_dynamic_import_literal_prefix_is_not_the_whole_dependency(self):
        start = self.write('functions/src/a.ts', "const module = import('./base' + suffix);")
        self.write('functions/src/base.ts', '')
        with self.assertRaises(deploy_drift.DriftError):
            deploy_drift.import_closure(start)

    def test_dotted_relative_module_name_is_not_truncated(self):
        start = self.write('functions/src/a.ts', "import './helper.util';")
        self.write('functions/src/helper.util.ts', 'export const value = 1;')
        self.assertEqual(deploy_drift.import_closure(start), {'functions/src/a.ts', 'functions/src/helper.util.ts'})

    def test_remote_config_double_quotes_dotted_keys_and_cross_file_wrapper(self):
        self.write('lib/config.dart', '''
import 'firebase_remote_config.dart';
const String flag = "feature.enabled";
String readFlag(String key) => remoteConfig.getString(key);
final first = remoteConfig.getString(flag);
final second = remoteConfig.getString("literal.with.dots");
''')
        self.write('lib/caller.dart', '''final value = readFlag("wrapped_key");''')
        self.assertEqual(set(deploy_drift.remote_config_reads()),
                         {'feature.enabled', 'literal.with.dots', 'wrapped_key'})

    def test_remote_config_platform_conditional_keys(self):
        self.write('lib/config.dart', '''
final String minBuildKey = defaultTargetPlatform == TargetPlatform.iOS ? 'min_build_ios' : 'min_build_android';
final value = remoteConfig?.getInt(minBuildKey);
''')
        self.assertEqual(set(deploy_drift.remote_config_reads()), {'min_build_ios', 'min_build_android'})

    def test_remote_config_read_through_a_function_value_field(self):
        self.write('lib/hints.dart', '''
class Hints {
  static const String enabledKey = 'hints.enabled';
  static const String remoteEnabledKey = 'hints_enabled';
  final String Function(String) _remoteConfig;
  Hints({String Function(String)? remoteConfig}) : _remoteConfig = remoteConfig ?? _defaultRemoteConfig;
  bool get on => _remoteConfig(remoteEnabledKey) == 'true' && _read<bool>(enabledKey, true);
  static String _defaultRemoteConfig(String key) => FirebaseInit.remoteConfigIfInitialized?.getString(key) ?? '';
}
''')
        self.assertEqual(set(deploy_drift.remote_config_reads()), {'hints_enabled'})

    def test_qualified_remote_config_constants_keep_class_scope(self):
        self.write('lib/config.dart', '''
class ConfigA { static const key = 'feature_a'; }
class ConfigB { static const key = 'feature_b'; }
final a = remoteConfig.getString(ConfigA.key);
final b = remoteConfig.getString(ConfigB.key);
''')
        self.assertEqual(set(deploy_drift.remote_config_reads()), {'feature_a', 'feature_b'})

    def test_private_remote_config_wrappers_do_not_mix_files(self):
        self.write('lib/config.dart', '''
String _read(String key) => remoteConfig.getString(key);
final a = _read('feature_a');
''')
        self.write('lib/other.dart', '''
String _read(String key) => preferences.getString(key);
final b = _read('not_remote_config');
''')
        self.assertEqual(set(deploy_drift.remote_config_reads()), {'feature_a'})

    def test_unknown_remote_config_expression_is_reported(self):
        self.write('lib/config.dart', '''final key = computeKey(); final value = remoteConfig.getString(key);''')
        reads = deploy_drift.remote_config_reads()
        self.assertTrue(getattr(reads, 'unresolved', []))

    def test_remote_config_expression_prefix_is_not_a_literal_key(self):
        self.write('lib/config.dart', '''final value = remoteConfig.getString('prefix' + suffix);''')
        reads = deploy_drift.remote_config_reads()
        self.assertTrue(getattr(reads, 'unresolved', []))
        self.assertNotIn('prefix', reads)

    def test_remote_config_function_call_is_unresolved(self):
        self.write('lib/config.dart', '''final value = remoteConfig.getString(computeKey());''')
        self.assertTrue(deploy_drift.remote_config_reads().unresolved)

    def test_worker_list_does_not_install_packages_and_empty_list_is_missing(self):
        self.write('infra/cloudflare/worker/wrangler.toml', 'name = "worker"\n')
        self.write('web/package.json', '{"devDependencies": {"wrangler": "^4.0.0"}}')
        self.write('web/node_modules/.bin/wrangler', '')
        self.write('infra/cloudflare/worker/node_modules/.bin/wrangler', '')

        def read_only_run(command, **kwargs):
            self.assertNotIn('npx', command)
            self.assertNotIn('--yes', command)
            self.assertEqual(command[1:3], ['deployments', 'list'])
            return '[]'

        with patch.object(deploy_drift, 'run', side_effect=read_only_run):
            self.assertEqual(deploy_drift.live_worker(), ('worker', None))

    def test_empty_template_has_no_values_and_group_keys_are_included(self):
        with patch.object(deploy_drift, 'google_get', return_value={}):
            self.assertEqual(deploy_drift.live_template_keys('p'), set())
        template = {'parameters': {'a': {'defaultValue': {'value': 'SECRET'}}},
                    'parameterGroups': {'group': {'parameters': {'b': {'defaultValue': {'value': 'SECRET'}}}}}}
        with patch.object(deploy_drift, 'google_get', return_value=template):
            self.assertEqual(deploy_drift.live_template_keys('p'), {'a', 'b'})

    def prepare_collection(self):
        self.write('firestore.rules', 'allow read;')
        self.write('firestore.indexes.json', '{"indexes": [], "fieldOverrides": []}')
        self.write('functions/src/index.ts', '')
        self.write('notes.json', '{}')
        history = MagicMock()
        history.landed.return_value = DEPLOYED - HOUR
        history.landed_under.return_value = DEPLOYED - HOUR
        history.prs_since.return_value = []
        history.prs_since_under.return_value = []
        fixtures = {
            'History': MagicMock(return_value=history), 'live_rules': ('allow read;', datetime.fromtimestamp(DEPLOYED, timezone.utc)),
            'gcloud_json': [], 'functions_manifest': {}, 'live_functions': [],
            'live_worker': ('worker', UPDATE_TIME), 'remote_config_reads': {}, 'live_template_keys': set(),
            'apply_scripts': ['functions/src/migrate.ts'],
        }
        mocks = {}
        self.stack.enter_context(patch.object(deploy_drift, 'git', return_value=''))
        for name, value in fixtures.items():
            replacement = value if name == 'History' else MagicMock(return_value=value)
            mocks[name] = self.stack.enter_context(patch.object(deploy_drift, name, replacement))
        return mocks

    def test_dirty_checkout_does_not_claim_deployed_code_matches(self):
        self.prepare_collection()
        with patch.object(deploy_drift, 'git', return_value='functions/src/fn.ts\ninfra/cloudflare/worker/src/index.ts\n'):
            items, errors = deploy_drift.collect('p')
        self.assertIn((FUNCTION, UNKNOWN), [(i.kind, i.status) for i in items])
        self.assertIn((WORKER_KIND, UNKNOWN), [(i.kind, i.status) for i in items])
        self.assertTrue(errors)

    def test_unresolved_remote_config_keeps_known_comparisons_and_unknown(self):
        mocks = self.prepare_collection()
        reads = deploy_drift.RemoteConfigReads()
        reads['known'] = 'lib/config.dart:1'
        reads.unresolved.append('lib/config.dart:2')
        mocks['remote_config_reads'].return_value = reads
        mocks['live_template_keys'].return_value = {'known'}
        items, errors = deploy_drift.collect('p')
        self.assertEqual([(i.kind, i.status) for i in items if i.kind == REMOTE_CONFIG],
                         [(REMOTE_CONFIG, IN_SYNC), (REMOTE_CONFIG, UNKNOWN)])
        self.assertEqual(errors, [])

    def test_unexpected_live_failure_is_redacted_and_other_sources_continue(self):
        mocks = self.prepare_collection()
        mocks['live_template_keys'].side_effect = TypeError('SECRET_TEMPLATE_VALUE')
        items, errors = deploy_drift.collect('p')
        self.assertEqual([(i.kind, i.status) for i in items if i.kind == REMOTE_CONFIG], [(REMOTE_CONFIG, UNKNOWN)])
        self.assertEqual([(i.kind, i.status) for i in items if i.kind == MIGRATION], [(MIGRATION, UNKNOWN)])
        self.assertEqual(len(errors), 1)
        self.assertNotIn('SECRET_TEMPLATE_VALUE', json.dumps([asdict(i) for i in items]) + str(errors))

    def test_ttl_failure_keeps_successful_index_results(self):
        mocks = self.prepare_collection()
        self.write('firestore.indexes.json', json.dumps({'indexes': [
            {'collectionGroup': 'walls', 'fields': [{'fieldPath': 'author', 'order': 'ASCENDING'}]}]}))
        mocks['gcloud_json'].side_effect = [[{
            'name': 'projects/p/databases/(default)/collectionGroups/walls/indexes/W1', 'state': 'READY',
            'fields': [{'fieldPath': 'author', 'order': 'ASCENDING'}]}], RuntimeError('SECRET')]
        items, errors = deploy_drift.collect('p')
        self.assertEqual([(i.kind, i.status) for i in items if i.kind in (INDEX, TTL)],
                         [(INDEX, IN_SYNC), (TTL, UNKNOWN)])
        self.assertEqual(len(errors), 1)
        self.assertNotIn('SECRET', str(errors))

    def test_history_failure_keeps_live_reads_and_marks_code_unknown(self):
        mocks = self.prepare_collection()
        mocks['History'].side_effect = deploy_drift.DriftError('SECRET_HISTORY')
        items, errors = deploy_drift.collect('p')
        self.assertEqual([(i.kind, i.status) for i in items if i.kind == RULES], [(RULES, IN_SYNC)])
        self.assertIn((FUNCTION, UNKNOWN), [(i.kind, i.status) for i in items])
        self.assertIn((WORKER_KIND, UNKNOWN), [(i.kind, i.status) for i in items])
        self.assertTrue(errors)
        self.assertNotIn('SECRET_HISTORY', str(errors))

    def test_function_entrypoint_change_is_in_code_history(self):
        mocks = self.prepare_collection()
        self.write('functions/src/fn.ts', '')
        self.write('functions/src/index.ts', 'export {fnA} from "./fn";')
        mocks['functions_manifest'].return_value = {'fnA': endpoint()}
        mocks['live_functions'].return_value = [live_fn('fnA')]
        history = mocks['History'].return_value
        history.landed.side_effect = lambda paths: DEPLOYED + HOUR if 'functions/src/index.ts' in paths else DEPLOYED - HOUR
        items, errors = deploy_drift.collect('p')
        self.assertEqual([(i.kind, i.status) for i in items if i.kind == FUNCTION], [(FUNCTION, DIFFERENT)])
        self.assertEqual(errors, [])

    def test_entrypoint_side_effect_import_changes_are_in_function_history(self):
        mocks = self.prepare_collection()
        self.write('functions/src/fn.ts', '')
        self.write('functions/src/index.ts', "import './globalOptions'; export {fnA} from './fn';")
        self.write('functions/src/globalOptions.ts', 'setGlobalOptions({memory: "512MiB"});')
        mocks['functions_manifest'].return_value = {'fnA': endpoint()}
        mocks['live_functions'].return_value = [live_fn('fnA')]
        history = mocks['History'].return_value
        history.landed.side_effect = lambda paths: DEPLOYED + HOUR if 'functions/src/globalOptions.ts' in paths else DEPLOYED - HOUR
        items, errors = deploy_drift.collect('p')
        self.assertEqual([(i.kind, i.status) for i in items if i.kind == FUNCTION], [(FUNCTION, DIFFERENT)])
        self.assertEqual(errors, [])

    def test_live_secrets_are_absent_from_json_and_table(self):
        mocks = self.prepare_collection()
        self.write('.firebaserc', '{"projects":{"default":"p"}}')
        self.write('functions/src/fn.ts', '')
        self.write('functions/src/index.ts', 'export {fnA} from "./fn";')
        mocks['functions_manifest'].return_value = {'fnA': endpoint()}
        fn = live_fn('fnA')
        fn['serviceConfig']['environmentVariables'] = {'API_KEY': 'SECRET_ENV_VALUE'}
        fn['serviceConfig']['secretEnvironmentVariables'] = [{'secret': 'SECRET_REFERENCE'}]
        mocks['live_functions'].return_value = [fn]
        mocks['live_template_keys'].return_value = {'published_key'}
        for args in ([], ['--json']):
            with self.subTest(args=args), patch.object(deploy_drift, 'git', side_effect=lambda *a: 'abc123' if a[0] == 'rev-parse' else ''), \
                    redirect_stdout(io.StringIO()) as out, redirect_stderr(io.StringIO()) as err:
                self.assertEqual(deploy_drift.main(args), 0)
                self.assertIn('published_key', out.getvalue())
                self.assertNotIn('SECRET', out.getvalue() + err.getvalue())

    def test_live_function_invalid_option_does_not_leak_its_value(self):
        mocks = self.prepare_collection()
        self.write('functions/src/fn.ts', '')
        self.write('functions/src/index.ts', 'export {fnA} from "./fn";')
        mocks['functions_manifest'].return_value = {'fnA': endpoint()}
        fn = live_fn('fnA')
        fn['serviceConfig']['availableCpu'] = 'SECRET_INVALID_VALUE'
        mocks['live_functions'].return_value = [fn]
        items, errors = deploy_drift.collect('p')
        self.assertEqual([(i.kind, i.status) for i in items if i.kind == FUNCTION], [(FUNCTION, UNKNOWN)])
        self.assertEqual(len(errors), 1)
        self.assertNotIn('SECRET', json.dumps([asdict(i) for i in items]) + str(errors))


class SafeReadsTest(unittest.TestCase):
    def test_unexpected_top_level_error_has_no_traceback_or_secret(self):
        for args in ([], ['--json']):
            with self.subTest(args=args), patch.object(deploy_drift, 'collect', side_effect=TypeError('SECRET')), \
                    redirect_stdout(io.StringIO()) as out, redirect_stderr(io.StringIO()) as err:
                self.assertEqual(deploy_drift.main(args), 1)
                self.assertNotIn('SECRET', out.getvalue() + err.getvalue())
                self.assertNotIn('Traceback', out.getvalue() + err.getvalue())

    def test_subprocess_stderr_never_reaches_exception(self):
        proc = subprocess.CompletedProcess(['gcloud'], 1, 'SECRET_STDOUT', 'SECRET_STDERR')
        with patch.object(deploy_drift.subprocess, 'run', return_value=proc):
            with self.assertRaises(deploy_drift.DriftError) as caught:
                deploy_drift.run(['gcloud', 'auth', 'print-access-token'])
        self.assertNotIn('SECRET', str(caught.exception))

    def test_subprocess_os_error_never_reaches_exception(self):
        with patch.object(deploy_drift.subprocess, 'run', side_effect=OSError('SECRET_OS_ERROR')):
            with self.assertRaises(deploy_drift.DriftError) as caught:
                deploy_drift.run(['gcloud', 'auth', 'print-access-token'])
        self.assertNotIn('SECRET', str(caught.exception))

    def test_google_transport_and_http_errors_do_not_expose_values(self):
        for error in (urllib.error.URLError('SECRET_TOKEN'),
                      urllib.error.HTTPError('https://example.invalid/SECRET', 403, 'SECRET', {}, None)):
            with self.subTest(error=type(error).__name__), patch.object(deploy_drift, 'run', return_value='SECRET_TOKEN'), \
                    patch.object(deploy_drift.urllib.request, 'urlopen', side_effect=error):
                with self.assertRaises(deploy_drift.DriftError) as caught:
                    deploy_drift.google_get('https://example.invalid/config', 'p')
                self.assertNotIn('SECRET', str(caught.exception))

    def test_main_failure_exit_and_output_are_redacted_in_both_formats(self):
        item = DriftItem(REMOTE_CONFIG, '*', '', '', UNKNOWN, 'could not read source')
        for args in ([], ['--json']):
            with self.subTest(args=args), patch.object(deploy_drift, 'collect', return_value=([item], ['remote config key: could not read source'])), \
                    patch.object(deploy_drift, 'git', return_value='abc123'), redirect_stdout(io.StringIO()) as out, \
                    redirect_stderr(io.StringIO()) as err:
                self.assertEqual(deploy_drift.main(args), 1)
                self.assertIn('unknown', out.getvalue())
                self.assertNotIn('Traceback', err.getvalue())


class HistoryTest(unittest.TestCase):
    def test_missing_blame_history_does_not_abort_a_comparison(self):
        with patch.object(deploy_drift, 'git', side_effect=deploy_drift.DriftError('SECRET')):
            self.assertEqual(deploy_drift.pr_for_line('firestore.rules', 1), '')

    def test_merge_time_and_pr_come_from_first_parent_diff(self):
        def history_git(*args):
            if args[0] == 'rev-parse':
                return 'false\n'
            merge_files = 'functions/src/a.ts' if '--diff-merges=first-parent' in args else ''
            return f'\x00200\tmerge_sha\tMerge pull request #900 from branch\n{merge_files}\n' \
                   '\x00100\told_sha\tOld change (#899)\nfunctions/src/a.ts\n'

        with patch.object(deploy_drift, 'git', side_effect=history_git):
            history = deploy_drift.History()
        self.assertEqual(history.landed({'functions/src/a.ts'}), 200)
        self.assertEqual(history.prs_since({'functions/src/a.ts'}, 150), ['#900'])

    def test_shallow_boundary_commit_counts_as_a_later_landing_not_a_failure(self):
        boundary = '\x001800000000\tboundary_sha\tSnapshot\nfunctions/src/a.ts\nfunctions/src/b.ts\n'
        with patch.object(deploy_drift, 'git', return_value=boundary):
            history = deploy_drift.History()
        self.assertEqual(history.landed({'functions/src/b.ts'}), 1800000000)
        # live_fn was deployed 2026-11-09, before the 2027-01-15 boundary time.
        items = deploy_drift.compare_functions(
            {'fnA': endpoint()}, [live_fn('fnA')], {'fnA': history.landed({'functions/src/a.ts'})},
            lambda name, since: [])
        self.assertEqual(items[0].status, DIFFERENT)

    def test_blame_uses_first_merge_not_a_later_merge_for_pr(self):
        def history_git(*args):
            if args[0] == 'blame':
                return 'feature_sha 1 1 1\n'
            if args[0] == 'rev-list' and '--first-parent' in args:
                return 'head_sha\nmerge_sha\nold_sha\n'
            if args[0] == 'rev-list':
                return 'head_sha\nmerge_sha\n'
            return 'Merge pull request #900 from branch' if args[-1] == 'merge_sha' else 'Later change (#901)'

        with patch.object(deploy_drift, 'git', side_effect=history_git):
            self.assertEqual(deploy_drift.pr_for_line('firestore.rules', 1), '#900')


class RunErrorMessageTest(unittest.TestCase):
    def test_failed_command_names_program_and_exit_code_but_not_stderr(self):
        with self.assertRaises(deploy_drift.DriftError) as raised:
            deploy_drift.run([sys.executable, '-c', 'import sys; sys.stderr.write("TOKEN_VALUE"); sys.exit(3)'])
        self.assertEqual(str(raised.exception), f'{Path(sys.executable).name} -c exited 3')


if __name__ == '__main__':
    unittest.main()
