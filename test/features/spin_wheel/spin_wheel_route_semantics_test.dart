import 'dart:async';
import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/constants/app_constants.dart' as constants;
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../qa_render/qa_harness.dart' show loadFonts;

enum _Dismissal { close, systemBack, accessibility }

class _Router extends AppRouter {
  _Router(this.dashboardLabel);

  final ValueNotifier<String> dashboardLabel;

  @override
  List<AutoRouteGuard> get guards => const [];

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        DashboardRoute.name,
        builder: (_) => Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: dashboardLabel,
            builder: (_, label, _) => TextButton(onPressed: () {}, child: Text(label)),
          ),
        ),
      ),
    ),
    super.routes.singleWhere((route) => route.page.name == SpinWheelRoute.name),
  ];
}

void main() {
  setUpAll(loadFonts);

  for (final reduceMotion in [false, true]) {
    for (final dismissal in _Dismissal.values) {
      testWidgets('SpinWheelRoute restores semantics after ${dismissal.name}, reduceMotion=$reduceMotion', (
        tester,
      ) async {
        final status = ValueNotifier(const SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 5, price: 10));
        final balance = ValueNotifier(340);
        final dashboardLabel = ValueNotifier('Dashboard before');
        final router = _Router(dashboardLabel);
        app_state.prismUser = constants.createGuestPrismUser()
          ..id = 'semantics-test'
          ..loggedIn = true;
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
          status.dispose();
          balance.dispose();
          dashboardLabel.dispose();
          tester.view.reset();
          app_state.prismUser = constants.createGuestPrismUser();
        });
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router.config(),
            theme: kLightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Dashboard before'), findsOneWidget);

        for (var cycle = 0; cycle < 2; cycle++) {
          unawaited(router.push(SpinWheelRoute(status: status, balance: balance)));
          await tester.pump();
          for (var frame = 0; frame < 24; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.takeException(), isNull);
          }
          final close = tester.getSemantics(find.byTooltip('Close'));
          expect(close.getSemanticsData().tooltip, 'Close');
          expect(close.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
          expect(find.bySemanticsLabel(RegExp('Dashboard')), findsNothing);
          expect(find.bySemanticsLabel('Spin the wheel'), findsOneWidget);

          dashboardLabel.value = 'Dashboard updated $cycle';
          balance.value += 1;
          await tester.pump();
          expect(tester.takeException(), isNull);
          switch (dismissal) {
            case _Dismissal.close:
              await tester.tap(find.byTooltip('Close'));
            case _Dismissal.systemBack:
              await tester.binding.handlePopRoute();
            case _Dismissal.accessibility:
              tester.binding.performSemanticsAction(
                SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: close.id),
              );
          }
          for (var frame = 0; frame < 24; frame++) {
            dashboardLabel.value = 'Dashboard $cycle frame $frame';
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.takeException(), isNull);
          }
          expect(router.current.name, DashboardRoute.name);
          expect(find.bySemanticsLabel('Dashboard $cycle frame 23'), findsOneWidget);
          expect(find.byTooltip('Close'), findsNothing);
          expect(find.text('Spin the wheel'), findsNothing);
        }
      });
    }
  }
}
