import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/badges/biz/bloc/badges_bloc.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/promo_codes/views/redeem_code_sheet.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/favourite_test_scope.dart';

class _BadgesBloc extends MockBloc<BadgesEvent, BadgesState> implements BadgesBloc {}

class _DropsBloc extends MockBloc<DropsEvent, DropsState> implements DropsBloc {}

class _QuestsBloc extends MockBloc<QuestsEvent, QuestsState> implements QuestsBloc {}

class _ShopBloc extends MockBloc<StreakShopEvent, StreakShopState> implements StreakShopBloc {}

void main() {
  setUpFavouriteCounts();
  setUp(() async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    DailyMomentConfig.enabledOverride = true;
    await CoinsTestBackend().install();
    getIt.registerSingleton<FirestoreClient>(CoinsTestFirestore());
    getIt.registerFactory<BadgesBloc>(() {
      final bloc = _BadgesBloc();
      whenListen(bloc, const Stream<BadgesState>.empty(), initialState: const BadgesState());
      return bloc;
    });
    getIt.registerFactory<DropsBloc>(() {
      final bloc = _DropsBloc();
      whenListen(bloc, const Stream<DropsState>.empty(), initialState: DropsState.initial());
      return bloc;
    });
    getIt.registerFactory<QuestsBloc>(() {
      final bloc = _QuestsBloc();
      whenListen(bloc, const Stream<QuestsState>.empty(), initialState: const QuestsState());
      return bloc;
    });
    getIt.registerFactory<StreakShopBloc>(() {
      final bloc = _ShopBloc();
      whenListen(bloc, const Stream<StreakShopState>.empty(), initialState: const StreakShopState());
      return bloc;
    });
  });
  tearDown(() async {
    DailyMomentConfig.enabledOverride = null;
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> frame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<({ValueNotifier<String?> code, GlobalKey<NavigatorState> navigator})> openPage(WidgetTester tester) async {
    final code = ValueNotifier<String?>('ABCDEFGH23');
    addTearDown(code.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueListenableBuilder<String?>(
          valueListenable: code,
          builder: (_, value, _) => RewardsPage(redeemCode: value),
        ),
      ),
    );
    await frame(tester);
    return (code: code, navigator: navigator);
  }

  String fieldCode(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('a new link updates an existing Rewards page and opens its code after the old sheet closes', (
    tester,
  ) async {
    final page = await openPage(tester);
    final state = tester.state(find.byType(RewardsPage));
    expect(fieldCode(tester), 'ABCDEFGH23');
    page.navigator.currentState!.pop();
    await frame(tester);

    page.code.value = 'JKLMNPQR45';
    await frame(tester);
    await frame(tester);

    expect(tester.state(find.byType(RewardsPage)), same(state));
    expect(find.byType(EditableText), findsOneWidget);
    expect(fieldCode(tester), 'JKLMNPQR45');
    expect(find.byType(RedeemCodeBody, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a link received with a sheet open waits instead of stacking another sheet', (tester) async {
    final page = await openPage(tester);

    page.code.value = 'JKLMNPQR45';
    await frame(tester);
    await frame(tester);

    expect(find.byType(RedeemCodeBody, skipOffstage: false), findsOneWidget);
    expect(fieldCode(tester), 'ABCDEFGH23');
    page.navigator.currentState!.pop();
    await frame(tester);
    await frame(tester);
    expect(find.byType(RedeemCodeBody, skipOffstage: false), findsOneWidget);
    expect(fieldCode(tester), 'JKLMNPQR45');

    page.navigator.currentState!.pop();
    await frame(tester);
    page.code.value = null;
    await frame(tester);
    expect(find.byType(RedeemCodeBody, skipOffstage: false), findsNothing);
  });
}
