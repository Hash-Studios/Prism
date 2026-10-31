import 'package:Prism/core/constants/app_constants.dart' as constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/navigation/views/pages/dashboard_page.dart';
import 'package:Prism/features/navigation/views/pages/home_tab_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _Notifications extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

class _Categories extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _Badges extends Mock implements BadgeRepository {}

class _Router extends AppRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo(DashboardRoute.name, builder: (_) => const DashboardPage()),
      children: <AutoRoute>[
        for (final route in <String>[
          HomeTabRoute.name,
          SearchTabRoute.name,
          RewardsTabRoute.name,
          CollectionTabRoute.name,
        ])
          AutoRoute(
            path: route,
            initial: route == HomeTabRoute.name,
            page: PageInfo(
              route,
              builder: (_) => route == HomeTabRoute.name
                  ? HomeTabTickerMode(child: Scaffold(body: Text('Page $route')))
                  : Scaffold(body: Text('Page $route')),
            ),
          ),
      ],
    ),
  ];
}

void main() {
  testWidgets('dashboard starts its feeds once and back returns a secondary tab to home', (tester) async {
    final notifications = _Notifications();
    final categories = _Categories();
    final badges = _Badges();
    final unseen = ValueNotifier<List<EarnedBadge>>(<EarnedBadge>[]);
    when(() => notifications.state).thenReturn(InAppNotificationsState.initial());
    when(() => categories.state).thenReturn(CategoryFeedState.initial());
    when(() => badges.unseen).thenReturn(unseen);
    getIt.registerSingleton<InAppNotificationsBloc>(notifications);
    getIt.registerSingleton<BadgeRepository>(badges);
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    app_state.prismUser = constants.createGuestPrismUser()
      ..id = 'test-user'
      ..loggedIn = true;
    final router = _Router();
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      unseen.dispose();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await getIt.reset();
      app_state.prismUser = constants.createGuestPrismUser();
    });

    await tester.pumpWidget(
      BlocProvider<CategoryFeedBloc>.value(
        value: categories,
        child: MaterialApp.router(
          routerConfig: router.config(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page HomeTabRoute'), findsOneWidget);
    verify(() => notifications.add(const InAppNotificationsEvent.started())).called(1);
    verify(() => categories.add(const CategoryFeedEvent.started())).called(1);

    final tabs = AutoTabsRouter.of(tester.element(find.text('Page HomeTabRoute')));
    expect(TickerMode.valuesOf(tester.element(find.text('Page HomeTabRoute'))).enabled, isTrue);
    tabs.setActiveIndex(1);
    await tester.pumpAndSettle();
    expect(find.text('Page SearchTabRoute'), findsOneWidget);
    final homeFinder = find.text('Page HomeTabRoute', skipOffstage: false);
    expect(TickerMode.valuesOf(tester.element(homeFinder)).enabled, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tabs.activeIndex, 0);
    expect(find.text('Page HomeTabRoute'), findsOneWidget);
    expect(TickerMode.valuesOf(tester.element(find.text('Page HomeTabRoute'))).enabled, isTrue);
    verifyNever(() => categories.add(const CategoryFeedEvent.started()));
    verifyNever(() => notifications.add(const InAppNotificationsEvent.started()));
  });
}
