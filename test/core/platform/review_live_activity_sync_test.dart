import 'dart:async';

import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:Prism/core/platform/review_live_activity_sync.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter_test/flutter_test.dart';

class _FakeHostApi extends PrismLiveActivityHostApi {
  int reviewStarts = 0;
  void Function()? onStart;

  @override
  Future<void> startReviewTokenUpdates() async {
    reviewStarts++;
    onStart?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final PrismLiveActivityHostApi defaultApi = LiveActivityChannel.api;
  final bool Function() defaultSupported = LiveActivityChannel.isSupportedPlatform;
  final Future<void> Function(Map<String, Object?> data) defaultRegister = ReviewLiveActivitySync.register;
  final bool Function() defaultIsAdmin = ReviewLiveActivitySync.isAdmin;
  final String? Function() defaultCurrentUserId = ReviewLiveActivitySync.currentUserId;
  final Duration defaultRetryDelay = ReviewLiveActivitySync.retryDelay;
  final ReviewLiveActivitySync sync = ReviewLiveActivitySync.instance;
  final String defaultUserId = app_state.prismUser.id;

  late List<Map<String, Object?>> recorded;
  late bool admin;
  late bool failNext;
  late _FakeHostApi host;
  late String authUid;

  setUp(() {
    app_state.prismUser.id = 'admin-a';
    authUid = 'admin-a';
    recorded = <Map<String, Object?>>[];
    admin = true;
    failNext = false;
    host = _FakeHostApi();
    LiveActivityChannel.api = host;
    LiveActivityChannel.isSupportedPlatform = () => true;
    ReviewLiveActivitySync.isAdmin = () => admin;
    ReviewLiveActivitySync.currentUserId = () => authUid;
    ReviewLiveActivitySync.retryDelay = Duration.zero;
    ReviewLiveActivitySync.register = (Map<String, Object?> data) async {
      recorded.add(data);
      if (failNext) {
        failNext = false;
        throw StateError('register failed');
      }
    };
    ReviewLiveActivitySync.resetForTest();
  });

  tearDown(() {
    ReviewLiveActivitySync.resetForTest();
    LiveActivityChannel.api = defaultApi;
    LiveActivityChannel.isSupportedPlatform = defaultSupported;
    ReviewLiveActivitySync.register = defaultRegister;
    ReviewLiveActivitySync.isAdmin = defaultIsAdmin;
    ReviewLiveActivitySync.currentUserId = defaultCurrentUserId;
    ReviewLiveActivitySync.retryDelay = defaultRetryDelay;
    app_state.prismUser.id = defaultUserId;
  });

  Future<void> settle() => ReviewLiveActivitySync.settleForTest();

  test('admin sends the push-to-start token then the activity token', () async {
    sync.onReviewPushToStartToken('aa');
    sync.onReviewActivityToken('bb');
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'pushToStartToken': 'aa'},
      <String, Object?>{'activityToken': 'bb'},
    ]);
  });

  test('non-admin sends nothing', () async {
    admin = false;
    sync.onReviewPushToStartToken('aa');
    sync.onReviewActivityToken('bb');
    await settle();
    expect(recorded, isEmpty);
  });

  test('the same activity token twice is sent once', () async {
    sync.onReviewActivityToken('bb');
    await settle();
    sync.onReviewActivityToken('bb');
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'bb'},
    ]);
  });

  test('the same token is registered again after the admin account changes', () async {
    sync.onReviewActivityToken('bb');
    await settle();
    app_state.prismUser.id = 'admin-b';
    authUid = 'admin-b';
    sync.onReviewActivityToken('bb');
    await settle();
    app_state.prismUser.id = 'admin-a';
    authUid = 'admin-a';
    sync.onReviewActivityToken('bb');
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'bb'},
      <String, Object?>{'activityToken': 'bb'},
      <String, Object?>{'activityToken': 'bb'},
    ]);
  });

  test('activity token updates are serialized and duplicate in-flight values are deduplicated', () async {
    final Completer<void> firstSend = Completer<void>();
    ReviewLiveActivitySync.register = (Map<String, Object?> data) async {
      recorded.add(data);
      if (recorded.length == 1) await firstSend.future;
    };

    sync.onReviewActivityToken('old');
    sync.onReviewActivityToken('old');
    sync.onReviewActivityToken(null);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'old'},
    ]);

    firstSend.complete();
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'old'},
      <String, Object?>{'activityToken': null},
    ]);
  });

  test('queued token updates are discarded when Firebase Auth changes first', () async {
    final Completer<void> firstSend = Completer<void>();
    ReviewLiveActivitySync.register = (Map<String, Object?> data) async {
      recorded.add(data);
      if (recorded.length == 1) await firstSend.future;
    };

    sync.onReviewActivityToken('first');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    sync.onReviewActivityToken('queued');
    authUid = 'admin-b';
    firstSend.complete();
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'first'},
    ]);
  });

  test('a null activity token after a real one is sent', () async {
    sync.onReviewActivityToken('bb');
    await settle();
    sync.onReviewActivityToken(null);
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'bb'},
      <String, Object?>{'activityToken': null},
    ]);
  });

  test('a failed send is retried and nothing throws out', () async {
    failNext = true;
    sync.onReviewActivityToken('bb');
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'bb'},
      <String, Object?>{'activityToken': 'bb'},
    ]);
  });

  test('a retry stops when Firebase Auth changes before the retry runs', () async {
    failNext = true;
    ReviewLiveActivitySync.retryDelay = const Duration(milliseconds: 50);
    sync.onReviewActivityToken('bb');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    authUid = 'admin-b';
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'bb'},
    ]);
  });

  test('start does nothing on unsupported platforms', () async {
    LiveActivityChannel.isSupportedPlatform = () => false;
    await ReviewLiveActivitySync.start();
    expect(host.reviewStarts, 0);
  });

  test('start does nothing after Firebase sign-out', () async {
    authUid = '';
    await ReviewLiveActivitySync.start();
    expect(host.reviewStarts, 0);
  });

  test('start replays the same token for the same admin account', () async {
    host.onStart = () => sync.onReviewActivityToken('bb');
    await ReviewLiveActivitySync.start();
    await settle();
    await ReviewLiveActivitySync.start();
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'bb'},
      <String, Object?>{'activityToken': 'bb'},
    ]);
  });

  test('an old in-flight send cannot dedupe a token replayed after start', () async {
    final Completer<void> firstSend = Completer<void>();
    ReviewLiveActivitySync.register = (Map<String, Object?> data) async {
      recorded.add(data);
      if (recorded.length == 1) await firstSend.future;
    };
    sync.onReviewActivityToken('bb');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    host.onStart = () => sync.onReviewActivityToken('bb');
    await ReviewLiveActivitySync.start();
    firstSend.complete();
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'bb'},
      <String, Object?>{'activityToken': 'bb'},
    ]);
  });
}
