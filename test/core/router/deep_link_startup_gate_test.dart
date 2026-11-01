import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_startup_gate.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/stub_app_router.dart';

void main() {
  late StubAppRouter router;
  late DeepLinkStartupGate gate;

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    app_state.prismUser = createGuestPrismUser()..loggedIn = true;
    router = StubAppRouter();
    gate = DeepLinkStartupGate(router: router);
  });

  tearDown(() {
    gate.dispose();
    app_state.prismUser = createGuestPrismUser();
  });

  testWidgets('navigation waits for onboarding and its replacement splash to leave the stack', (tester) async {
    await pumpRouter(tester);
    unawaited(router.replaceAll([OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();
    gate.markBootstrapCompleted();
    var ready = false;
    unawaited(gate.whenReady().then((value) => ready = value));

    await tester.pump(const Duration(minutes: 10));
    expect(ready, isFalse);
    unawaited(router.replaceAll([const SplashWidgetRoute()]));
    await tester.pumpAndSettle();
    expect(ready, isFalse);

    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();
    expect(ready, isTrue);
    expect(await gate.whenReady(), isTrue);
  });

  testWidgets('bootstrap readiness permits referral storage while onboarding is still visible', (tester) async {
    await pumpRouter(tester);
    unawaited(router.replaceAll([OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();
    var bootstrapped = false;
    var ready = false;
    unawaited(gate.whenBootstrapped().then((value) => bootstrapped = value));
    unawaited(gate.whenReady().then((value) => ready = value));
    await tester.pump();
    expect(bootstrapped, isFalse);

    gate.markBootstrapCompleted();
    await tester.pump();
    expect(bootstrapped, isTrue);
    expect(ready, isFalse);
    expect(await gate.whenBootstrapped(), isTrue);
  });

  testWidgets('a browsable router still waits for successful bootstrap', (tester) async {
    await pumpRouter(tester);
    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();
    var ready = false;
    unawaited(gate.whenReady().then((value) => ready = value));
    await tester.pump();
    expect(ready, isFalse);

    gate.markBootstrapCompleted();
    await tester.pump();
    expect(ready, isTrue);
  });

  testWidgets('dispose resolves all waiting gates false and later router changes cannot reopen them', (tester) async {
    await pumpRouter(tester);
    final bootstrap = gate.whenBootstrapped();
    final navigation = gate.whenReady();
    gate.dispose();
    expect(await bootstrap, isFalse);
    expect(await navigation, isFalse);

    gate.markBootstrapCompleted();
    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();
    expect(await gate.whenBootstrapped(), isFalse);
    expect(await gate.whenReady(), isFalse);
  });
}
