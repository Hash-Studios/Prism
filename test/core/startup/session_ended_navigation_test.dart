import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/startup/session_ended_navigation.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SessionRouter extends AppRouter {
  @override
  List<AutoRoute> get routes => AppRouter().routes
      .map(
        (route) => route is RedirectRoute
            ? route
            : AutoRoute(
                path: route.path,
                page: PageInfo(route.page.name, builder: (_) => Text(route.page.name)),
                guards: route.guards,
              ),
      )
      .toList();
}

void main() {
  tearDown(() => app_state.prismUser = createGuestPrismUser());

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('session loss on $platform applies the guest policy to the mounted stack', (tester) async {
      app_state.prismUser = createGuestPrismUser()..loggedIn = true;
      final router = _SessionRouter();
      final continuation = AuthNavigationContinuation.of(router);
      addTearDown(continuation.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
      await tester.pumpAndSettle();
      unawaited(router.replaceAll([const DashboardRoute()]));
      await tester.pumpAndSettle();
      unawaited(router.pushPath('/wallpaper-detail'));
      await tester.pumpAndSettle();
      expect(router.stackData.map((route) => route.name), [DashboardRoute.name, WallpaperDetailRoute.name]);

      var prompts = 0;
      final handled = handleSessionEndedNavigation(
        router: router,
        signOut: () async {
          app_state.prismUser = createGuestPrismUser();
          return true;
        },
        isMounted: () => true,
        // Returning without signing in models Not now, barrier dismissal, or back.
        showGuestPrompt: () async => prompts++,
      );
      await tester.pumpAndSettle();
      await handled;

      if (platform == TargetPlatform.android) {
        expect(router.stackData.map((route) => route.name), [OnboardingV2ShellRoute.name]);
        expect(prompts, 0);
        expect(await router.maybePop(), isFalse);
        await tester.pumpAndSettle();
        expect(find.text(DashboardRoute.name), findsNothing);
        expect(find.text(WallpaperDetailRoute.name), findsNothing);
        expect(router.current.name, OnboardingV2ShellRoute.name);
      } else {
        expect(prompts, 1);
        expect(router.current.name, WallpaperDetailRoute.name);
        expect(await router.maybePop(), isTrue);
        await tester.pumpAndSettle();
        expect(router.current.name, DashboardRoute.name);
      }
    }, variant: TargetPlatformVariant.only(platform));
  }

  for (final signedInAfterCleanup in [false, true]) {
    testWidgets('false sign-out result uses current session ownership: signed in $signedInAfterCleanup', (
      tester,
    ) async {
      app_state.prismUser = createGuestPrismUser()..loggedIn = true;
      final router = _SessionRouter();
      final continuation = AuthNavigationContinuation.of(router);
      addTearDown(continuation.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
      await tester.pumpAndSettle();
      unawaited(router.replaceAll([const DashboardRoute()]));
      await tester.pumpAndSettle();
      final signOut = Completer<bool>();
      var prompts = 0;
      final handled = handleSessionEndedNavigation(
        router: router,
        signOut: () => signOut.future,
        isMounted: () => true,
        showGuestPrompt: () async => prompts++,
      );
      app_state.prismUser = createGuestPrismUser()..loggedIn = signedInAfterCleanup;
      signOut.complete(false);
      await tester.pumpAndSettle();
      await handled;

      final expectedRoute = signedInAfterCleanup ? DashboardRoute.name : OnboardingV2ShellRoute.name;
      expect(router.stackData.map((route) => route.name), [expectedRoute]);
      expect(prompts, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('session loss cancels a destination deferred by the previous session', (tester) async {
    app_state.prismUser = createGuestPrismUser();
    final router = _SessionRouter();
    final continuation = AuthNavigationContinuation.of(router);
    addTearDown(continuation.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();
    unawaited(router.push(const CoinHistoryRoute()));
    await tester.pumpAndSettle();
    final pending = continuation.pendingNavigation!;

    final handled = handleSessionEndedNavigation(
      router: router,
      signOut: () async => true,
      isMounted: () => true,
      showGuestPrompt: () async {},
    );
    await tester.pumpAndSettle();
    await handled;

    expect(await pending, isFalse);
    expect(continuation.pendingNavigation, isNull);
    expect(router.stackData.map((route) => route.name), [OnboardingV2ShellRoute.name]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
