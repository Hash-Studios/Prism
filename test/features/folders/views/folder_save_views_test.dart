import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/biz/folder_save/folder_save_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_run.dart';
import 'package:Prism/features/folders/domain/repositories/folder_save_gateway.dart';
import 'package:Prism/features/folders/views/widgets/folder_save_views.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

const FolderSaveTarget _target = FolderSaveTarget(folderId: 'f1', name: 'Night', ownerId: 'u1');

FolderSaveAccount _account({bool isPro = false, int balance = 0, int graceLeft = 0, int price = 10}) =>
    FolderSaveAccount(isPro: isPro, premiumUnlocked: isPro, balance: balance, graceLeft: graceLeft, price: price);

FolderSaveWall _wall(String id) => FolderSaveWall(id: id, source: WallpaperSource.prism, label: 'Wall $id');

FolderSaveRun? _runOf(FolderSaveState state) => switch (state) {
  FolderSaveRunning(:final run) || FolderSaveFinished(:final run) => run,
  _ => null,
};

class FakeFolderSaveGateway implements FolderSaveGateway {
  FolderSaveAccount accountValue = _account();

  /// Access per Prism wall id. A wall not listed is open.
  final Map<String, WallAccess> access = <String, WallAccess>{};

  /// Wall ids the server no longer serves. They are left out of the access map.
  final Set<String> unserved = <String>{};

  /// Wall keys, for example 'prism:p1', that are already in Downloads.
  final Set<String> savedKeys = <String>{};

  /// Save outcome per wall id. A wall not listed saves.
  final Map<String, FolderWallOutcome> outcomes = <String, FolderWallOutcome>{};

  /// A wall id held here does not finish until the test completes its completer.
  final Map<String, Completer<FolderWallOutcome>> holds = <String, Completer<FolderWallOutcome>>{};

  @override
  String get ownerId => 'u1';

  @override
  FolderSaveAccount account() => accountValue;

  @override
  Future<Map<String, WallAccess>> wallAccess(List<String> ids) async => <String, WallAccess>{
    for (final String id in ids)
      if (!unserved.contains(id)) id: access[id] ?? WallAccess.open,
  };

  @override
  Future<bool> isSaved(FolderSaveWall wall) async => savedKeys.contains(wall.key);

  @override
  Future<FolderSaveAccess> requestAccess(String album) async => FolderSaveAccess.granted;

  @override
  Future<FolderWallOutcome> save(FolderSaveItem item, {required String album, required int maxCoins}) {
    final Completer<FolderWallOutcome>? hold = holds[item.wall.id];
    if (hold != null) return hold.future;
    return Future<FolderWallOutcome>.value(outcomes[item.wall.id] ?? const FolderWallOutcome.saved());
  }

  @override
  Future<void> clearTemporaryFiles() async {}
}

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: kLightTheme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

