import 'dart:async';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_startup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/stub_app_router.dart';

const _user = UserLinkIntent(profileIdentifier: 'akshay', rawUri: 'https://prismwalls.com/user/akshay');
const _refer = ReferLinkIntent(inviterId: 'inviter-1', rawUri: 'https://prismwalls.com/refer/inviter-1');

void main() {
  late StubAppRouter router;
  late List<DeepLinkActionEntity> handled;
  late List<Object> errors;
  late DeepLinkStartupGate gate;

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();
  }

  setUp(() {
    router = StubAppRouter();
    handled = <DeepLinkActionEntity>[];
    errors = <Object>[];
    gate = DeepLinkStartupGate(
      router: router,
      handle: (action) async => handled.add(action),
      onError: (action, error, stackTrace) => errors.add(error),
    );
  });

  tearDown(() => gate.dispose());

  testWidgets('a link that arrives during onboarding waits until the stack leaves onboarding', (tester) async {
    await pumpRouter(tester);
    unawaited(router.replaceAll([const OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();
    gate.markBootstrapCompleted();

    gate.add(_user);
    await tester.pumpAndSettle();
    expect(handled, isEmpty);

    unawaited(router.replaceAll([const SplashWidgetRoute()]));
    await tester.pumpAndSettle();
    expect(handled, isEmpty);

    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();
    expect(handled, <DeepLinkActionEntity>[_user]);

    unawaited(router.push(const DownloadRoute()));
    await tester.pumpAndSettle();
    expect(handled, hasLength(1));
  });

  testWidgets('a link waits for the config even when the stack is past startup', (tester) async {
    await pumpRouter(tester);
    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();

    gate.add(_user);
    await tester.pumpAndSettle();
    expect(handled, isEmpty);

    gate.markBootstrapCompleted();
    await tester.pumpAndSettle();
    expect(handled, <DeepLinkActionEntity>[_user]);
  });

  testWidgets('a referral link runs during onboarding and does not wait behind a held link', (tester) async {
    await pumpRouter(tester);
    unawaited(router.replaceAll([const OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();
    gate.markBootstrapCompleted();

    gate.add(_user);
    gate.add(_refer);
    await tester.pumpAndSettle();

    expect(handled, <DeepLinkActionEntity>[_refer]);

    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();
    expect(handled, <DeepLinkActionEntity>[_refer, _user]);
  });

  testWidgets('a push tap waits for the end of startup however long onboarding takes', (tester) async {
    await pumpRouter(tester);
    unawaited(router.replaceAll([const OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();
    gate.markBootstrapCompleted();
    var ready = false;
    unawaited(gate.whenReady().then((value) => ready = value));

    await tester.pump(const Duration(minutes: 10));
    expect(ready, isFalse);

    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();
    expect(ready, isTrue);
  });

  testWidgets('a push tap never gets through while the config has not loaded', (tester) async {
    await pumpRouter(tester);
    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();
    var completed = false;
    unawaited(gate.whenReady().then((_) => completed = true));

    await tester.pump(const Duration(minutes: 1));
    expect(completed, isFalse);

    gate.dispose();
    await tester.pump();
    expect(completed, isTrue);
    expect(await gate.whenReady(), isFalse);
  });

  testWidgets('a link that throws goes to onError and later links still run', (tester) async {
    final failing = DeepLinkStartupGate(
      router: router,
      handle: (action) async {
        if (action == _user) throw StateError('boom');
        handled.add(action);
      },
      onError: (action, error, stackTrace) => errors.add(error),
    );
    addTearDown(failing.dispose);
    await pumpRouter(tester);
    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();

    failing.markBootstrapCompleted();
    failing.add(_user);
    failing.add(_refer);
    await tester.pumpAndSettle();

    expect(errors, hasLength(1));
    expect(handled, contains(_refer));
  });

  testWidgets('a disposed gate stops listening to the router', (tester) async {
    await pumpRouter(tester);
    unawaited(router.replaceAll([const OnboardingV2ShellRoute()]));
    await tester.pumpAndSettle();
    gate.markBootstrapCompleted();
    gate.add(_user);
    gate.dispose();

    unawaited(router.replaceAll([const DashboardRoute()]));
    await tester.pumpAndSettle();

    expect(handled, isEmpty);
  });
}
