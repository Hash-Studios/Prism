import 'dart:async';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_dispatcher.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/router/route_guards.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthTestRouter extends RootStackRouter {
  late final pausedGuard = _PausedGuard();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(path: '/', page: _page(SplashWidgetRoute.name)),
    AutoRoute(path: '/dashboard', page: _page(DashboardRoute.name)),
    AutoRoute(path: '/onboarding/v2', page: _page(OnboardingV2ShellRoute.name)),
    AutoRoute(path: '/guarded/:id', page: _page('GuardedRoute'), guards: const [SignedInGuard()]),
    AutoRoute(path: '/delayed', page: _page('DelayedRoute'), guards: [const SignedInGuard(), pausedGuard]),
    AutoRoute(path: '/second', page: _page('SecondRoute')),
    AutoRoute(
      path: '/parent/:group',
      page: PageInfo('ParentRoute', builder: (_) => const AutoRouter()),
      children: [
        AutoRoute(path: '', page: _page('ParentHomeRoute')),
        AutoRoute(path: 'child/:id', page: _page('ChildRoute'), guards: const [SignedInGuard()]),
        AutoRoute(path: 'delayed', page: _page('DelayedChildRoute'), guards: [const SignedInGuard(), pausedGuard]),
      ],
    ),
    AutoRoute(path: '/admin', page: _page('AdminRoute'), guards: const [AdminGuard()]),
    AutoRoute(path: '/not-found', page: _page(NotFoundRoute.name)),
  ];

  static PageInfo _page(String name) => PageInfo(name, builder: (_) => Text(name));
}

class _PausedGuard extends AutoRouteGuard {
  final release = Completer<void>();
  bool entered = false;

  @override
  Future<void> onNavigation(NavigationResolver resolver, StackRouter router) async {
    entered = true;
    await release.future;
    resolver.next();
  }
}

class _DestinationArgs {
  const _DestinationArgs(this.value);
  final Object value;
}

class _DestinationNavigation extends DeepLinkNavigation {
  const _DestinationNavigation(this.destination);

  final PageRouteInfo destination;

  @override
  Future<PageRouteInfo?> mapActionToRoute(DeepLinkActionEntity action) async => destination;
}

