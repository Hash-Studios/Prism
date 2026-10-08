import 'dart:async';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/push_tap_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/stub_app_router.dart';

void main() {
  testWidgets('waitForStartupEnd has no time limit and finishes when the stack leaves startup', (tester) async {
    final router = StubAppRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();
    unawaited(router.replaceAll([const OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();

    bool? result;
    unawaited(waitForStartupEnd(router, isMounted: () => true).then((value) => result = value));
    await tester.pump(const Duration(minutes: 30));
    expect(result, isNull);

    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('waitForStartupEnd returns at once when startup is over, and false when unmounted', (tester) async {
    final router = StubAppRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();
    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();

    expect(await waitForStartupEnd(router, isMounted: () => true), isTrue);
    expect(await waitForStartupEnd(router, isMounted: () => false), isFalse);
  });

  testWidgets('waitForStartupEnd gives up with false when the owner is gone at the next router change', (tester) async {
    final router = StubAppRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();
    unawaited(router.replaceAll([const OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();
    var mounted = true;
    bool? result;
    unawaited(waitForStartupEnd(router, isMounted: () => mounted).then((value) => result = value));

    mounted = false;
    unawaited(router.replaceAll([const SplashWidgetRoute()]));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
