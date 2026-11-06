import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/features/ads/data/ad_experiment_config.dart';
import 'package:Prism/features/ads/views/widgets/experimental_inline_ad.dart';
import 'package:Prism/features/badges/biz/bloc/badges_bloc.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
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
    tester.view.physicalSize = const Size(1000, 4400);
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

  test('badge progress mirrors the server thresholds and clamps at the target', () {
    BadgeProgress? of(String id, {int streak = 0, int following = 0}) =>
        badgeProgressFor(id, streakBest: streak, following: following, profileSteps: 3, profileStepsTotal: 4);
    expect(of('week_warrior', streak: 3), (done: 3, target: 7));
    expect(of('week_warrior', streak: 12), (done: 7, target: 7));
    expect(of('streak_master', streak: 12), (done: 12, target: 28));
    expect(of('social_butterfly', following: 6), (done: 6, target: 10));
    expect(of('profile_complete'), (done: 3, target: 4));
    // No local count: no bar.
    expect(of('ai_artist'), isNull);
    expect(of('challenge_winner'), isNull);
  });

  testWidgets('the closest badge leads with its progress, then earned, then the rest by progress', (tester) async {
    final BadgeInfo last = badgeCatalog.last;
    await getIt.unregister<BadgesBloc>();
    getIt.registerFactory<BadgesBloc>(() {
      final bloc = _BadgesBloc();
      whenListen(bloc, const Stream<BadgesState>.empty(), initialState: BadgesState(earnedIds: <String>[last.id]));
      return bloc;
    });
    app_state.prismUser = app_constants.createGuestPrismUser()..following = List<String>.generate(6, (i) => 'u$i');
    CoinsService.instance.streakNotifier.value = CoinsService.instance.streakNotifier.value.copyWith(count: 3);
    addTearDown(() => CoinsService.instance.streakNotifier.value = StreakStatus.empty);
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: RewardsBadgesSection())),
      ),
    );
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    double top(String id) => tester.getTopLeft(find.text(badgeInfo(id)!.name(l10n))).dy;
    double left(String id) => tester.getTopLeft(find.text(badgeInfo(id)!.name(l10n))).dx;
    // Social Butterfly (6/10) is closest, so it leads; the earned badge comes next, then Week Warrior (3/7).
    expect(top('social_butterfly'), lessThan(top(last.id)));
    expect(top(last.id), moreOrLessEquals(top('week_warrior')));
    expect(left(last.id), lessThan(left('week_warrior')));
    expect(top('week_warrior'), lessThan(top('streak_master')));
    // Streak Master (3/28) still has progress, so it comes before the badges with no local count.
    expect(top('streak_master'), moreOrLessEquals(top('challenge_winner')));
    expect(left('streak_master'), lessThan(left('challenge_winner')));
    expect(top('streak_master'), lessThan(top('ai_artist')));
    expect(find.text('6/10'), findsOneWidget);
    expect(find.text('3/7'), findsOneWidget);
    expect(find.text('3/28'), findsOneWidget);
    // The state shows in the glyph ink and the bar, not a lock.
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
  });

  testWidgets('daily moment places Today, Earn, Spend and More in order', (tester) async {
    await pumpPage(tester, enabled: true);
    final today = find.byType(DailyMomentTodayCard);
    final earn = find.byType(RewardsEarnSection);
    final spend = find.byType(RewardsSpendSection);
    final more = find.byKey(const ValueKey<String>('rewards-more'));
    final moreRows = find.text(AppLocalizationsEn().economySpinTheWheel);
    expect(today, findsOneWidget);
    expect(earn, findsOneWidget);
    expect(spend, findsOneWidget);
    expect(more, findsOneWidget);
    expect(tester.getTopLeft(today).dy, lessThan(tester.getTopLeft(earn).dy));
    expect(tester.getTopLeft(earn).dy, lessThan(tester.getTopLeft(spend).dy));
    expect(tester.getTopLeft(spend).dy, lessThan(tester.getTopLeft(more).dy));
    // Quests lead the lower half, before More and the rank card.
    expect(tester.getTopLeft(spend).dy, lessThan(tester.getTopLeft(find.byType(TodayCard)).dy));
    // The mocked quest board is empty, so the quests block has no height here.
    expect(tester.getTopLeft(find.byType(TodayCard)).dy, lessThanOrEqualTo(tester.getTopLeft(more).dy));
    expect(tester.getTopLeft(more).dy, lessThan(tester.getTopLeft(find.byType(RankProgressCard)).dy));
    expect(find.byType(RewardsHero), findsNothing);
    expect(find.byType(BalanceCard), findsNothing);
    expect(find.byType(CoinBalancePill), findsNothing);
    expect(moreRows, findsOneWidget);
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
