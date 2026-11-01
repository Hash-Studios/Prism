import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/creator_stats/views/widgets/stats_entry_button.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

class _StatsRouter extends RootStackRouter {
  _StatsRouter({required this.nested});
  final bool nested;
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo('Host', builder: (_) => nested ? const AutoRouter() : _entry()),
      children: nested
          ? [
              AutoRoute(
                path: '',
                page: PageInfo('ProfileTab', builder: (_) => _entry()),
              ),
            ]
          : [],
    ),
    for (final route in AppRouter().routes.where(
      (route) => ['/creator-stats', '/onboarding/v2', '/dashboard'].contains(route.path),
    ))
      AutoRoute(
        path: route.path,
        page: PageInfo(
          route.page.name,
          builder: (data) => Scaffold(
            body: Text(
              '${route.page.name}:${route.page.name == CreatorStatsRoute.name ? data.argsAs<CreatorStatsRouteArgs>().source : ''}',
            ),
          ),
        ),
        guards: route.guards,
      ),
  ];
  static Widget _entry() => const Scaffold(body: StatsEntryButton(source: 'profile'));
}

void main() {
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = createGuestPrismUser();
  });
  for (final nested in [false, true]) {
    testWidgets('Stats tap opens the root dashboard from ${nested ? 'nested profile' : 'root'}', (tester) async {
      app_state.prismUser = profileUser();
      final router = _StatsRouter(nested: nested);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(router.current.name, CreatorStatsRoute.name);
      expect(find.text('CreatorStatsRoute:profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
  }
  testWidgets('the production Stats guard defers guest navigation to sign-in', (tester) async {
    app_state.prismUser = createGuestPrismUser();
    final router = _StatsRouter(nested: true);
    final continuation = AuthNavigationContinuation.of(router);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push(CreatorStatsRoute()));
    await tester.pumpAndSettle();
    expect(router.current.name, OnboardingV2ShellRoute.name);
    expect(find.text('CreatorStatsRoute:link'), findsNothing);
    expect(continuation.pendingNavigation, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    continuation.dispose();
    router.dispose();
  });
}
