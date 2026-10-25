import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:Prism/core/platform/review_live_activity_sync.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHostApi extends PrismLiveActivityHostApi {
  int reviewStarts = 0;

  @override
  Future<void> startReviewTokenUpdates() async {
    reviewStarts++;
  }
}

void main() {
  final PrismLiveActivityHostApi defaultApi = LiveActivityChannel.api;
  final bool Function() defaultSupported = LiveActivityChannel.isSupportedPlatform;
  final Future<void> Function(Map<String, Object?> data) defaultRegister = ReviewLiveActivitySync.register;
  final bool Function() defaultIsAdmin = ReviewLiveActivitySync.isAdmin;
  final ReviewLiveActivitySync sync = ReviewLiveActivitySync.instance;

  late List<Map<String, Object?>> recorded;
  late bool admin;
  late bool failNext;
  late _FakeHostApi host;

  setUp(() {
    recorded = <Map<String, Object?>>[];
    admin = true;
    failNext = false;
    host = _FakeHostApi();
    LiveActivityChannel.api = host;
    LiveActivityChannel.isSupportedPlatform = () => true;
    ReviewLiveActivitySync.isAdmin = () => admin;
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
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

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
    sync.onReviewActivityToken('bb');
    await settle();
    expect(recorded, <Map<String, Object?>>[
      <String, Object?>{'activityToken': 'bb'},
      <String, Object?>{'activityToken': 'bb'},
    ]);
  });

  test('start does nothing on unsupported platforms', () async {
    LiveActivityChannel.isSupportedPlatform = () => false;
    await ReviewLiveActivitySync.start();
    expect(host.reviewStarts, 0);
  });
}
