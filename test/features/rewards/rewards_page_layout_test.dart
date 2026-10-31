import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/features/ads/data/ad_experiment_config.dart';
import 'package:Prism/features/ads/views/widgets/experimental_inline_ad.dart';
import 'package:Prism/features/badges/biz/bloc/badges_bloc.dart';
import 'package:Prism/features/badges/views/widgets/rewards_badges_section.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/daily_flow/views/daily_moment_today_card.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/views/widgets/drop_card.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/views/widgets/today_card.dart';
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:Prism/features/rewards/views/widgets/balance_card.dart';
import 'package:Prism/features/rewards/views/widgets/creator_progress_card.dart';
import 'package:Prism/features/rewards/views/widgets/freeze_card.dart';
import 'package:Prism/features/rewards/views/widgets/rank_progress_card.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_activity_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_collection_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_earn_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_hero.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_links_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_spend_section.dart';
import 'package:Prism/features/spin_wheel/views/widgets/spin_wheel_card.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
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
  final backend = CoinsTestBackend();
  setUp(() async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    await backend.install();
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

  Future<void> pumpPage(WidgetTester tester, {required bool enabled, bool showBack = false}) async {
    DailyMomentConfig.enabledOverride = enabled;
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RewardsPage(showBack: showBack),
      ),
    );
    await tester.pump();
  }

  testWidgets('daily moment places Today, Earn, Spend and More in order', (tester) async {
    await pumpPage(tester, enabled: true);
    final today = find.byType(DailyMomentTodayCard);
    final earn = find.byType(RewardsEarnSection);
    final spend = find.byType(RewardsSpendSection);
    final more = find.byKey(const ValueKey<String>('rewards-more'));
    expect(today, findsOneWidget);
    expect(earn, findsOneWidget);
    expect(spend, findsOneWidget);
    expect(more, findsOneWidget);
    expect(tester.getTopLeft(today).dy, lessThan(tester.getTopLeft(earn).dy));
    expect(tester.getTopLeft(earn).dy, lessThan(tester.getTopLeft(spend).dy));
    expect(tester.getTopLeft(spend).dy, lessThan(tester.getTopLeft(more).dy));
    expect(find.byType(RewardsHero), findsNothing);
    expect(find.byType(BalanceCard), findsNothing);
    expect(find.byType(CoinBalancePill), findsNothing);
    await tester.tap(more);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TodayCard), findsOneWidget);
    expect(find.text(AppLocalizationsEn().economyDailyStreak), findsOneWidget);
    expect(find.text(AppLocalizationsEn().economySpinTheWheel), findsOneWidget);
  });

  testWidgets('legacy layout keeps hero, quests and balance', (tester) async {
    await pumpPage(tester, enabled: false);
    expect(find.byType(RewardsHero), findsOneWidget);
    expect(find.byType(TodayCard), findsOneWidget);
    expect(find.byType(BalanceCard), findsOneWidget);
    expect(find.byType(CoinBalancePill), findsOneWidget);
    expect(find.byType(DailyMomentTodayCard), findsNothing);
    final sections = <Type>[
      RewardsHero,
      DropCard,
      RankProgressCard,
      CreatorProgressCard,
      TodayCard,
      SpinWheelCard,
      FreezeCard,
      BalanceCard,
      RewardsEarnSection,
      ExperimentalInlineAd,
      RewardsSpendSection,
      RewardsLinksSection,
      RewardsBadgesSection,
      RewardsCollectionSection,
      RewardsActivitySection,
    ];
    for (var index = 0; index < sections.length - 1; index++) {
      final before = find.byType(sections[index]);
      final after = find.byType(sections[index + 1]);
      expect(before, findsOneWidget);
      expect(after, findsOneWidget);
      expect(tester.getTopLeft(before).dy, lessThanOrEqualTo(tester.getTopLeft(after).dy));
    }
    expect(find.byKey(const ValueKey<String>('rewards-more')), findsNothing);
  });

  for (final enabled in <bool>[true, false]) {
    for (final showBack in <bool>[true, false]) {
      testWidgets('Rewards banner follows Earn with daily moment $enabled and pushed route $showBack', (tester) async {
        await pumpPage(tester, enabled: enabled, showBack: showBack);
        final slot = find.byType(ExperimentalInlineAd);
        expect(slot, findsOneWidget);
        final banner = tester.widget<ExperimentalInlineAd>(slot);
        expect(banner.format, AdExperimentFormat.banner);
        expect(banner.active, showBack);
        expect(banner.availableWidth, greaterThan(0));
        expect(banner.availableWidth, lessThanOrEqualTo(640));
        expect(tester.getBottomLeft(find.byType(RewardsEarnSection)).dy, tester.getTopLeft(slot).dy);
        expect(tester.getBottomLeft(slot).dy, tester.getTopLeft(find.byType(RewardsSpendSection)).dy);
      });
    }
  }
}