void main() {
  late _AuthTestRouter router;
  late AuthNavigationContinuation continuation;
  late _DestinationArgs args;
  late PageRouteInfo<_DestinationArgs> destination;

  Future<void> pumpRouter(WidgetTester tester, {bool bootstrapCompleted = true}) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();
    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();
    if (bootstrapCompleted) continuation.markBootstrapCompleted();
  }

  Future<void> requestDestination(WidgetTester tester) async {
    unawaited(router.push(destination));
    await tester.pumpAndSettle();
    expect(router.current.name, OnboardingV2ShellRoute.name);
    expect(router.stackData.where((route) => route.name == 'GuardedRoute'), isEmpty);
    expect(continuation.pendingNavigation, isNotNull);
  }

  Future<void> finishSignIn(WidgetTester tester) async {
    app_state.prismUser.loggedIn = true;
    unawaited(router.replaceAll([const SplashWidgetRoute()]));
    await tester.pumpAndSettle();
    expect(router.current.name, SplashWidgetRoute.name);
    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();
  }

  setUp(() {
    app_state.prismUser = createGuestPrismUser();
    router = _AuthTestRouter();
    continuation = AuthNavigationContinuation.of(router);
    args = const _DestinationArgs(Object());
    destination = PageRouteInfo<_DestinationArgs>(
      'GuardedRoute',
      args: args,
      rawPathParams: const {'id': 'wall-42'},
      rawQueryParams: const {'source': 'in-app'},
      fragment: 'details',
    );
  });

  tearDown(() {
    continuation.dispose();
    app_state.prismUser = createGuestPrismUser();
  });

  testWidgets('opening sign-in schedules a frame when the router is idle', (tester) async {
    await pumpRouter(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
    unawaited(router.push(destination));
    await tester.idle();

    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(router.current.name, DashboardRoute.name);
    await tester.pumpAndSettle();
    expect(router.current.name, OnboardingV2ShellRoute.name);
  });

  testWidgets('a guarded request from a post-frame callback opens sign-in without another event', (tester) async {
    await pumpRouter(tester);
    tester.binding.addPostFrameCallback((_) => unawaited(router.push(destination)));
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.idle();
    expect(continuation.pendingNavigation, isNotNull);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();

    expect(router.current.name, OnboardingV2ShellRoute.name);
  });

  for (final operation in ['cancel', 'dispose', 'logout']) {
    testWidgets('$operation before the sign-in frame does not open onboarding', (tester) async {
      await pumpRouter(tester);
      unawaited(router.push(destination));
      await tester.idle();
      final outcome = continuation.pendingNavigation!;
      expect(router.current.name, DashboardRoute.name);

      if (operation == 'dispose') {
        continuation.dispose();
      } else {
        continuation.cancel();
        if (operation == 'logout') app_state.prismUser = createGuestPrismUser();
      }
      await tester.pumpAndSettle();

      expect(await outcome, isFalse);
      expect(router.current.name, DashboardRoute.name);
      expect(continuation.pendingNavigation, isNull);
    });
  }

  testWidgets('a newer action before the sign-in frame opens only one onboarding', (tester) async {
    await pumpRouter(tester);
    unawaited(router.push(destination));
    await tester.idle();
    final previous = continuation.pendingNavigation!;
    const latestArgs = _DestinationArgs('latest-before-frame');
    unawaited(
      router.push(
        const PageRouteInfo<_DestinationArgs>('GuardedRoute', args: latestArgs, rawPathParams: {'id': 'latest-wall'}),
      ),
    );
    await tester.idle();
    final latest = continuation.pendingNavigation!;
    await tester.pumpAndSettle();

    expect(await previous, isFalse);
    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), hasLength(1));
    await finishSignIn(tester);
    expect(await latest, isTrue);
    expect(router.current.args, same(latestArgs));
  });

  for (final bootstrapCompleted in [true, false]) {
    testWidgets('sign-in before the opening frame respects bootstrap=$bootstrapCompleted', (tester) async {
      await pumpRouter(tester, bootstrapCompleted: bootstrapCompleted);
      unawaited(router.push(destination));
      await tester.idle();
      final outcome = continuation.pendingNavigation!;
      expect(router.current.name, DashboardRoute.name);

      app_state.prismUser.loggedIn = true;
      unawaited(router.replaceAll([const DashboardRoute()]));
      await tester.pumpAndSettle();

      if (!bootstrapCompleted) {
        expect(router.current.name, DashboardRoute.name);
        expect(continuation.pendingNavigation, isNotNull);
        continuation.markBootstrapCompleted();
        await tester.pumpAndSettle();
      }
      expect(router.current.name, 'GuardedRoute');
      expect(await outcome, isTrue);
      expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), isEmpty);
    });
  }

  testWidgets('an independently opened sign-in before the opening frame is not duplicated', (tester) async {
    await pumpRouter(tester);
    unawaited(router.push(destination));
    await tester.idle();
    unawaited(router.push(OnboardingV2ShellRoute()));
    await tester.idle();
    await tester.pumpAndSettle();

    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), hasLength(1));
    final outcome = continuation.pendingNavigation!;
    await finishSignIn(tester);
    expect(await outcome, isTrue);
  });

  testWidgets('a typed in-app route resumes once after sign-in and both stack replacements', (tester) async {
    await pumpRouter(tester);
    await requestDestination(tester);
    final outcome = continuation.pendingNavigation!;

    await finishSignIn(tester);

    expect(router.current.name, 'GuardedRoute');
    expect(router.current.args, same(args));
    expect(router.current.params.getString('id'), 'wall-42');
    expect(router.current.queryParams.getString('source'), 'in-app');
    expect(router.current.route.fragment, 'details');
    expect(await outcome, isTrue);
    expect(continuation.pendingNavigation, isNull);

    unawaited(router.push(const PageRouteInfo<void>('SecondRoute')));
    await tester.pumpAndSettle();
    expect(router.stackData.where((route) => route.name == 'GuardedRoute'), hasLength(1));
  });

  testWidgets('actual sign-in still waits for bootstrap completion', (tester) async {
    await pumpRouter(tester, bootstrapCompleted: false);
    await requestDestination(tester);
    final outcome = continuation.pendingNavigation!;
    await finishSignIn(tester);

    expect(router.current.name, DashboardRoute.name);
    continuation.markBootstrapCompleted();
    await tester.pumpAndSettle();

    expect(router.current.name, 'GuardedRoute');
    expect(await outcome, isTrue);
  });

  testWidgets('a cancelled provider leaves the guest on onboarding without resuming', (tester) async {
    await pumpRouter(tester);
    await requestDestination(tester);
    router.notifyAll();
    await tester.pumpAndSettle();

    expect(app_state.prismUser.loggedIn, isFalse);
    expect(router.current.name, OnboardingV2ShellRoute.name);
    expect(router.stackData.where((route) => route.name == 'GuardedRoute'), isEmpty);
  });

  testWidgets('choosing guest clears the action, including a later unrelated sign-in', (tester) async {
    await pumpRouter(tester);
    await requestDestination(tester);
    final outcome = continuation.pendingNavigation!;
    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();

    expect(await outcome, isFalse);
    expect(continuation.pendingNavigation, isNull);
    await finishSignIn(tester);
    expect(router.current.name, DashboardRoute.name);
  });

  testWidgets('a protected link replayed as the guest declines opens a fresh sign-in', (tester) async {
    await pumpRouter(tester);
    await requestDestination(tester);
    final Element firstSignIn = tester.element(find.text(OnboardingV2ShellRoute.name));
    final outcome = continuation.pendingNavigation!;

    // A link queued behind the sign-in replays as soon as the guest's replaceAll removes it, before the next frame.
    unawaited(router.replaceAll([const DashboardRoute()]).then((_) => router.push(destination)));
    await tester.pumpAndSettle();

    expect(await outcome, isFalse);
    expect(router.current.name, OnboardingV2ShellRoute.name);
    expect(firstSignIn.mounted, isFalse, reason: 'the finished sign-in page must not be reused');
    expect(continuation.pendingNavigation, isNotNull);
  });

  testWidgets('back from sign-in cancels the held action', (tester) async {
    await pumpRouter(tester);
    await requestDestination(tester);
    final outcome = continuation.pendingNavigation!;
    unawaited(router.maybePop());
    await tester.pumpAndSettle();

    expect(router.current.name, DashboardRoute.name);
    expect(await outcome, isFalse);
    expect(continuation.pendingNavigation, isNull);
  });

  testWidgets('logout clears the held action before an authenticated bootstrap can complete', (tester) async {
    await pumpRouter(tester, bootstrapCompleted: false);
    await requestDestination(tester);
    final outcome = continuation.pendingNavigation!;
    await finishSignIn(tester);
    continuation.cancel();
    app_state.prismUser = createGuestPrismUser();
    continuation.markBootstrapCompleted();
    await tester.pumpAndSettle();

    expect(await outcome, isFalse);
    expect(router.current.name, DashboardRoute.name);
    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), isEmpty);
  });

  testWidgets('guard denial after sign-in stays denied without another onboarding', (tester) async {
    await pumpRouter(tester);
    unawaited(router.push(const PageRouteInfo<void>('AdminRoute')));
    await tester.pumpAndSettle();
    final outcome = continuation.pendingNavigation!;
    await finishSignIn(tester);

    expect(await outcome, isFalse);
    expect(router.current.name, NotFoundRoute.name);
    expect(router.stackData.where((route) => route.name == 'AdminRoute'), isEmpty);
    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), isEmpty);
  });

  testWidgets('an admin route resumes after actual admin sign-in', (tester) async {
    await pumpRouter(tester);
    unawaited(router.push(const PageRouteInfo<void>('AdminRoute')));
    await tester.pumpAndSettle();
    expect(router.current.name, OnboardingV2ShellRoute.name);
    final outcome = continuation.pendingNavigation!;
    app_state.prismUser.email = adminEmails.first;

    await finishSignIn(tester);

    expect(await outcome, isTrue);
    expect(router.current.name, 'AdminRoute');
    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), isEmpty);
  });

  testWidgets('logout during the resumed guard evaluation cannot insert or requeue the destination', (tester) async {
    await pumpRouter(tester, bootstrapCompleted: false);
    await requestDestination(tester);
    final outcome = continuation.pendingNavigation!;
    await finishSignIn(tester);

    continuation.markBootstrapCompleted();
    continuation.cancel();
    app_state.prismUser = createGuestPrismUser();
    await tester.pumpAndSettle();

    expect(await outcome, isFalse);
    expect(router.current.name, DashboardRoute.name);
    expect(continuation.pendingNavigation, isNull);
    expect(router.stackData.where((route) => route.name == 'GuardedRoute'), isEmpty);
    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), isEmpty);
  });

  testWidgets('a multi-route navigation keeps the original pending routes', (tester) async {
    await pumpRouter(tester);
    unawaited(router.pushAll([destination, const PageRouteInfo<void>('SecondRoute')]));
    await tester.pumpAndSettle();
    final outcome = continuation.pendingNavigation!;
    await finishSignIn(tester);

    expect(await outcome, isTrue);
    expect(router.stackData.map((route) => route.name), [DashboardRoute.name, 'GuardedRoute', 'SecondRoute']);
    expect(router.stackData[1].args, same(args));
  });

  testWidgets('logout while a second guard is pending removes its late insertion', (tester) async {
    await pumpRouter(tester);
    unawaited(router.push(const PageRouteInfo<void>('DelayedRoute')));
    await tester.pumpAndSettle();
    final outcome = continuation.pendingNavigation!;
    await finishSignIn(tester);
    expect(router.pausedGuard.entered, isTrue);
    expect(router.current.name, DashboardRoute.name);

    continuation.cancel();
    app_state.prismUser = createGuestPrismUser();
    router.pausedGuard.release.complete();
    await tester.pumpAndSettle();

    expect(await outcome, isFalse);
    expect(router.current.name, DashboardRoute.name);
    expect(continuation.pendingNavigation, isNull);
    expect(router.stackData.where((route) => route.name == 'DelayedRoute'), isEmpty);
    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), isEmpty);
  });

  testWidgets('a guarded nested route retains its typed parent after the original scope is destroyed', (tester) async {
    await pumpRouter(tester);
    const childArgs = _DestinationArgs('nested-wall');
    unawaited(
      router.push(
        PageRouteInfo<_DestinationArgs>(
          'ParentRoute',
          args: args,
          rawPathParams: const {'group': 'creator-7'},
          initialChildren: const [
            PageRouteInfo<_DestinationArgs>('ChildRoute', args: childArgs, rawPathParams: {'id': 'wall-42'}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.current.name, OnboardingV2ShellRoute.name);
    final outcome = continuation.pendingNavigation!;

    await finishSignIn(tester);

    expect(await outcome, isTrue);
    expect(router.currentSegments.map((route) => route.name), ['ParentRoute', 'ChildRoute']);
    expect(router.currentSegments.first.args, same(args));
    expect(router.currentSegments.first.params.getString('group'), 'creator-7');
    expect(router.currentSegments.last.args, same(childArgs));
    expect(router.currentSegments.last.params.getString('id'), 'wall-42');
  });

  testWidgets('a newer action during sign-in replaces the pending action without another onboarding', (tester) async {
    await pumpRouter(tester);
    await requestDestination(tester);
    final previous = continuation.pendingNavigation!;
    const latestArgs = _DestinationArgs('latest');
    unawaited(
      router.push(
        const PageRouteInfo<_DestinationArgs>('GuardedRoute', args: latestArgs, rawPathParams: {'id': 'latest-wall'}),
      ),
    );
    await tester.pumpAndSettle();
    expect(await previous, isFalse);
    final latest = continuation.pendingNavigation!;
    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), hasLength(1));

    await finishSignIn(tester);

    expect(await latest, isTrue);
    expect(router.current.args, same(latestArgs));
    expect(router.current.params.getString('id'), 'latest-wall');
    expect(router.stackData.where((route) => route.name == 'GuardedRoute'), hasLength(1));
  });

  testWidgets('logout cancels a late nested guard while retaining the existing parent page', (tester) async {
    await pumpRouter(tester);
    final parent = PageRouteInfo<_DestinationArgs>(
      'ParentRoute',
      args: args,
      rawPathParams: const {'group': 'creator-7'},
    );
    unawaited(router.push(parent.copyWith(children: [const PageRouteInfo<void>('DelayedChildRoute')])));
    await tester.pumpAndSettle();
    final outcome = continuation.pendingNavigation!;
    app_state.prismUser.loggedIn = true;
    unawaited(router.replaceAll([const SplashWidgetRoute()]));
    await tester.pumpAndSettle();
    unawaited(router.replaceAll([parent]));
    await tester.pumpAndSettle();
    expect(router.pausedGuard.entered, isTrue);

    continuation.cancel();
    app_state.prismUser = createGuestPrismUser();
    router.pausedGuard.release.complete();
    await tester.pumpAndSettle();

    expect(await outcome, isFalse);
    expect(router.currentSegments.first.name, 'ParentRoute');
    expect(router.currentSegments.where((route) => route.name == 'DelayedChildRoute'), isEmpty);
    expect(router.stackData.where((route) => route.name == OnboardingV2ShellRoute.name), isEmpty);
    expect(continuation.pendingNavigation, isNull);
  });

  testWidgets('disposing a router never replays its action in a later session', (tester) async {
    await pumpRouter(tester);
    await requestDestination(tester);
    final outcome = continuation.pendingNavigation!;
    continuation.dispose();
    await finishSignIn(tester);

    expect(await outcome, isFalse);
    expect(router.current.name, DashboardRoute.name);
  });

  testWidgets('the dispatcher reports navigation only after the deferred destination becomes visible', (tester) async {
    await pumpRouter(tester);
    final events = <AnalyticsEvent>[];
    final dispatcher = DeepLinkDispatcher(
      router: router,
      whenReady: () async => true,
      navigation: _DestinationNavigation(destination),
      track: (event) async => events.add(event),
    );
    addTearDown(dispatcher.dispose);
    final result = dispatcher.openAction(
      const UserLinkIntent(profileIdentifier: 'creator', rawUri: 'prism://user/creator'),
      source: DeepLinkSourceValue.inApp,
    );
    await tester.pumpAndSettle();

    expect(router.current.name, OnboardingV2ShellRoute.name);
    expect(events.whereType<DeepLinkNavigationResultEvent>(), isEmpty);

    await finishSignIn(tester);

    expect(await result, DeepLinkDispatchResult.navigated);
    expect(router.current.args, same(args));
    final navigationResult = events.whereType<DeepLinkNavigationResultEvent>().single;
    expect(navigationResult.toWireParameters()['result'], 'navigated');
  });

  testWidgets('the dispatcher reports cancellation when sign-in is abandoned as a guest', (tester) async {
    await pumpRouter(tester);
    final events = <AnalyticsEvent>[];
    final dispatcher = DeepLinkDispatcher(
      router: router,
      whenReady: () async => true,
      navigation: _DestinationNavigation(destination),
      track: (event) async => events.add(event),
    );
    addTearDown(dispatcher.dispose);
    final result = dispatcher.openAction(
      const UserLinkIntent(profileIdentifier: 'creator', rawUri: 'prism://user/creator'),
      source: DeepLinkSourceValue.inApp,
    );
    await tester.pumpAndSettle();
    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();

    expect(await result, DeepLinkDispatchResult.cancelled);
    expect(router.current.name, DashboardRoute.name);
    expect(app_state.prismUser.loggedIn, isFalse);
    expect(events.whereType<DeepLinkNavigationResultEvent>().single.toWireParameters()['result'], 'cancelled');
  });

  testWidgets('the dispatcher reports blocked when an admin guard rejects the resumed destination', (tester) async {
    await pumpRouter(tester);
    final events = <AnalyticsEvent>[];
    final dispatcher = DeepLinkDispatcher(
      router: router,
      whenReady: () async => true,
      navigation: const _DestinationNavigation(PageRouteInfo<void>('AdminRoute')),
      track: (event) async => events.add(event),
    );
    addTearDown(dispatcher.dispose);
    final result = dispatcher.openAction(
      const UserLinkIntent(profileIdentifier: 'creator', rawUri: 'prism://user/creator'),
      source: DeepLinkSourceValue.inApp,
    );
    await tester.pumpAndSettle();
    await finishSignIn(tester);

    expect(await result, DeepLinkDispatchResult.blocked);
    expect(router.current.name, NotFoundRoute.name);
    expect(events.whereType<DeepLinkNavigationResultEvent>().single.toWireParameters()['result'], 'blocked');
  });
}
