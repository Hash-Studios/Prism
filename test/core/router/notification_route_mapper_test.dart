import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const NotificationRouteMapper mapper = NotificationRouteMapper();

  test('maps wall_of_the_day to home tab route', () async {
    final route = await mapper.fromRoute(route: 'wall_of_the_day', sourceTag: 'test');
    expect(route, isA<HomeTabRoute>());
  });

  test('maps streak_reminder to profile tab route', () async {
    final route = await mapper.fromRoute(route: 'streak_reminder', sourceTag: 'test');
    expect(route, isA<ProfileTabRoute>());
  });

  test('maps follower to notification route', () async {
    final route = await mapper.fromRoute(route: 'follower', sourceTag: 'test');
    expect(route, isA<NotificationRoute>());
  });

  test('returns null for non-whitelisted route', () async {
    final route = await mapper.fromRoute(route: 'totally_unknown', sourceTag: 'test');
    expect(route, isNull);
  });
}
