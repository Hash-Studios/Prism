import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart';
import 'package:Prism/features/live_wallpaper/views/widgets/live_wallpaper_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import 'fake_live_wallpaper_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  late FakeLiveWallpaperRepository repository;
  late LiveWallpaperBloc bloc;
  late List<(String, Map<String, dynamic>)> calls;

  setUp(() async {
    await backend.install();
    repository = FakeLiveWallpaperRepository();
    calls = <(String, Map<String, dynamic>)>[];
    backend.onCall = (String name, Map<String, dynamic> params) async {
      calls.add((name, params));
      return <String, Object?>{
        'success': true,
        'changed': true,
        'previousBalance': 100,
        'currentBalance': 80,
        'delta': -20,
        'reason': 'ok',
        'passUntil': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
      };
    };
    CoinsService.instance.balanceNotifier.value = 100;
  });

  tearDown(() async {
    CoinsService.instance.passesNotifier.value = Passes.empty;
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> pump(WidgetTester tester) async {
    bloc = LiveWallpaperBloc(repository)
      ..add(LiveWallpaperEvent.started(isPro: false, unlockedStyles: activeLiveStyleIds()));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LiveWallpaperBloc>.value(value: bloc, child: const LiveWallpaperView()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('applying a locked style offers a 7-day unlock; paying spends liveWallpaperStyle for that style', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Starfield'));
    await tester.pump();
    expect(find.text('Unlock · 20 coins'), findsOneWidget);

    await tester.tap(find.text('Unlock · 20 coins'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock Starfield for 7 days · 20 coins'), findsOneWidget);
    expect(find.text('See Prism Pro'), findsOneWidget);

    await tester.tap(find.text('Unlock Starfield for 7 days · 20 coins'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(calls.single.$1, 'spendCoins');
    expect(calls.single.$2['action'], 'liveWallpaperStyle');
    expect(calls.single.$2['styleId'], 'starfield');
    expect(calls.single.$2['sourceTag'], 'live_wallpaper.style');
    expect(bloc.state.unlockedStyles, contains('starfield'));
    expect(find.text('Set live wallpaper'), findsOneWidget);
    expect(repository.gradientApplies, isEmpty);
  });

  testWidgets('a style that is still unlocked from earlier opens with no lock', (tester) async {
    CoinsService.instance.passesNotifier.value = Passes(
      liveStyles: <String, DateTime>{
        'starfield': DateTime.now().add(const Duration(days: 2)),
        'plasma': DateTime.now().subtract(const Duration(days: 1)),
      },
    );
    await pump(tester);

    expect(bloc.state.unlockedStyles, <String>{'starfield'});
    await tester.tap(find.text('Starfield'));
    await tester.pump();
    expect(find.text('Set live wallpaper'), findsOneWidget);
    await tester.tap(find.text('Plasma'));
    await tester.pump();
    expect(find.text('Unlock · 20 coins'), findsOneWidget);
  });
}
