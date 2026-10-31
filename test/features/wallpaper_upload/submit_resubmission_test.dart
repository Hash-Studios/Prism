import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/data/resubmission_repository.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/submit_resubmission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/coins_test_backend.dart';
import '../../support/in_memory_local_store.dart';

class _Store extends InMemoryLocalStore {
  void Function(String key)? afterWrite;

  @override
  Future<void> set(String key, Object? value) async {
    await super.set(key, value);
    afterWrite?.call(key);
  }
}

class _Client extends Mock implements FirestoreClient {}

class _Repository extends ResubmissionRepository {
  _Repository() : super(_Client());
  bool loseResponse = false;

  @override
  Future<ResubmissionAdmission> submit({
    required String operationId,
    required String rejectedDocId,
    required GitHubContent original,
    required GitHubContent thumbnail,
    required SubmissionMetadata metadata,
    required String resolution,
    required String size,
  }) async {
    if (loseResponse) {
      loseResponse = false;
      throw StateError('Response lost after admission');
    }
    return const ResubmissionAdmission(wallDocId: 'admitted', logicalId: 'logical', attempt: 1);
  }
}

Future<void> _submit(
  _Repository repository, {
  String operation = 'operation',
  String ownerUid = 'owner',
  void Function(CoinMutationResult result, String ownerUid)? onUploadAward,
}) => SubmitResubmission(repository)
    .call(
      ownerUid: ownerUid,
      operationId: operation,
      rejectedDocId: 'rejected',
      original: const GitHubContent(downloadUrl: '', path: 'original', sha: 'sha'),
      thumbnail: const GitHubContent(downloadUrl: '', path: 'thumbnail', sha: 'sha'),
      metadata: const SubmissionMetadata(),
      resolution: '1080x1920',
      size: '1MB',
      onUploadAward: onUploadAward,
    )
    .then((_) {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  setUp(() async {
    store = _Store();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(store));
    app_state.prismUser = constants.createGuestPrismUser()
      ..id = 'owner'
      ..loggedIn = true;
    await UploadQuota.incrementWeeklyUploads();
  });
  tearDown(() async {
    app_state.prismUser = constants.createGuestPrismUser();
    await getIt.reset();
  });

  for (final scenario in [
    'confirmed',
    'failed',
    'unchanged',
    'zero delta',
    'negative delta',
    'account changed',
    'signed out',
  ]) {
    test('resubmission reports only a confirmed owner-bound award: $scenario', () async {
      final backend = CoinsTestBackend();
      await backend.install();
      addTearDown(() => backend.onCall = (_, _) async => <String, Object?>{'success': false, 'changed': false});
      final owner = app_state.prismUser.id;
      var awardCalls = 0;
      backend.onCall = (name, params) async {
        if (name == 'reconcileRankRewards') return <String, Object?>{'success': true};
        expect(name, 'awardCoins');
        expect(params['action'], 'firstWallpaperUpload');
        awardCalls++;
        if (scenario == 'account changed') app_state.prismUser.id = 'another-owner';
        if (scenario == 'signed out') app_state.prismUser.loggedIn = false;
        return <String, Object?>{
          'success': scenario != 'failed',
          'changed': scenario != 'unchanged',
          'delta': scenario == 'zero delta'
              ? 0
              : scenario == 'negative delta'
              ? -37
              : 37,
          'previousBalance': 100,
          'currentBalance': 137,
        };
      };
      final receipts = <({int coins, String ownerId})>[];
      await _submit(
        _Repository(),
        ownerUid: owner,
        onUploadAward: (result, ownerUid) => receipts.add((coins: result.delta, ownerId: ownerUid)),
      );

      expect(awardCalls, 1);
      expect(receipts, scenario == 'confirmed' ? [(coins: 37, ownerId: owner)] : isEmpty);
    });
  }

  test('successful admission replay after restart charges local quota once', () async {
    await _submit(_Repository());
    expect(UploadQuota.currentUploadsThisWeek(), 2);
    final restored = InMemoryLocalStore()..data.addAll(store.data);
    await getIt.unregister<SettingsLocalDataSource>();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(restored));
    await _submit(_Repository());
    expect(UploadQuota.currentUploadsThisWeek(), 2);
    await _submit(_Repository(), operation: 'different');
    expect(UploadQuota.currentUploadsThisWeek(), 3);
  });

  test('lost response then repeated successful retries charge once', () async {
    final repository = _Repository()..loseResponse = true;
    await expectLater(_submit(repository), throwsStateError);
    expect(UploadQuota.currentUploadsThisWeek(), 1);
    await _submit(repository);
    await _submit(repository);
    expect(UploadQuota.currentUploadsThisWeek(), 2);
  });
  for (final counterWritten in [false, true]) {
    test('restart recovers quota journal with counter written $counterWritten', () async {
      final settings = getIt<SettingsLocalDataSource>();
      await settings.set('uploadQuotaOperations/owner', <String, Object?>{
        'operation': <String, Object?>{'week': UploadQuota.storedWeekStart, 'count': 2},
      });
      if (counterWritten) await settings.set('uploadsThisWeek', 2);
      await _submit(_Repository());
      await _submit(_Repository());
      expect(UploadQuota.currentUploadsThisWeek(), 2);
    });
  }

  test('a replay in another week does not charge that week and cleanup removes owner receipts', () async {
    final old = DateTime(2026, 1, 5);
    final next = DateTime(2026, 1, 12);
    await UploadQuota.incrementWeeklyUploads(now: old, ownerUid: 'owner', operationId: 'old');
    await UploadQuota.incrementWeeklyUploads(now: next);
    await UploadQuota.incrementWeeklyUploads(now: next, ownerUid: 'owner', operationId: 'old');
    expect(UploadQuota.currentUploadsThisWeek(now: next), 1);
    await UploadQuota.clearOperationsForUser('owner');
    expect(getIt<SettingsLocalDataSource>().get<Object?>('uploadQuotaOperations/owner'), isNull);
  });

  test('concurrent successful replays share one local charge', () async {
    await Future.wait([_submit(_Repository()), _submit(_Repository())]);
    expect(UploadQuota.currentUploadsThisWeek(), 2);
  });
  test('account change while local quota persists cannot update the new account', () async {
    store.afterWrite = (key) {
      if (!key.contains('uploadQuotaOperations/')) return;
      store.afterWrite = null;
      app_state.prismUser = constants.createGuestPrismUser()
        ..id = 'other'
        ..loggedIn = true
        ..uploadsThisWeek = 77;
    };
    await _submit(_Repository());
    expect(app_state.prismUser.id, 'other');
    expect(app_state.prismUser.uploadsThisWeek, 77);
  });
}
