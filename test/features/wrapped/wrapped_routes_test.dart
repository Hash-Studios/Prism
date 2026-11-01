import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/features/wrapped/views/pages/wrapped_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the intent source to the analytics source', () {
    expect(wrappedSourceFrom('push'), WrappedSourceValue.push);
    expect(wrappedSourceFrom('inbox'), WrappedSourceValue.inbox);
    expect(wrappedSourceFrom('home'), WrappedSourceValue.home);
    expect(wrappedSourceFrom('link'), WrappedSourceValue.deepLink);
  });

  test('a wrapped push route opens /wrapped with the push source', () async {
    final DeepLinkActionEntity? action = await const NotificationRouteMapper().actionFromRoute(
      route: 'wrapped',
      sourceTag: 'push.route_mapper',
    );

    expect(
      action,
      isA<PageLinkIntent>()
          .having((PageLinkIntent a) => a.path, 'path', '/wrapped')
          .having((PageLinkIntent a) => a.source, 'source', 'push'),
    );
  });

  test('a wrapped inbox route opens /wrapped with the inbox source', () async {
    final DeepLinkActionEntity? action = await const NotificationRouteMapper().actionFromRoute(
      route: 'wrapped',
      sourceTag: 'notification.route_mapper',
    );

    expect(
      action,
      isA<PageLinkIntent>()
          .having((PageLinkIntent a) => a.path, 'path', '/wrapped')
          .having((PageLinkIntent a) => a.source, 'source', 'inbox'),
    );
  });
}
