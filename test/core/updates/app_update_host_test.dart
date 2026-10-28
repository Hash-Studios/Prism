import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/updates/app_update_host.dart';
import 'package:Prism/core/updates/code_push_updater.dart';
import 'package:Prism/core/updates/ota_update_controller.dart';
import 'package:Prism/core/updates/store_update_policy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

const String _toastMessage = 'Close and reopen Prism to finish updating.';
const String _sheetMessage = 'A new version of Prism is available.';
const String _updateLabel = 'Update Prism';
const String _notNowLabel = 'Not now';

class _FakeCodePushUpdater implements CodePushUpdater {
  int checkCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<int?> currentPatchNumber() async => null;

  @override
  Future<int?> nextPatchNumber() async => null;

  @override
  Future<CodePushStatus> checkForUpdate() async {
    checkCalls++;
    return CodePushStatus.upToDate;
  }

  @override
  Future<void> downloadUpdate() async {}
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

  tearDown(() => toasts.overlayResolver = null);

  Future<void> pumpApp(WidgetTester tester) async {
    toasts.overlayResolver = () => tester.state<OverlayState>(find.byType(Overlay).first);
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

  // Lets the toast timer (2.4s plus 20ms per character) and its exit animation finish.
  Future<void> settleToasts(WidgetTester tester) => tester.pump(const Duration(seconds: 10));

  void setRestart() =>
      controller.announcement.value = const PendingRestart(version: '3.14.0', build: '353', patchNumber: 1);

  testWidgets('checks for updates on mount', (tester) async {
    await pumpApp(tester);
    await tester.pump();

    expect(updater.checkCalls, 1);
    await settleToasts(tester);
  });

  testWidgets('shows the restart message once', (tester) async {
    await pumpApp(tester);
    setRestart();
    await tester.pumpAndSettle();

    expect(find.text(_toastMessage), findsOneWidget);
    expect(settings.get<String?>(OtaUpdateController.announcedKey), '3.14.0+353#1');
    expect(controller.announcement.value, isNull);
    await settleToasts(tester);
  });

  testWidgets('waits while another route is on top', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();

    setRestart();
    await tester.pumpAndSettle();
    expect(find.text(_toastMessage), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text(_toastMessage), findsOneWidget);
    await settleToasts(tester);
  });

  testWidgets('waits while a paywall is presenting', (tester) async {
    await pumpApp(tester);
    paywall.value = true;
    setRestart();
    await tester.pumpAndSettle();
    expect(find.text(_toastMessage), findsNothing);

    paywall.value = false;
    await tester.pumpAndSettle();
    expect(find.text(_toastMessage), findsOneWidget);
    await settleToasts(tester);
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
    await settleToasts(tester);
  });

  testWidgets('store sheet respects the startup slot', (tester) async {
    StartupModalSlot.tryClaim();
    storeUpdate = StoreUpdate.suggested;
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text(_sheetMessage), findsNothing);
    await settleToasts(tester);
  });

  testWidgets('restart message waits for the store sheet', (tester) async {
    storeUpdate = StoreUpdate.suggested;
    setRestart();
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text(_sheetMessage), findsOneWidget);
    expect(find.text(_toastMessage), findsNothing);

    await tester.tap(find.text(_notNowLabel));
    await tester.pumpAndSettle();
    expect(find.text(_toastMessage), findsOneWidget);
    await settleToasts(tester);
  });

  testWidgets('required and none store updates show no sheet', (tester) async {
    for (final StoreUpdate value in <StoreUpdate>[StoreUpdate.required, StoreUpdate.none]) {
      storeUpdate = value;
      await pumpApp(tester);
      await tester.pumpAndSettle();

      expect(find.text(_sheetMessage), findsNothing);
      expect(find.text(_updateLabel), findsNothing);
      expect(StartupModalSlot.shown.value, isFalse);
      await settleToasts(tester);
    }
  });
}
