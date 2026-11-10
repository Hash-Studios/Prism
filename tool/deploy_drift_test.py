"""Unit tests for the pure compare logic in tool/deploy_drift.py. Fixture data only: no subprocess, no network."""

from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
import sys
import unittest


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

    def test_unknown_code_time_is_different(self):
        items = run_functions({'fnA': endpoint()}, [live_fn('fnA')], {})
        self.assertEqual(summary(items), [
            (FUNCTION, 'asia-south1/fnA', DIFFERENT, 'code landed unknown', 'deployed 2026-11-09 14:48 UTC',
             'code landed on master after the live deploy', ['#900']),
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
             'no code on master reads it; old app builds may', []),
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


if __name__ == '__main__':
    unittest.main()
