import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _FailingLocalStore extends InMemoryLocalStore {
  bool failWrites = false;

  @override
  Future<void> set(String key, Object? value) async {
    final shouldFail = failWrites;
    await super.set(key, value);
    if (shouldFail) throw StateError('disk unavailable');
  }
}

class _FakeFirestoreClient extends Fake implements FirestoreClient {
  int wallWrites = 0;
  Object? saveError;
  Object? syncError;
  Completer<void>? saveGate;

  @override
  Future<String> addDoc(String collection, Map<String, dynamic> data, {required String sourceTag}) async {
    wallWrites++;
    if (saveGate != null) await saveGate!.future;
    if (saveError != null) throw saveError!;
    return 'saved-wall';
  }

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) async {
    if (syncError != null) throw syncError!;
  }
}

Future<wall_store.WallSubmissionResult> _submit() =>
    wall_store.createRecord('wall', 'Prism', 'thumb', 'image', '100x100', '1MB', null, 'General', 'Community', false);

const wall_store.WallSubmissionResult _submitted = wall_store.WallSubmissionResult.submitted;
const wall_store.WallSubmissionResult _quotaExceeded = wall_store.WallSubmissionResult.quotaExceeded;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeFirestoreClient firestore;
  late List<String> toasts;
  late _FailingLocalStore local;

  setUp(() {
    firestore = _FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    local = _FailingLocalStore();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(local));
    app_state.prismUser = app_constants.createGuestPrismUser();
    toasts = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async {
        toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
        return true;
      },
    );
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
  });

  test('failed wall save does not consume quota or announce success', () async {
    firestore.saveError = StateError('offline');
    await expectLater(_submit(), throwsStateError);
    expect(UploadQuota.currentUploadsThisWeek(), 0);
    expect(toasts, isEmpty);
  });

  test('pending wall save does not consume quota', () async {
    firestore.saveGate = Completer<void>();
    final submission = _submit();
    final countWhilePending = UploadQuota.currentUploadsThisWeek();
    firestore.saveGate!.complete();
    expect(await submission, _submitted);
    expect(countWhilePending, 0);
    expect(UploadQuota.currentUploadsThisWeek(), 1);
  });

  test('quota rejection writes no wall and reports quotaExceeded', () async {
    for (var i = 0; i < UploadQuota.freeUploadsPerWeek; i++) {
      await UploadQuota.incrementWeeklyUploads();
    }
    expect(await _submit(), _quotaExceeded);
    expect(firestore.wallWrites, 0);
    expect(UploadQuota.currentUploadsThisWeek(), 3);
    expect(toasts, ['Free users can upload 3 wallpapers per week.']);
  });

  test('saved wall consumes one upload and reports success', () async {
    expect(await _submit(), _submitted);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(), 1);
    expect(app_state.prismUser.uploadsThisWeek, 1);
    expect(toasts, ['Your wall is submitted and is under review.']);
  });

  test('premium upload bypasses an exhausted free quota without incrementing it', () async {
    for (var i = 0; i < UploadQuota.freeUploadsPerWeek; i++) {
      await UploadQuota.incrementWeeklyUploads();
    }
    app_state.prismUser.premium = true;
    expect(await _submit(), _submitted);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(), 3);
    expect(toasts, ['Your wall is submitted and is under review.']);
  });

  test('profile sync failure does not reject an already saved wall', () async {
    app_state.prismUser.id = 'user';
    firestore.syncError = StateError('profile offline');
    expect(await _submit(), _submitted);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(), 1);
    expect(toasts, ['Your wall is submitted and is under review.']);
  });

  test('quota persistence failure does not reject an already saved wall', () async {
    UploadQuota.currentUploadsThisWeek();
    local.failWrites = true;
    expect(await _submit(), _submitted);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(), 1);
    expect(toasts, ['Your wall is submitted and is under review.']);
  });

  test('reward failure does not reject an already saved wall', () async {
    // No Firebase app is initialized, so the reward callable fails.
    app_state.prismUser.id = 'user';
    app_state.prismUser.loggedIn = true;
    expect(await _submit(), _submitted);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(), 1);
    expect(toasts, ['Your wall is submitted and is under review.']);
  });

  test('overlapping submissions cannot both use the last free upload', () async {
    await UploadQuota.incrementWeeklyUploads();
    await UploadQuota.incrementWeeklyUploads();
    firestore.saveGate = Completer<void>();
    final first = _submit();
    final second = _submit();
    firestore.saveGate!.complete();
    expect(await first, _submitted);
    expect(await second, _quotaExceeded);
    expect(await _submit(), _quotaExceeded);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(), 3);
  });

  test('failed save releases the guard so a retry can succeed', () async {
    firestore.saveError = StateError('offline');
    await expectLater(_submit(), throwsStateError);
    firestore.saveError = null;
    expect(await _submit(), _submitted);
    expect(UploadQuota.currentUploadsThisWeek(), 1);
    expect(firestore.wallWrites, 2);
  });

  test('previous week uploads reset without blocking this week', () async {
    final lastWeek = DateTime.now().subtract(const Duration(days: 7));
    for (var i = 0; i < UploadQuota.freeUploadsPerWeek; i++) {
      await UploadQuota.incrementWeeklyUploads(now: lastWeek);
    }
    expect(await _submit(), _submitted);
    expect(UploadQuota.currentUploadsThisWeek(), 1);
  });
}
