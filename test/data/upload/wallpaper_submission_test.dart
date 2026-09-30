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
  Completer<void>? quotaWriteGate;
  Completer<void>? quotaWriteStarted;

  @override
  Future<void> set(String key, Object? value) async {
    final shouldFail = failWrites;
    await super.set(key, value);
    final Completer<void>? gate = quotaWriteGate;
    if (key == 'settings.uploadsThisWeek' && value is int && value > 0 && gate != null) {
      if (quotaWriteStarted case final started? when !started.isCompleted) started.complete();
      await gate.future;
    }
    if (shouldFail) throw StateError('disk unavailable');
  }
}

class _FakeFirestoreClient extends Fake implements FirestoreClient {
  int wallWrites = 0;
  Object? saveError;
  Object? syncError;
  Completer<void>? saveGate;
  Completer<void>? saveStarted;
  Map<String, dynamic>? userUpdate;

  @override
  Future<String> addDoc(String collection, Map<String, dynamic> data, {required String sourceTag}) async {
    wallWrites++;
    saveStarted?.complete();
    if (saveGate != null) await saveGate!.future;
    if (saveError != null) throw saveError!;
    return 'saved-wall';
  }

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) async {
    userUpdate = Map<String, dynamic>.of(data);
    if (syncError != null) throw syncError!;
  }
}

Future<wall_store.WallSubmissionResult> _submit({DateTime Function()? now}) => wall_store.createRecord(
  'wall',
  'Prism',
  'thumb',
  'image',
  '100x100',
  '1MB',
  null,
  'General',
  'Community',
  false,
  now: now,
);

