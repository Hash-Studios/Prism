import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const NotificationRouteMapper mapper = NotificationRouteMapper();
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<String> toastMessages = <String>[];
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    toastMessages.clear();
  });

  tearDown(() {
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
    expect(route, isA<StreakTabRoute>());
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

  test('returns null for non-whitelisted route', () async {
    final route = await mapper.fromRoute(route: 'totally_unknown', sourceTag: 'test');
    expect(route, isNull);
  });
}
