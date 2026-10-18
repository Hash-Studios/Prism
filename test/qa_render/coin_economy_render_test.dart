@Tags(<String>['qa_render'])
library;

import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/views/widgets/coin_gate_sheet.dart';
import 'package:Prism/features/badges/biz/bloc/badges_bloc.dart';
import 'package:Prism/features/draw/biz/bloc/draw_bloc.j.dart';
import 'package:Prism/features/draw/domain/entities/draw_entity.dart';
import 'package:Prism/features/draw/views/pages/draw_page.dart';
import 'package:Prism/features/drops/drops.dart';
import 'package:Prism/features/leaderboard/biz/bloc/leaderboard_bloc.j.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:Prism/features/leaderboard/views/pages/leaderboard_page.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/quests/quests.dart';
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:Prism/features/shop/biz/bloc/shop_bloc.j.dart';
import 'package:Prism/features/shop/shop.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/views/widgets/trending_strip.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/boost_wall_row.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/drops/drop_fixtures.dart';
import '../features/quests/fake_quests_repository.dart';
import '../support/coins_test_backend.dart';
import '../support/fake_app_analytics.dart';
import '../support/fake_user_block_repository.dart';
import '../support/profile_user_fixture.dart';
import 'qa_harness.dart';

class _MockBadgesBloc extends MockBloc<BadgesEvent, BadgesState> implements BadgesBloc {}

class _MockDropsBloc extends MockBloc<DropsEvent, DropsState> implements DropsBloc {}

class _MockShopBloc extends MockBloc<StreakShopEvent, StreakShopState> implements StreakShopBloc {}

QuestState twoOfThreeDone() => questState(
  items: <QuestItem>[
    questItem('set_wall', QuestEvent.setWallpaper, claimed: true, progress: 1),
    questItem('fav_3', QuestEvent.favourite, target: 3, claimed: true, progress: 3),
    questItem('wotd_view', QuestEvent.viewWotd),
  ],
  bonus: questItem('watch_ad', QuestEvent.watchAd, claimed: true, progress: 1),
);

QuestState allDone({bool chestOpened = false, bool chestDoubled = false}) => questState(
  items: <QuestItem>[
    questItem('set_wall', QuestEvent.setWallpaper, claimed: true, progress: 1),
    questItem('fav_3', QuestEvent.favourite, target: 3, claimed: true, progress: 3),
    questItem('wotd_view', QuestEvent.viewWotd, claimed: true, progress: 1),
  ],
  bonus: questItem('watch_ad', QuestEvent.watchAd, claimed: chestDoubled, progress: chestDoubled ? 1 : 0),
  chestOpened: chestOpened,
  chestDoubled: chestDoubled,
);

void registerRewardsDeps({QuestState? quests, DropsState? drops}) {
  getIt.registerFactory<StreakShopBloc>(() {
    final _MockShopBloc shop = _MockShopBloc();
    whenListen(shop, const Stream<StreakShopState>.empty(), initialState: const StreakShopState());
    return shop;
  });
  getIt.registerFactory<BadgesBloc>(() {
    final _MockBadgesBloc badges = _MockBadgesBloc();
    whenListen(badges, const Stream<BadgesState>.empty(), initialState: const BadgesState());
    return badges;
  });
  getIt.registerFactory<QuestsBloc>(() => QuestsBloc(FakeQuestsRepository(quests: quests ?? twoOfThreeDone())));
  getIt.registerFactory<DropsBloc>(() {
    final _MockDropsBloc bloc = _MockDropsBloc();
    whenListen(bloc, const Stream<DropsState>.empty(), initialState: drops ?? DropsState.initial());
    return bloc;
  });
  getIt.registerSingleton<FirestoreClient>(CoinsTestFirestore());
}

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

class _MockLeaderboardBloc extends MockBloc<LeaderboardEvent, LeaderboardState> implements LeaderboardBloc {}

class _MockDrawBloc extends MockBloc<DrawEvent, DrawState> implements DrawBloc {}

class _MockProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _MockTrendingBloc extends MockBloc<TrendingEvent, TrendingState> implements TrendingBloc {}

class _ProfileRepository implements PublicProfileRepository {
  final StreamController<PublicProfileEntity?> profiles = StreamController<PublicProfileEntity?>.broadcast();

  @override
  Stream<PublicProfileEntity?> watchProfile(String identifier) => profiles.stream;

  @override
  Future<void> clearForUser(String userId) async {}

