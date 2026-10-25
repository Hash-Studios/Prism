import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a /theme notification route maps to the theme page', () async {
    final action = await const NotificationRouteMapper().actionFromRoute(
      route: '/theme',
      sourceTag: 't',
      fallbackToInbox: false,
    );

    expect(action, isA<PageLinkIntent>());
    expect((action! as PageLinkIntent).path, '/theme');
  });
}
