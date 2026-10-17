import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/route_guards.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNavigationResolver extends Mock implements NavigationResolver {}

class _MockStackRouter extends Mock implements StackRouter {}

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
    when(() => router.pushPath<Object?>('/onboarding/v2')).thenAnswer((_) => Future<Object?>.value());

    const SignedInGuard().onNavigation(resolver, router);

    verify(() => router.pushPath<Object?>('/onboarding/v2')).called(1);
    verify(() => resolver.next(false)).called(1);
  });
}