  @override
  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> fetchWalls({
    required String email,
    required bool refresh,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> follow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> unfollow({
    required String currentUserId,
    required String currentUserEmail,
    required String targetUserId,
    required String targetUserEmail,
  }) => throw UnimplementedError();

  @override
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> fetchUserSummariesPage({
    required List<String> allEmails,
    required int page,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<UserSummaryEntity>>> searchUsersByUsername({
    required String query,
    required List<String> scopeEmails,
  }) => throw UnimplementedError();
}

void registerShopBloc() {
  getIt.registerFactory<ShopBloc>(() => ShopBloc(getIt<SettingsLocalDataSource>()));
}

PrismWallpaper _wall(String id, {String? email, DateTime? boostedUntil, String by = 'Ana'}) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: 'https://example.test/$id.jpg',
    thumbnailUrl: 'https://example.test/$id-thumb.jpg',
    authorName: by,
    authorEmail: email,
  ),
  review: true,
  boostedUntil: boostedUntil,
);

DropsState _loadedDrop({Map<String, DropUnlock> unlocked = const <String, DropUnlock>{}}) => DropsState(
  status: LoadStatus.success,
  now: DateTime.now(),
  drop: dropEntity(wallIds: const <String>['A', 'B', 'C', 'D', 'E', 'F']),
  unlocked: unlocked,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(WallpaperDetailRoute());
    registerFallbackValue(const DropsEvent.started());
    registerFallbackValue(const LeaderboardEvent.started());
    registerFallbackValue(const DrawEvent.started());
    registerFallbackValue(const ThemeEvent.started());
  });
  setUpAll(loadFonts);

