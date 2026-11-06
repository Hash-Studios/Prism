import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/folders/biz/folder_save/folder_save_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_run.dart';
import 'package:Prism/features/folders/domain/repositories/folder_save_gateway.dart';
import 'package:Prism/features/folders/views/widgets/folder_save_views.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';

class _Gateway extends Mock implements FolderSaveGateway {}

const FolderSaveTarget _target = FolderSaveTarget(folderId: 'f1', name: 'Night', ownerId: 'viewer');
const FolderSaveWall _wall = FolderSaveWall(id: 'p1', source: WallpaperSource.prism);
const FolderSaveAccount _account = FolderSaveAccount(
  isPro: true,
  premiumUnlocked: true,
  balance: 0,
  graceLeft: 0,
  price: 10,
);

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: kLightTheme,
  home: Scaffold(body: child),
);

Future<void> _pump(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _Gateway gateway;
  late FolderSaveBloc bloc;

  setUpAll(() {
    registerFallbackValue(_wall);
    registerFallbackValue(const FolderSaveItem(wall: _wall, kind: FolderSaveKind.free));
  });

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    gateway = _Gateway();
    when(() => gateway.ownerId).thenReturn('viewer');
    when(() => gateway.account()).thenReturn(_account);
    when(() => gateway.wallAccess(any())).thenAnswer((_) async => <String, WallAccess>{'p1': WallAccess.open});
    when(() => gateway.isSaved(any())).thenAnswer((_) async => false);
    when(() => gateway.clearTemporaryFiles()).thenAnswer((_) async {});
    when(() => gateway.requestAccess(any())).thenAnswer((_) async => FolderSaveAccess.granted);
    when(
      () => gateway.save(
        any(),
        album: any(named: 'album'),
        maxCoins: any(named: 'maxCoins'),
      ),
    ).thenAnswer((_) async => const FolderWallOutcome.saved());
    bloc = FolderSaveBloc(gateway);
    getIt.registerSingleton<FolderSaveBloc>(bloc);
  });

  tearDown(() async {
    await getIt.reset();
    await bloc.close();
    AnalyticsRuntime.reset();
  });

  testWidgets('Try again retries the failed plan without closing the sheet', (tester) async {
    int reads = 0;
    when(() => gateway.wallAccess(any())).thenAnswer((_) async {
      if (++reads == 1) throw StateError('offline');
      return <String, WallAccess>{'p1': WallAccess.open};
    });
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(openFolderSave(context, target: _target, walls: const <FolderSaveWall>[_wall])),
            child: const Text('Open save'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open save'));
    await _pump(tester);
    expect(bloc.state, isA<FolderSavePlanFailed>());

    await tester.tap(find.text('Try again'));
    await _pump(tester);

    expect(reads, 2);
    expect(find.byType(FolderSavePlanSheet), findsOneWidget);
    expect(bloc.state, isA<FolderSavePlanned>());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a different folder page does not suppress the completion announcement', (tester) async {
    final List<FolderSaveRun> announced = <FolderSaveRun>[];
    await tester.pumpWidget(_host(const FolderSaveStatus(folderId: 'other')));
    bloc.add(const FolderSaveEvent.planRequested(target: _target, walls: <FolderSaveWall>[_wall]));
    await _pump(tester);
    expect(bloc.state, isA<FolderSavePlanned>());

    bloc.add(FolderSaveEvent.started(choice: FolderSaveChoice.all, announce: (_, run) => announced.add(run)));
    await _pump(tester);

    expect(bloc.state, isA<FolderSaveFinished>());
    expect(announced, hasLength(1));
    expect(announced.single.saved, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a reused folder page releases its previous folder watcher', (tester) async {
    final List<FolderSaveRun> announced = <FolderSaveRun>[];
    await tester.pumpWidget(_host(const FolderSaveStatus(folderId: 'f1')));
    await tester.pumpWidget(_host(const FolderSaveStatus(folderId: 'other')));
    bloc.add(const FolderSaveEvent.planRequested(target: _target, walls: <FolderSaveWall>[_wall]));
    await _pump(tester);
    bloc.add(FolderSaveEvent.started(choice: FolderSaveChoice.all, announce: (_, run) => announced.add(run)));
    await _pump(tester);

    expect(bloc.state, isA<FolderSaveFinished>());
    expect(announced, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an all-saved plan shows its empty explanation without a save action', (tester) async {
    when(() => gateway.isSaved(any())).thenAnswer((_) async => true);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(openFolderSave(context, target: _target, walls: const <FolderSaveWall>[_wall])),
            child: const Text('Open save'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open save'));
    await _pump(tester);

    expect(find.text('1 wallpaper is already in Downloads'), findsOneWidget);
    expect(find.text('There is nothing new to save in this folder.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('folder-save-all')), findsNothing);
    expect(find.byKey(const ValueKey<String>('folder-save-paid')), findsNothing);
    expect(find.byKey(const ValueKey<String>('folder-save-free')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
