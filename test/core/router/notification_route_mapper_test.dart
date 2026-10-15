import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_firestore_client.dart';

void main() {
  const NotificationRouteMapper mapper = NotificationRouteMapper();
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<String> toastMessages = <String>[];
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  late FakeFirestoreClient firestore;
  late FakeAppAnalytics analyticsSink;

  setUp(() async {
    analyticsSink = FakeAppAnalytics();
    AnalyticsRuntime.instance = analyticsSink;
    await getIt.reset();
    firestore = FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    app_state.prismUser.email = 'user@example.com';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    toastMessages.clear();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser.email = '';
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  test('maps legacy setup notification routes to home and shows a toast', () async {
    final route = await mapper.fromRoute(route: '/setup/legacy-id', sourceTag: 'test');
    expect(route, isA<HomeTabRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, <String>['Home screen setups are no longer available.']);
  });

  test('maps wall_of_the_day to home tab route', () async {
    final route = await mapper.fromRoute(route: 'wall_of_the_day', sourceTag: 'test');
    expect(route, isA<HomeTabRoute>());
  });

  test('maps streak_reminder to streak tab route', () async {
    final route = await mapper.fromRoute(route: 'streak_reminder', sourceTag: 'test');
    expect(route, isA<RewardsTabRoute>());
  });

  test('maps follower to profile route when identifier is present', () async {
    final route = await mapper.fromRoute(
      route: 'follower',
      profileIdentifier: 'creator@example.com',
      sourceTag: 'test',
    );
    expect(route, isA<ProfileRoute>());
  });

  test('maps follower to notification route when identifier is absent', () async {
    final route = await mapper.fromRoute(route: 'follower', sourceTag: 'test');
    expect(route, isA<NotificationRoute>());
  });

  test('maps follower payload to profile route using follower_email', () async {
    final route = await mapper.fromPayload(<String, dynamic>{
      'route': 'follower',
      'follower_email': 'user@example.com',
    }, sourceTag: 'test');
    expect(route, isA<ProfileRoute>());
  });

  const String unavailable = 'That item is no longer available';

  Map<String, dynamic> wall({required bool review}) => <String, dynamic>{
    'id': 'w1',
    'wallpaper_url': 'https://example.com/w1.jpg',
    'wallpaper_thumb': 'https://example.com/w1-thumb.jpg',
    'review': review,
  };

  test('maps an approved wall to the wallpaper detail route', () async {
    firestore.docs[FirebaseCollections.walls] = <String, Map<String, dynamic>>{'w1': wall(review: true)};

    final route = await mapper.fromRoute(route: 'wall', wallId: 'w1', sourceTag: 'test');

    expect(route, isA<WallpaperDetailRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, isEmpty);
  });

  test('an unapproved wall falls back to the inbox with a toast', () async {
    firestore.docs[FirebaseCollections.walls] = <String, Map<String, dynamic>>{'w1': wall(review: false)};

    final route = await mapper.fromRoute(route: 'wall', wallId: 'w1', sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, <String>[unavailable]);
  });

  test('an admin can still open an unapproved wall', () async {
    app_state.prismUser.email = adminEmails.first;
    firestore.docs[FirebaseCollections.walls] = <String, Map<String, dynamic>>{'w1': wall(review: false)};

    final route = await mapper.fromRoute(route: 'wall', wallId: 'w1', sourceTag: 'test');

    expect(route, isA<WallpaperDetailRoute>());
  });

  test('a missing or deleted wall falls back to the inbox with a toast', () async {
    final route = await mapper.fromPayload(<String, dynamic>{'route': 'wall', 'wall_id': 'gone'}, sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, <String>[unavailable]);
  });

  test('a wall route without a wall id falls back to the inbox', () async {
    final route = await mapper.fromRoute(route: 'wall', sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, <String>[unavailable]);
  });

  test('a lookup error falls back to the inbox instead of throwing', () async {
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(_ThrowingFirestoreClient());

    final route = await mapper.fromRoute(route: 'wall', wallId: 'w1', sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, <String>[unavailable]);
  });

  test('maps content_report to the admin review route for an admin', () async {
    app_state.prismUser.email = adminEmails.first;

    final route = await mapper.fromRoute(route: 'content_report', sourceTag: 'test');

    expect(route, isA<AdminReviewRoute>());
  });

  test('content_report falls back to the inbox for a non-admin', () async {
    final route = await mapper.fromRoute(route: 'content_report', sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, <String>[unavailable]);
  });

  test('an unknown route falls back to the inbox with a toast', () async {
    final route = await mapper.fromRoute(route: 'totally_unknown', sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, <String>[unavailable]);
  });

  test('an empty route opens the inbox without a toast', () async {
    final route = await mapper.fromPayload(const <String, dynamic>{}, sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, isEmpty);
  });

  test('fallbackToInbox false keeps returning null for callers that handle it', () async {
    final unknown = await mapper.fromRoute(route: 'totally_unknown', sourceTag: 'test', fallbackToInbox: false);
    final missingWall = await mapper.fromRoute(
      route: 'wall',
      wallId: 'gone',
      sourceTag: 'test',
      fallbackToInbox: false,
    );

    expect(unknown, isNull);
    expect(missingWall, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, isEmpty);
  });

  group('push tap analytics', () {
    List<PushKindValue?> openedKinds() => analyticsSink.events
        .whereType<PushOpenedEvent>()
        .map<PushKindValue?>((PushOpenedEvent event) => event.kind)
        .toList();

    test('names the kind of every push the server sends', () {
      expect(
        NotificationRouteMapper.pushKindFor(<String, dynamic>{'route': 'streak_reminder'}),
        PushKindValue.streakReminder,
      );
      expect(NotificationRouteMapper.pushKindFor(<String, dynamic>{'route': 'follower'}), PushKindValue.follower);
      expect(
        NotificationRouteMapper.pushKindFor(<String, dynamic>{'route': 'wall', 'wall_id': 'w1'}),
        PushKindValue.post,
      );
      expect(NotificationRouteMapper.pushKindFor(<String, dynamic>{'route': 'wall_of_the_day'}), PushKindValue.wotd);
      expect(
        NotificationRouteMapper.pushKindFor(<String, dynamic>{'route': 'content_report'}),
        PushKindValue.moderation,
      );
      expect(
        NotificationRouteMapper.pushKindFor(<String, dynamic>{'route': 'wall', 'report_id': 'r1'}),
        PushKindValue.moderation,
      );
      expect(NotificationRouteMapper.pushKindFor(<String, dynamic>{'route': 'announcement'}), isNull);
      expect(NotificationRouteMapper.pushKindFor(<String, dynamic>{}), isNull);
    });

    test('a push tap records push_opened once with its kind', () async {
      await mapper.fromPayload(<String, dynamic>{'route': 'streak_reminder'}, sourceTag: 'test');
      await mapper.fromPayload(<String, dynamic>{'route': 'follower', 'profile_identifier': 'ana'}, sourceTag: 'test');
      await mapper.fromPayload(<String, dynamic>{'route': 'wall_of_the_day'}, sourceTag: 'test');

      expect(openedKinds(), <PushKindValue?>[PushKindValue.streakReminder, PushKindValue.follower, PushKindValue.wotd]);
    });

    test('an inbox row does not count as a push tap', () async {
      await mapper.fromRoute(route: 'streak_reminder', sourceTag: 'test');

      expect(openedKinds(), isEmpty);
    });

    test('trackPushOpened records the tap for a push that opened as a deep link', () {
      mapper.trackPushOpened(<String, dynamic>{'route': 'follower', 'url': 'https://prismwalls.com/user/ana'});

      expect(openedKinds(), <PushKindValue?>[PushKindValue.follower]);
    });
  });
}

class _ThrowingFirestoreClient extends FakeFirestoreClient {
  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) {
    throw StateError('offline');
  }
}
