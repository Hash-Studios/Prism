import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_catalog_resolver.dart';
import 'package:Prism/core/router/deep_link_route_catalog.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/in_memory_local_store.dart';

void main() {
  const NotificationRouteMapper mapper = NotificationRouteMapper();

  group('notification payload', () {
    test('a feed field opens Home on that tab', () async {
      final action = await mapper.actionFromPayload({
        'route': 'home',
        'feed': 'latest',
        'push_kind': 'win_back',
        'step': '7',
      }, sourceTag: 't');

      expect(action, isA<PageLinkIntent>().having((intent) => intent.path, 'path', '/dashboard/home?feed=latest'));
    });

    test('home without a valid feed keeps the plain Home path', () async {
      for (final Map<String, dynamic> payload in <Map<String, dynamic>>[
        {'route': 'home'},
        {'route': 'home', 'feed': 'bogus'},
      ]) {
        final action = await mapper.actionFromPayload(payload, sourceTag: 't');

        expect(action, isA<PageLinkIntent>().having((intent) => intent.path, 'path', '/dashboard/home'));
      }
    });
  });

  group('deep link catalog', () {
    test('home accepts a feed chip and rejects an unknown one', () {
      expect(DeepLinkRouteCatalog.match(Uri.parse('/dashboard/home?feed=latest'))?.target, DeepLinkPageTarget.home);
      expect(DeepLinkRouteCatalog.match(Uri.parse('/dashboard/home?feed=bogus')), isNull);
    });

    test('a hidden tab still resolves by its deep link', () {
      expect(DeepLinkRouteCatalog.match(Uri.parse('/dashboard/collection'))?.target, DeepLinkPageTarget.collectionTab);
    });
  });

  group('routeForPageLink', () {
    late FakeFirestoreClient firestore;
    late LayoutPrefsStore store;

    setUp(() async {
      await getIt.reset();
      firestore = FakeFirestoreClient();
      getIt.registerSingleton<FirestoreClient>(firestore);
      store = LayoutPrefsStore(SettingsLocalDataSource(InMemoryLocalStore()), firestore);
      getIt.registerSingleton<LayoutPrefsStore>(store);
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('a feed query opens Home and sets the remembered feed tab', () async {
      final route = await routeForPageLink(
        const PageLinkIntent(path: '/dashboard/home?feed=latest', rawUri: '/dashboard/home?feed=latest'),
      );

      expect(route, isA<DashboardRoute>());
      expect(store.value.feedTab, HomeFeedChip.latest);
    });

    test('a link without a feed query leaves the feed tab unchanged', () async {
      await store.setFeedTab(HomeFeedChip.popular);

      final route = await routeForPageLink(const PageLinkIntent(path: '/dashboard/home', rawUri: '/dashboard/home'));

      expect(route, isA<DashboardRoute>());
      expect(store.value.feedTab, HomeFeedChip.popular);
    });
  });
}
