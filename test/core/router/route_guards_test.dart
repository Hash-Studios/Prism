import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/router/route_guards.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNavigationResolver extends Mock implements NavigationResolver {}

class _MockStackRouter extends Mock implements StackRouter {}

class _MockRootRouter extends Mock implements RootStackRouter {}

void main() {
  late _MockNavigationResolver resolver;
  late _MockStackRouter router;

  setUp(() {
    resolver = _MockNavigationResolver();
    router = _MockStackRouter();
    app_state.prismUser = createGuestPrismUser();
    when(() => resolver.next()).thenReturn(null);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    app_state.prismUser = createGuestPrismUser();
  });

  test('allows a guest to enter the dashboard on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final dashboard = AppRouter().routes.singleWhere((route) => route.path == '/dashboard');
    final guard = dashboard.guards.single as SignedInGuard;

    guard.onNavigation(resolver, router);

    verify(() => resolver.next()).called(1);
    verifyNever(() => resolver.next(false));
    verifyNever(() => router.pushPath<Object?>(any()));
  });

  test('keeps account-required routes behind the sign-in guard', () {
    final root = _MockRootRouter();
    when(() => router.root).thenReturn(root);
    when(() => router.isRoot).thenReturn(true);
    when(() => root.root).thenReturn(root);
    when(() => root.stackData).thenReturn([]);
    when(() => resolver.route).thenReturn(AppRouter().matcher.matchByRoute(const ShopRoute())!);
    when(() => resolver.pendingRoutes).thenReturn([]);
    when(
      () => root.pushPath<Object?>('/onboarding/v2', onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) => Completer<Object?>().future);
    addTearDown(AuthNavigationContinuation.of(root).dispose);

    const SignedInGuard().onNavigation(resolver, router);

    expect(AuthNavigationContinuation.of(root).pendingNavigation, isNotNull);
    verify(() => root.pushPath<Object?>('/onboarding/v2', onFailure: any(named: 'onFailure'))).called(1);
    verify(() => resolver.next(false)).called(1);
  });

  test('allows a signed-in user without redirecting', () {
    app_state.prismUser.loggedIn = true;

    const SignedInGuard().onNavigation(resolver, router);

    verify(() => resolver.next()).called(1);
    verifyNever(() => router.pushPath<Object?>(any()));
  });

  test('a signed-in non-admin stays denied without starting sign-in', () {
    app_state.prismUser.loggedIn = true;
    when(() => router.pushPath<Object?>('/not-found')).thenAnswer((_) async => null);

    const AdminGuard().onNavigation(resolver, router);

    verify(() => resolver.next(false)).called(1);
    verify(() => router.pushPath<Object?>('/not-found')).called(1);
    verifyNever(() => router.pushPath<Object?>('/onboarding/v2'));
  });
}
