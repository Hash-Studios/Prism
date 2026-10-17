import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/views/pages/auto_rotate_screen.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';

class _MockAutoRotateBloc extends MockBloc<AutoRotateEvent, AutoRotateState> implements AutoRotateBloc {}

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState>
    implements FavouriteWallsBloc {}

class _MockSessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  late _MockAutoRotateBloc autoRotateBloc;
  late _MockFavouriteWallsBloc favouriteWallsBloc;
  late _MockSessionBloc sessionBloc;
  late List<(String, Map<String, dynamic>)> calls;

  setUpAll(() {
    registerFallbackValue(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: false));
  });

  setUp(() async {
    await backend.install();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    calls = <(String, Map<String, dynamic>)>[];
    backend.onCall = (String name, Map<String, dynamic> params) async {
      calls.add((name, params));
      return <String, Object?>{
        'success': true,
        'changed': true,
        'previousBalance': 100,
        'currentBalance': 50,
        'delta': -50,
        'reason': 'ok',
        'passUntil': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
      };
    };
    CoinsService.instance.balanceNotifier.value = 100;
    autoRotateBloc = _MockAutoRotateBloc();
    favouriteWallsBloc = _MockFavouriteWallsBloc();
    sessionBloc = _MockSessionBloc();
    when(
      () => favouriteWallsBloc.state,
    ).thenReturn(FavouriteWallsState.initial().copyWith(status: LoadStatus.success, userId: backend.userId));
    when(() => sessionBloc.state).thenReturn(
      SessionState(
        status: LoadStatus.success,
        session: SessionEntity(userId: backend.userId, loggedIn: true, premium: false, subscriptionTier: 'free'),
      ),
    );
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial().copyWith(loaded: true, isPro: false));
    getIt.registerFactory<AutoRotateBloc>(() => autoRotateBloc);
  });

  tearDown(() async {
    CoinsService.instance.passesNotifier.value = Passes.empty;
    app_state.prismUser = app_constants.createGuestPrismUser();
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AutoRotateBloc>.value(value: autoRotateBloc),
            BlocProvider<FavouriteWallsBloc>.value(value: favouriteWallsBloc),
            BlocProvider<SessionBloc>.value(value: sessionBloc),
          ],
          child: const AutoRotateScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a locked user sees the 7-day pass and Prism Pro', (tester) async {
    await pumpScreen(tester);

    expect(find.text('7-day pass · 50 coins'), findsOneWidget);
    expect(find.text('See Prism Pro'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('buying the pass spends autoRotatePass7d and unlocks the bloc', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('7-day pass · 50 coins'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(calls.single.$1, 'spendCoins');
    expect(calls.single.$2['action'], 'autoRotatePass7d');
    expect(calls.single.$2['sourceTag'], 'auto_rotate.pass');
    expect(CoinsService.instance.autoRotateUnlocked, isTrue);
    verify(() => autoRotateBloc.add(AutoRotateEvent.entitlementChanged(isPro: true, userId: backend.userId))).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('an active pass starts the bloc as unlocked and shows when it ends', (tester) async {
    CoinsService.instance.passesNotifier.value = Passes(
      autoRotatePassUntil: DateTime.now().add(const Duration(days: 3)),
    );
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial().copyWith(loaded: true, isPro: true));
    await pumpScreen(tester);

    verify(() => autoRotateBloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: true))).called(1);
    expect(find.textContaining('Pass active until'), findsOneWidget);
    expect(find.text('7-day pass · 50 coins'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