  group('qa render', () {
    // 1. Rewards
    for (final bool pro in <bool>[false, true]) {
      qaScreen(pro ? 'rewards_pro' : 'rewards', pro: pro, setUpExtra: registerRewardsDeps, (QaShot shot) async {
        await shot.pump(const RewardsPage(showBack: false));
        await shot.save(pro ? 'rewards_pro' : 'rewards');
      });
    }

    // 2. Rewards, Use your coins grid
    qaScreen('rewards_spend', setUpExtra: registerRewardsDeps, (QaShot shot) async {
      await shot.pump(const RewardsPage(showBack: false));
      final Finder spend = find.text('Use your coins');
      await shot.tester.scrollUntilVisible(spend, 300, scrollable: find.byType(Scrollable).first);
      await shot.settle(frames: 2);
      await Scrollable.ensureVisible(shot.tester.element(spend), alignment: 0.02);
      await shot.settle(frames: 2);
      await shot.save('rewards_spend');
    });

    // 3. Today card in four states
    qaScreen(
      'today_card_states',
      height: 3200,
      setUpExtra: () {
        final List<QuestState> states = <QuestState>[
          questState(),
          allDone(),
          allDone(chestOpened: true),
          allDone(chestOpened: true, chestDoubled: true),
        ];
        int next = 0;
        getIt.registerFactory<QuestsBloc>(() => QuestsBloc(FakeQuestsRepository(quests: states[next++ % 4])));
      },
      (QaShot shot) async {
        await shot.pump(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(PrismSpace.page),
              child: Builder(
                builder: (BuildContext context) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Locked', style: PrismTextStyles.caption(context)),
                    const SizedBox(height: PrismSpace.xxs),
                    const TodayCard(),
                    Text('Ready', style: PrismTextStyles.caption(context)),
                    const SizedBox(height: PrismSpace.xxs),
                    const TodayCard(),
                    Text('Opened', style: PrismTextStyles.caption(context)),
                    const SizedBox(height: PrismSpace.xxs),
                    const TodayCard(),
                    Text('Doubled', style: PrismTextStyles.caption(context)),
                    const SizedBox(height: PrismSpace.xxs),
                    const TodayCard(),
                  ],
                ),
              ),
            ),
          ),
        );
        await shot.save('today_card_states');
      },
    );

    // 4. Chest sheet
    qaScreen('chest_sheet', (QaShot shot) async {
      await shot.pump(
        Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () =>
                  showChestSheet(context, const ChestResult(ChestOutcome.opened, coins: 12, itemId: 'frame_ring')),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await shot.tester.tap(find.text('open'));
      await shot.settle(frames: 8);
      await shot.save('chest_sheet');
    });

    // 5. Shop
    qaScreen('shop_frames', setUpExtra: registerShopBloc, (QaShot shot) async {
      await shot.pump(const ShopPage());
      await shot.tester.tap(find.text('Frames'));
      await shot.settle();
      await shot.save('shop_frames');
    });

    qaScreen('shop_item_sheet', setUpExtra: registerShopBloc, (QaShot shot) async {
      CoinsService.instance.balanceNotifier.value = 140;
      await shot.pump(const ShopPage());
      await shot.tester.tap(find.text('Frames'));
      await shot.settle();
      await shot.tester.tap(find.text('Aurora'));
      await shot.settle(frames: 8);
      await shot.save('shop_item_sheet');
    });

    qaScreen('shop_icons', setUpExtra: registerShopBloc, (QaShot shot) async {
      await shot.pump(const ShopPage());
      await shot.tester.tap(find.text('Icons'));
      await shot.settle();
      await shot.save('shop_icons');
    });

    qaScreen('shop_icon_sheet', setUpExtra: registerShopBloc, (QaShot shot) async {
      CoinsService.instance.balanceNotifier.value = 340;
      await shot.pump(const ShopPage());
      await shot.tester.tap(find.text('Icons'));
      await shot.settle();
      await shot.tester.tap(find.text('Sunset'));
      await shot.settle(frames: 12);
      await shot.save('shop_icon_sheet');
    });

    // 6. Theme picker with locked chips
    qaScreen(
      'theme_picker_locked',
      height: 1600,
      setUpExtra: () {
        registerShopBloc();
        CoinsService.instance.inventoryNotifier.value = Inventory.empty;
      },
      (QaShot shot) async {
        final _MockThemeBloc themeBloc = _MockThemeBloc();
        whenListen(
          themeBloc,
          const Stream<ThemeState>.empty(),
          initialState: ThemeState.initial().copyWith(mode: ThemeMode.system),
        );
        await shot.pump(BlocProvider<ThemeBloc>.value(value: themeBloc, child: const ThemeView()));
        await shot.save('theme_picker_locked');
      },
    );

    // 7. Drops
    final Map<String, DropUnlock> unlocked = <String, DropUnlock>{
      'A': const DropUnlock(wallId: 'A', weekKey: '2026-W42', url: 'https://example.test/A-full.jpg'),
      'C': const DropUnlock(wallId: 'C', weekKey: '2026-W42', url: 'https://example.test/C-full.jpg'),
    };
    DropsBloc dropsBloc() {
      final _MockDropsBloc bloc = _MockDropsBloc();
      whenListen(bloc, const Stream<DropsState>.empty(), initialState: _loadedDrop(unlocked: unlocked));
      return bloc;
    }

    qaScreen('drops_live', height: 1250, setUpExtra: () => getIt.registerFactory<DropsBloc>(dropsBloc), (
      QaShot shot,
    ) async {
      await shot.pump(const DropsPage());
      await shot.save('drops_live');
    });

    qaScreen('drop_unlock_sheet', setUpExtra: () => getIt.registerFactory<DropsBloc>(dropsBloc), (QaShot shot) async {
      await shot.pump(const DropsPage());
      await shot.tester.tap(find.byType(PrismWallTile).at(1));
      await shot.settle(frames: 8);
      await shot.save('drop_unlock_sheet');
    });

    // 8. Public profile
    for (final bool gift in <bool>[false, true]) {
      qaScreen(
        gift ? 'profile_gift_sheet' : 'profile_cosmetics',
        setUpExtra: () {
          final _MockProfileBloc bloc = _MockProfileBloc();
          whenListen(
            bloc,
            const Stream<PublicProfileState>.empty(),
            initialState: PublicProfileState.initial().copyWith(email: 'ana@example.com', status: LoadStatus.success),
          );
          getIt
            ..registerFactory<PublicProfileBloc>(() => bloc)
            ..registerSingleton<PublicProfileRepository>(_ProfileRepository())
            ..registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending());
          AnalyticsRuntime.instance = FakeAppAnalytics();
          app_state.prismUser = profileUser(id: 'me', username: 'creator_01', bio: 'Hello')..name = 'Me Myself';
        },
        (QaShot shot) async {
          addTearDown(AnalyticsRuntime.reset);
          await shot.pump(const ProfileScreen(profileIdentifier: 'ana@example.com'));
          (getIt<PublicProfileRepository>() as _ProfileRepository).profiles.add(
            const PublicProfileEntity(
              id: 'u2',
              name: 'Ana Rivera',
              email: 'ana@example.com',
              username: 'ana_rivera',
              profilePhoto: '',
              bio: 'Makes calm gradients.',
              followers: <String>['a', 'b', 'c'],
              following: <String>['d'],
              links: <String, String>{},
              coverPhoto: '',
              frameId: 'frame_aurora',
              nameGlowId: 'glow_ember',
              xp: 2500,
            ),
          );
          await shot.settle();
          if (gift) {
            await shot.tester.tap(find.byTooltip('Gift a 24 h pass'));
            await shot.settle(frames: 8);
          }
          await shot.save(gift ? 'profile_gift_sheet' : 'profile_cosmetics');
        },
      );
    }

    // 9. Leaderboard and Draw
    qaScreen('leaderboard_global', (QaShot shot) async {
      const List<(String, int, String)> rows = <(String, int, String)>[
        ('Ana Rivera', 4820, 'prism'),
        ('Kenji Mori', 3310, 'gold'),
        ('Sofia Lund', 2760, 'gold'),
        ('Me', 1240, 'silver'),
        ('Dev Patel', 980, 'silver'),
        ('Lea Novak', 640, 'silver'),
        ('Tom Hale', 310, 'bronze'),
        ('Ines Duarte', 120, 'bronze'),
      ];
      final _MockLeaderboardBloc bloc = _MockLeaderboardBloc();
      whenListen(
        bloc,
        const Stream<LeaderboardState>.empty(),
        initialState: LeaderboardState.initial().copyWith(
          tab: LeaderboardTab.global,
          friendsStatus: LoadStatus.success,
          globalStatus: LoadStatus.success,
          global: <LeaderboardEntry>[
            for (final (String name, int xp, String rank) in rows)
              LeaderboardEntry(
                uid: name,
                name: name,
                username: name.toLowerCase().replaceAll(' ', '_'),
                photo: '',
                xp: xp,
                rank: rank,
                isMe: name == 'Me',
              ),
          ],
        ),
      );
      AnalyticsRuntime.instance = FakeAppAnalytics();
      addTearDown(AnalyticsRuntime.reset);
      await shot.pump(BlocProvider<LeaderboardBloc>.value(value: bloc, child: const LeaderboardPage()));
      await shot.save('leaderboard_global');
    });

    DrawState drawState() => DrawState.initial().copyWith(
      status: LoadStatus.success,
      draw: DrawEntity(
        weekKey: '2026-W42',
        status: 'open',
        closesAt: DateTime.now().add(const Duration(days: 2, hours: 3, minutes: 30)),
        tickets: 24,
        participants: 9,
        prizeProMonths: 1,
        prizeItemId: 'frame_prism',
      ),
      myTickets: 2,
    );

    qaScreen('draw_page', (QaShot shot) async {
      EconomyConfig.current = const EconomyConfig(flags: EconomyFlags(drawEnabled: true));
      final _MockDrawBloc bloc = _MockDrawBloc();
      whenListen(bloc, const Stream<DrawState>.empty(), initialState: drawState());
      await shot.pump(BlocProvider<DrawBloc>.value(value: bloc, child: const DrawPage()));
      await shot.save('draw_page');
    });

    qaScreen('draw_disabled', (QaShot shot) async {
      final _MockDrawBloc bloc = _MockDrawBloc();
      whenListen(bloc, const Stream<DrawState>.empty(), initialState: drawState());
      await shot.pump(BlocProvider<DrawBloc>.value(value: bloc, child: const DrawPage()));
      await shot.save('draw_disabled');
    });

    // 10. Boost row and boosted trending tile
    qaScreen('wall_detail_boost', height: 260, (QaShot shot) async {
      app_state.prismUser.email = 'owner@example.com';
      Widget row(PrismWallpaper wall) => Padding(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.sm),
        child: PrismGroup(children: <Widget>[BoostWallRow(wall: wall)]),
      );
      await shot.pump(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                row(_wall('W1', email: 'owner@example.com')),
                row(
                  _wall('W2', email: 'owner@example.com', boostedUntil: DateTime.now().add(const Duration(hours: 5))),
                ),
              ],
            ),
          ),
        ),
      );
      await shot.save('wall_detail_boost');
    });

    qaScreen('trending_boosted', height: 380, (QaShot shot) async {
      final _MockTrendingBloc bloc = _MockTrendingBloc();
      whenListen(
        bloc,
        const Stream<TrendingState>.empty(),
        initialState: TrendingState.initial().copyWith(
          week: TrendingSection(
            status: LoadStatus.success,
            walls: <PrismWallpaper>[
              _wall('t1', boostedUntil: DateTime.now().add(const Duration(hours: 3))),
              for (final (int i, String by) in <String>['Kenji', 'Sofia', 'Dev', 'Lea'].indexed)
                _wall('t${i + 2}', by: by),
            ],
          ),
        ),
      );
      await shot.pump(
        Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: PrismSpace.xxl),
              child: BlocProvider<TrendingBloc>.value(value: bloc, child: const TrendingStrip()),
            ),
          ),
        ),
      );
      await shot.save('trending_boosted');
    });

    // 11. Coin gate, short balance
    qaScreen('coin_gate_short', (QaShot shot) async {
      CoinsService.instance.balanceNotifier.value = 5;
      await shot.pump(
        Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showCoinGateSheet<String>(
                context,
                title: 'Not enough coins',
                cost: CoinPolicy.wallpaperDownload,
                message: (int missing) => 'You need $missing more coins to save this wallpaper.',
                options: <CoinGateOption<String>>[
                  CoinGateOption(label: watchAdOptionLabel(), value: 'watch'),
                  const CoinGateOption(label: 'Upgrade to Pro', value: 'upgrade', outlined: true),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await shot.tester.tap(find.text('open'));
      await shot.settle(frames: 8);
      await shot.save('coin_gate_short');
    });
  });
}