/// A button that opens the plan sheet the way openFolderSave does, with the bloc provided above the route.
Widget _sheetHost(FolderSaveBloc bloc, {double textScale = 1}) => _app(
  Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => unawaited(
            showPrismSheet<void>(
              context,
              builder: (_) => BlocProvider<FolderSaveBloc>.value(
                value: bloc,
                child: FolderSavePlanSheet(onRetry: () {}),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ),
  textScale: textScale,
);

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late FakeFolderSaveGateway gateway;
  late FolderSaveBloc bloc;

  setUp(() {
    gateway = FakeFolderSaveGateway();
    bloc = FolderSaveBloc(gateway);
    getIt.registerSingleton<FolderSaveBloc>(bloc);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async => true,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    AnalyticsRuntime.reset();
    await bloc.close();
    await getIt.reset();
  });

  // The sheet and the progress row can animate, so pump fixed frames instead of settling.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  // Lets the bloc's async work run on the real event loop, then draws the frame.
  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }

  Future<void> planWalls(WidgetTester tester, List<String> ids) async {
    final Future<FolderSaveState> planned = bloc.stream.firstWhere((state) => state is FolderSavePlanned);
    bloc.add(
      FolderSaveEvent.planRequested(target: _target, walls: <FolderSaveWall>[for (final String id in ids) _wall(id)]),
    );
    await tester.runAsync(() => planned);
  }

  Future<void> openPlanSheet(WidgetTester tester, List<String> ids, {double textScale = 1}) async {
    await tester.pumpWidget(_sheetHost(bloc, textScale: textScale));
    await planWalls(tester, ids);
    await tester.pump();
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> summaryRun(WidgetTester tester, List<String> ids, {double textScale = 1}) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(body: FolderSaveStatus(folderId: 'f1')),
        textScale: textScale,
      ),
    );
    await planWalls(tester, ids);
    final Future<FolderSaveState> finished = bloc.stream.firstWhere((state) => state is FolderSaveFinished);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await tester.runAsync(() => finished);
    await settle(tester);
  }

  /// Non-Pro, 20 coins, 2 free downloads left. Walls p1 and p2 are free, p3 and p4 cost 10 coins, p5 needs Pro.
  Future<void> freeAndCoinsScenario(WidgetTester tester, {double textScale = 1}) async {
    gateway.accountValue = _account(balance: 20, graceLeft: 2);
    gateway.access['p5'] = WallAccess.premium;
    await openPlanSheet(tester, <String>['p1', 'p2', 'p3', 'p4', 'p5'], textScale: textScale);

    expect(find.text('2 wallpapers are free'), findsOneWidget);
    expect(find.text('2 wallpapers cost 10 coins each'), findsOneWidget);
    expect(find.text('1 wallpaper needs Pro'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('folder-save-paid')), findsOneWidget);
    expect(find.text('Save all I can (20 coins)'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('folder-save-free')), findsOneWidget);
    expect(find.text('Save the 2 free wallpapers'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('folder-save-all')), findsNothing);
  }

  testWidgets('a free user with coins sees the free and the paid Save all buttons', (tester) async {
    await freeAndCoinsScenario(tester);
  });

  testWidgets('a low balance buys only the walls it covers', (tester) async {
    gateway.accountValue = _account(balance: 10, graceLeft: 2);
    gateway.access['p5'] = WallAccess.premium;
    await openPlanSheet(tester, <String>['p1', 'p2', 'p3', 'p4', 'p5']);

    expect(find.text('Save all I can (10 coins)'), findsOneWidget);
    expect(find.text('Your coins cover 1 paid wallpaper.'), findsOneWidget);
  });

  testWidgets('with no coins left, the paid button is gone and the sheet says so', (tester) async {
    gateway.accountValue = _account(graceLeft: 2);
    gateway.access['p5'] = WallAccess.premium;
    await openPlanSheet(tester, <String>['p1', 'p2', 'p3', 'p4', 'p5']);

    expect(find.byKey(const ValueKey<String>('folder-save-paid')), findsNothing);
    expect(find.text('You do not have enough coins for a paid wallpaper.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('folder-save-free')), findsOneWidget);
    expect(find.text('Save the 2 free wallpapers'), findsOneWidget);
  });

  testWidgets('a Pro user gets one Save all button and no coin rows', (tester) async {
    gateway.accountValue = _account(isPro: true);
    gateway.access['p4'] = WallAccess.premium;
    await openPlanSheet(tester, <String>['p1', 'p2', 'p3', 'p4']);

    expect(find.byKey(const ValueKey<String>('folder-save-all')), findsOneWidget);
    expect(find.text('Save 4 wallpapers'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('folder-save-paid')), findsNothing);
    expect(find.byKey(const ValueKey<String>('folder-save-free')), findsNothing);
    expect(find.text('4 wallpapers are free'), findsOneWidget);
    expect(find.textContaining('coins'), findsNothing);
  });

  testWidgets('walls already in Downloads or no longer served are listed as blocked rows', (tester) async {
    gateway.savedKeys.add('prism:p1');
    gateway.unserved.add('p2');
    await openPlanSheet(tester, <String>['p1', 'p2']);

    expect(find.text('1 wallpaper is already in Downloads'), findsOneWidget);
    expect(find.text('1 wallpaper is not available to save'), findsOneWidget);
    expect(find.text('There is nothing new to save in this folder.'), findsOneWidget);
  });

  testWidgets('tapping the paid button closes the sheet and starts a run of the free and coin walls', (tester) async {
    await freeAndCoinsScenario(tester);

    final Future<FolderSaveState> finished = bloc.stream.firstWhere((state) => state is FolderSaveFinished);
    await tester.tap(find.byKey(const ValueKey<String>('folder-save-paid')));
    await settle(tester);

    expect(find.byType(FolderSavePlanSheet), findsNothing);
    expect(bloc.state, anyOf(isA<FolderSaveRunning>(), isA<FolderSaveFinished>()));
    expect(_runOf(bloc.state)?.queue, hasLength(4));

    // Let the run end before the test does, so its toast does not fire after teardown.
    await tester.runAsync(() => finished);
    await flush(tester);
    expect(bloc.state, isA<FolderSaveFinished>());
  });

  testWidgets('the summary counts saved, already-saved and failed walls, and Done clears it', (tester) async {
    gateway.accountValue = _account(isPro: true);
    gateway.savedKeys.add('prism:p3');
    gateway.outcomes['p2'] = const FolderWallOutcome.failed(FolderSaveFailure.network);
    await summaryRun(tester, <String>['p1', 'p2', 'p3']);

    expect(find.text('1 wallpaper saved'), findsOneWidget);
    expect(find.text('1 already in Downloads'), findsOneWidget);
    expect(find.text('1 failed'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('folder-save-retry')), findsOneWidget);
    expect(find.text('Retry failed'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('folder-save-done')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('folder-save-done')));
    await flush(tester);
    await settle(tester);

    expect(find.text('1 wallpaper saved'), findsNothing);
    expect(bloc.state, isA<FolderSaveIdle>());
  });

  testWidgets('progress counts finished walls, Cancel stops the rest, and the summary says Stopped', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    gateway.accountValue = _account(isPro: true);
    // Three walls hold the three workers. The fourth never starts once Cancel is pressed.
    for (final String id in <String>['p1', 'p2', 'p3']) {
      gateway.holds[id] = Completer<FolderWallOutcome>();
    }
    await tester.pumpWidget(_app(const Scaffold(body: FolderSaveStatus(folderId: 'f1'))));
    await planWalls(tester, <String>['p1', 'p2', 'p3', 'p4']);
    bloc.add(const FolderSaveEvent.started(choice: FolderSaveChoice.all));
    await flush(tester);

    expect(find.text('Saving 0 of 4'), findsOneWidget);
    // The progress row fades in through the switcher. Its semantics node appears once the fade ends.
    await settle(tester);
    expect(find.bySemanticsLabel(RegExp('Saving .* of 4 wallpapers')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('folder-save-cancel')));
    await flush(tester);
    expect(find.text('Stopping…'), findsOneWidget);

    final Future<FolderSaveState> finished = bloc.stream.firstWhere((state) => state is FolderSaveFinished);
    for (final String id in <String>['p1', 'p2', 'p3']) {
      gateway.holds[id]!.complete(const FolderWallOutcome.saved());
    }
    await tester.runAsync(() => finished);
    await settle(tester);

    expect(find.textContaining('Stopped.'), findsOneWidget);
    expect(find.text('Stopped. 3 wallpapers saved'), findsOneWidget);
    expect(find.text('1 not started'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('large text: the plan sheet keeps its Save all buttons readable on a phone', (tester) async {
    _usePhoneSurface(tester);
    await freeAndCoinsScenario(tester, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Save all I can (20 coins)'), findsOneWidget);
    expect(find.text('Save the 2 free wallpapers'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey<String>('folder-save-paid'))).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(find.byKey(const ValueKey<String>('folder-save-free'))).height, greaterThanOrEqualTo(44));
  });

  testWidgets('large text: the summary wraps its buttons without overflow on a phone', (tester) async {
    _usePhoneSurface(tester);
    gateway.accountValue = _account(isPro: true);
    gateway.savedKeys.add('prism:p3');
    gateway.outcomes['p2'] = const FolderWallOutcome.failed(FolderSaveFailure.network);
    await summaryRun(tester, <String>['p1', 'p2', 'p3'], textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('1 wallpaper saved'), findsOneWidget);
    expect(find.text('Retry failed'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
