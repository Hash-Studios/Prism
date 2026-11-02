import 'dart:async';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/updates/app_update_host.dart';
import 'package:Prism/core/updates/code_push_updater.dart';
import 'package:Prism/core/updates/ota_update_controller.dart';
import 'package:Prism/core/updates/store_update_policy.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

const String _restartMessage = 'Close and reopen Prism to finish updating.';
const String _sheetMessage = 'A new version of Prism is available.';
const String _updateLabel = 'Update Prism';
const String _notNowLabel = 'Not now';

class _NestedDashboard extends StatelessWidget {
  const _NestedDashboard({required this.controller, required this.storeUpdate});

  final OtaUpdateController controller;
  final StoreUpdate Function() storeUpdate;

  @override
  Widget build(BuildContext context) => AutoTabsRouter(
    routes: const <PageRouteInfo<Object?>>[HomeTabRoute()],
    builder: (context, child) => AppUpdateHost(controller: controller, storeUpdate: storeUpdate, child: child),
  );
}

class _NestedRouter extends AppRouter {
  _NestedRouter(this.controller, this.storeUpdate);

  final OtaUpdateController controller;
  final StoreUpdate Function() storeUpdate;

  // The app's account guard is not under test here.
  @override
  List<AutoRouteGuard> get guards => const <AutoRouteGuard>[];

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Dashboard',
        builder: (_) => _NestedDashboard(controller: controller, storeUpdate: storeUpdate),
      ),
      children: <AutoRoute>[
        AutoRoute(
          path: 'home',
          initial: true,
          page: PageInfo(HomeTabRoute.name, builder: (_) => const AutoRouter()),
          children: <AutoRoute>[
            AutoRoute(
              path: '',
              initial: true,
              page: PageInfo('HomeRoot', builder: (_) => const Scaffold(body: Text('Home content'))),
            ),
            AutoRoute(
              path: 'detail',
              page: PageInfo('NestedDetail', builder: (_) => const Scaffold(body: Text('Nested detail'))),
            ),
          ],
        ),
      ],
    ),
  ];
}

class _FakeCodePushUpdater implements CodePushUpdater {
  int checkCalls = 0;
  int downloadCalls = 0;
  CodePushStatus checkStatus = CodePushStatus.upToDate;
  int? nextPatch;

  @override
  bool get isAvailable => true;

  @override
  Future<int?> currentPatchNumber() async => null;

  @override
  Future<int?> nextPatchNumber() async => nextPatch;

  @override
  Future<CodePushStatus> checkForUpdate() async {
    checkCalls++;
    return checkStatus;
  }

  @override
  Future<void> downloadUpdate() async {
    downloadCalls++;
  }
}

void main() {
  late _FakeCodePushUpdater updater;
  late SettingsLocalDataSource settings;
  late OtaUpdateController controller;
  late ValueNotifier<bool> paywall;
  late StoreUpdate storeUpdate;

  setUp(() {
    StartupModalSlot.reset();
    updater = _FakeCodePushUpdater();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    controller = OtaUpdateController(
      updater: updater,
      settings: settings,
      analytics: FakeAppAnalytics(),
      release: () => (version: '3.14.0', build: '353'),
    );
    paywall = ValueNotifier<bool>(false);
    storeUpdate = StoreUpdate.none;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppUpdateHost(
          controller: controller,
          storeUpdate: () => storeUpdate,
          paywallPresenting: paywall,
          child: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
  }

  testWidgets('checks for updates on mount', (tester) async {
    await pumpApp(tester);
    await tester.pump();

    expect(updater.checkCalls, 1);
  });

  testWidgets('shows no toast for a downloaded patch', (tester) async {
    updater
      ..checkStatus = CodePushStatus.outdated
      ..nextPatch = 1;
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(updater.downloadCalls, 1);
    expect(find.text(_restartMessage), findsNothing);
    expect(find.text(_sheetMessage), findsNothing);
  });

  testWidgets('waits while another route is on top', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    storeUpdate = StoreUpdate.suggested;
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(find.text(_sheetMessage), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text(_sheetMessage), findsOneWidget);
    expect(find.text(_updateLabel), findsOneWidget);
  });

  testWidgets('waits while a sheet is on the root navigator', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    final BuildContext context = tester.element(find.byType(AppUpdateHost));

    storeUpdate = StoreUpdate.suggested;
    unawaited(showPrismSheet<void>(context, builder: (_) => const Text('Root sheet')));
    await tester.pumpAndSettle();
    expect(find.text(_sheetMessage), findsNothing);

    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.text(_sheetMessage), findsOneWidget);
    expect(find.text(_updateLabel), findsOneWidget);
  });

  testWidgets('waits while a route in the active tab router is on top', (tester) async {
    final router = _NestedRouter(controller, () => storeUpdate);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    final StackRouter tabRouter = AutoRouter.of(tester.element(find.text('Home content')));

    storeUpdate = StoreUpdate.suggested;
    unawaited(tabRouter.push(const PageRouteInfo<void>('NestedDetail')));
    await tester.pumpAndSettle();
    expect(find.text(_sheetMessage), findsNothing);

    tabRouter.pop();
    await tester.pumpAndSettle();
    expect(find.text(_sheetMessage), findsOneWidget);
    router.dispose();
  });

  testWidgets('waits while a paywall is presenting', (tester) async {
    paywall.value = true;
    storeUpdate = StoreUpdate.suggested;
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.text(_sheetMessage), findsNothing);

    paywall.value = false;
    await tester.pumpAndSettle();
    expect(find.text(_sheetMessage), findsOneWidget);
  });

  testWidgets('store update suggested shows the sheet once', (tester) async {
    storeUpdate = StoreUpdate.suggested;
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text(_sheetMessage), findsOneWidget);
    expect(find.text(_updateLabel), findsOneWidget);
    expect(find.text(_notNowLabel), findsOneWidget);
    expect(StartupModalSlot.shown.value, isTrue);

    await tester.tap(find.text(_notNowLabel));
    await tester.pumpAndSettle();
    expect(find.text(_sheetMessage), findsNothing);
  });

  testWidgets('store sheet respects the startup slot', (tester) async {
    StartupModalSlot.tryClaim();
    storeUpdate = StoreUpdate.suggested;
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text(_sheetMessage), findsNothing);
  });

  testWidgets('required and none store updates show no sheet', (tester) async {
    for (final StoreUpdate value in <StoreUpdate>[StoreUpdate.required, StoreUpdate.none]) {
      storeUpdate = value;
      await pumpApp(tester);
      await tester.pumpAndSettle();

      expect(find.text(_sheetMessage), findsNothing);
      expect(find.text(_updateLabel), findsNothing);
      expect(StartupModalSlot.shown.value, isFalse);
    }
  });
}
