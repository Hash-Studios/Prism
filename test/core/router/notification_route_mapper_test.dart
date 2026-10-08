import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

void main() {
  const NotificationRouteMapper mapper = NotificationRouteMapper();
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<String> toastMessages = <String>[];
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  late FakeFirestoreClient firestore;

  setUp(() async {
    await getIt.reset();
    firestore = FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    app_state.prismUser.email = 'user@example.com';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    toastMessages.clear();
  });

  tearDown(() async {
    app_state.prismUser.email = '';
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  test('maps legacy setup notification routes to home and shows a toast', () async {
    final route = await mapper.fromRoute(route: '/setup/legacy-id', sourceTag: 'test');
    expect(route, isA<HomeTabRoute>());
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
    expect(toastMessages, isEmpty);
  });

  test('an unapproved wall falls back to the inbox with a toast', () async {
    firestore.docs[FirebaseCollections.walls] = <String, Map<String, dynamic>>{'w1': wall(review: false)};

    final route = await mapper.fromRoute(route: 'wall', wallId: 'w1', sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
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
    expect(toastMessages, <String>[unavailable]);
  });

  test('a wall route without a wall id falls back to the inbox', () async {
    final route = await mapper.fromRoute(route: 'wall', sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
    expect(toastMessages, <String>[unavailable]);
  });

  test('a lookup error falls back to the inbox instead of throwing', () async {
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(_ThrowingFirestoreClient());

    final route = await mapper.fromRoute(route: 'wall', wallId: 'w1', sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
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
    expect(toastMessages, <String>[unavailable]);
  });

  test('an unknown route falls back to the inbox with a toast', () async {
    final route = await mapper.fromRoute(route: 'totally_unknown', sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
    expect(toastMessages, <String>[unavailable]);
  });

  test('an empty route opens the inbox without a toast', () async {
    final route = await mapper.fromPayload(const <String, dynamic>{}, sourceTag: 'test');

    expect(route, isA<NotificationRoute>());
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
    expect(toastMessages, isEmpty);
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