const wall_store.WallSubmissionResult _submitted = wall_store.WallSubmissionResult.submitted;
const wall_store.WallSubmissionResult _quotaExceeded = wall_store.WallSubmissionResult.quotaExceeded;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeFirestoreClient firestore;
  late List<String> toasts;
  late _FailingLocalStore local;
  late DateTime testNow;

  setUp(() {
    testNow = DateTime(2026, 9, 30, 12);
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
    if (firestore.saveGate case final gate? when !gate.isCompleted) gate.complete();
    if (local.quotaWriteGate case final gate? when !gate.isCompleted) gate.complete();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
  });

  test('failed wall save does not consume quota or announce success', () async {
    firestore.saveError = StateError('offline');
    await expectLater(_submit(now: () => testNow), throwsStateError);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 0);
    expect(toasts, isEmpty);
  });

  test('pending wall save does not consume quota', () async {
    firestore.saveGate = Completer<void>();
    firestore.saveStarted = Completer<void>();
    final submission = _submit(now: () => testNow);
    await firestore.saveStarted!.future;
    final countWhilePending = UploadQuota.currentUploadsThisWeek(now: testNow);
    firestore.saveGate!.complete();
    expect(await submission, _submitted);
    expect(countWhilePending, 0);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 1);
  });

  test('submission waits for the quota write after the wall is saved', () async {
    UploadQuota.currentUploadsThisWeek(now: testNow);
    firestore.saveGate = Completer<void>();
    firestore.saveStarted = Completer<void>();
    local.quotaWriteGate = Completer<void>();
    local.quotaWriteStarted = Completer<void>();
    var submissionCompleted = false;
    final submission = _submit(now: () => testNow)..then((_) => submissionCompleted = true);

    wall_store.WallSubmissionResult? result;
    try {
      await firestore.saveStarted!.future;
      firestore.saveGate!.complete();
      await local.quotaWriteStarted!.future;
      await Future<void>.delayed(Duration.zero);

      expect(submissionCompleted, isFalse);
      expect(toasts, isEmpty);
      local.quotaWriteGate!.complete();
      result = await submission;
    } finally {
      if (firestore.saveGate case final gate? when !gate.isCompleted) gate.complete();
      if (local.quotaWriteGate case final gate? when !gate.isCompleted) gate.complete();
      await submission.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    }

    expect(result, _submitted);
    expect(submissionCompleted, isTrue);
  });

  test('quota rejection writes no wall and reports quotaExceeded', () async {
    for (var i = 0; i < UploadQuota.freeUploadsPerWeek; i++) {
      await UploadQuota.incrementWeeklyUploads(now: testNow);
    }
    expect(await _submit(now: () => testNow), _quotaExceeded);
    expect(firestore.wallWrites, 0);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 3);
    expect(toasts, ['Free users can upload 3 wallpapers per week.']);
  });

  test('saved wall consumes one upload and reports success', () async {
    expect(await _submit(now: () => testNow), _submitted);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 1);
    expect(app_state.prismUser.uploadsThisWeek, 1);
    expect(toasts, ['Your wall is submitted and is under review.']);
  });

  test('premium upload bypasses an exhausted free quota without incrementing it', () async {
    for (var i = 0; i < UploadQuota.freeUploadsPerWeek; i++) {
      await UploadQuota.incrementWeeklyUploads(now: testNow);
    }
    app_state.prismUser.premium = true;
    expect(await _submit(now: () => testNow), _submitted);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 3);
    expect(toasts, ['Your wall is submitted and is under review.']);
  });

  test('profile sync failure does not reject an already saved wall', () async {
    app_state.prismUser.id = 'user';
    firestore.syncError = StateError('profile offline');
    expect(await _submit(now: () => testNow), _submitted);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 1);
    expect(toasts, ['Your wall is submitted and is under review.']);
  });

  test('quota persistence failure still updates the profile after a saved wall', () async {
    UploadQuota.currentUploadsThisWeek(now: testNow);
    app_state.prismUser.id = 'user';
    local.failWrites = true;
    expect(await _submit(now: () => testNow), _submitted);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 1);
    expect(app_state.prismUser.uploadsWeekStart, '2026-09-28T00:00:00.000');
    expect(app_state.prismUser.uploadsThisWeek, 1);
    expect(firestore.userUpdate, {'uploadsWeekStart': '2026-09-28T00:00:00.000', 'uploadsThisWeek': 1});
    expect(toasts, ['Your wall is submitted and is under review.']);
  });

  test('increment reports a current-week persistence failure', () async {
    UploadQuota.currentUploadsThisWeek(now: testNow);
    local.failWrites = true;

    await expectLater(UploadQuota.incrementWeeklyUploads(now: testNow), throwsStateError);
  });

  test('cold-start reset write failures do not leave unhandled errors or skip profile sync', () async {
    app_state.prismUser.id = 'user';
    local.failWrites = true;

    expect(await _submit(now: () => testNow), _submitted);
    await Future<void>.delayed(Duration.zero);

    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 1);
    expect(app_state.prismUser.uploadsWeekStart, '2026-09-28T00:00:00.000');
    expect(app_state.prismUser.uploadsThisWeek, 1);
    expect(firestore.userUpdate, {'uploadsWeekStart': '2026-09-28T00:00:00.000', 'uploadsThisWeek': 1});
  });

  test('failed rollover writes from Sunday and Monday getters are contained', () async {
    local.data['settings.uploadsWeekStart'] = '2026-09-07T00:00:00.000';
    local.data['settings.uploadsThisWeek'] = 3;
    local.failWrites = true;
    final sunday = DateTime(2026, 9, 20, 23, 59, 59);
    final monday = DateTime(2026, 9, 21);

    expect(UploadQuota.currentUploadsThisWeek(now: sunday), 0);
    expect(UploadQuota.currentUploadsThisWeek(now: monday), 0);
    await Future<void>.delayed(Duration.zero);

    expect(UploadQuota.storedWeekStart, '2026-09-21T00:00:00.000');
    expect(UploadQuota.currentUploadsThisWeek(now: monday), 0);
  });

  test('submission crossing Sunday midnight snapshots the Monday quota week', () async {
    testNow = DateTime(2026, 9, 27, 23, 59, 59);
    await UploadQuota.incrementWeeklyUploads(now: testNow);
    local.quotaWriteGate = Completer<void>();
    local.quotaWriteStarted = Completer<void>();
    app_state.prismUser.id = 'user';
    final submission = _submit(now: () => testNow);

    await local.quotaWriteStarted!.future;
    testNow = DateTime(2026, 9, 28);
    local.quotaWriteGate!.complete();

    expect(await submission, _submitted);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 0);
    expect(app_state.prismUser.uploadsWeekStart, '2026-09-28T00:00:00.000');
    expect(app_state.prismUser.uploadsThisWeek, 0);
    expect(firestore.userUpdate, {'uploadsWeekStart': '2026-09-28T00:00:00.000', 'uploadsThisWeek': 0});
  });

  test('reward failure does not reject an already saved wall', () async {
    app_state.prismUser.id = 'user';
    app_state.prismUser.loggedIn = true;
    expect(await _submit(now: () => testNow), _submitted);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 1);
    expect(toasts, ['Your wall is submitted and is under review.']);
  });

  test('overlapping submissions cannot both use the last free upload', () async {
    await UploadQuota.incrementWeeklyUploads(now: testNow);
    await UploadQuota.incrementWeeklyUploads(now: testNow);
    firestore.saveGate = Completer<void>();
    firestore.saveStarted = Completer<void>();
    final first = _submit(now: () => testNow);
    final second = _submit(now: () => testNow);
    wall_store.WallSubmissionResult? firstResult;
    wall_store.WallSubmissionResult? secondResult;
    try {
      await firestore.saveStarted!.future;
      firestore.saveGate!.complete();
      firstResult = await first;
      secondResult = await second;
    } finally {
      if (firestore.saveGate case final gate? when !gate.isCompleted) gate.complete();
      await first.then<void>((_) {}, onError: (Object _, StackTrace __) {});
      await second.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    }

    expect(firstResult, _submitted);
    expect(secondResult, _quotaExceeded);
    expect(await _submit(now: () => testNow), _quotaExceeded);
    expect(firestore.wallWrites, 1);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 3);
  });

  test('failed save releases the guard so a retry can succeed', () async {
    firestore.saveError = StateError('offline');
    await expectLater(_submit(now: () => testNow), throwsStateError);
    firestore.saveError = null;
    expect(await _submit(now: () => testNow), _submitted);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 1);
    expect(firestore.wallWrites, 2);
  });

  test('previous week uploads reset without blocking this week', () async {
    final lastWeek = testNow.subtract(const Duration(days: 7));
    for (var i = 0; i < UploadQuota.freeUploadsPerWeek; i++) {
      await UploadQuota.incrementWeeklyUploads(now: lastWeek);
    }
    expect(await _submit(now: () => testNow), _submitted);
    expect(UploadQuota.currentUploadsThisWeek(now: testNow), 1);
  });
}
