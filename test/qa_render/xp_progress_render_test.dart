@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/rewards/domain/rank_progress.dart';
import 'package:Prism/features/rewards/views/widgets/rank_progress_card.dart';
import 'package:Prism/features/shop/biz/bloc/shop_bloc.j.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_user_block_repository.dart';
import '../support/profile_user_fixture.dart';
import 'qa_harness.dart';

class _MockProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _MockProfileRepository extends Mock implements PublicProfileRepository {}

void main() {
  setUpAll(() async {
    registerFallbackValue(const ShopRoute());
    if (qaRender) await loadFonts();
  });

  for (final (String name, int xp, Set<String> owned) in <(String, int, Set<String>)>[
    ('xp_bronze', 220, <String>{}),
    ('xp_silver_syncing', 500, <String>{}),
    ('xp_gold', 2500, <String>{'glow_aurora', 'frame_gold'}),
    ('xp_prism', 6500, <String>{'glow_aurora', 'frame_gold', 'glow_prism'}),
  ]) {
    qaScreen(name, (QaShot shot) async {
      await shot.pump(
        Scaffold(
          appBar: AppBar(title: const Text('Your progress')),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: XpProgressCard(
                progress: RankProgress(xp: xp, owned: owned, config: EconomyConfig.defaults),
                onOpenShop: () {},
                onUseReward: (_) {},
              ),
            ),
          ),
        ),
      );
      await shot.save(name);
    });
  }

  qaScreen('xp_explanation', (QaShot shot) async {
    await shot.pump(
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: XpProgressCard(
            progress: RankProgress(xp: 1240, owned: <String>{'glow_aurora'}, config: EconomyConfig.defaults),
          ),
        ),
      ),
    );
    await shot.tester.tap(find.byTooltip('How XP and rank rewards work'));
    await shot.settle();
    await shot.save('xp_explanation');
    await shot.tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -600));
    await shot.settle();
    await shot.save('xp_explanation_bottom');
  });

  qaScreen('xp_large_text', (QaShot shot) async {
    shot.tester.view.physicalSize = const Size(960, 2400);
    await shot.pump(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: XpProgressCard(
                  progress: RankProgress(xp: 1999, owned: <String>{'glow_aurora'}, config: EconomyConfig.defaults),
                  onUseReward: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await shot.save('xp_large_text');
  });

  qaScreen(
    'own_profile_xp',
    setUpExtra: () {
      final _MockProfileBloc bloc = _MockProfileBloc();
      whenListen(
        bloc,
        const Stream<PublicProfileState>.empty(),
        initialState: PublicProfileState.initial().copyWith(email: 'user@example.com', status: LoadStatus.success),
      );
      final _MockProfileRepository repository = _MockProfileRepository();
      when(() => repository.watchProfile(any())).thenAnswer((_) => const Stream<PublicProfileEntity?>.empty());
      getIt
        ..registerFactory<PublicProfileBloc>(() => bloc)
        ..registerFactory<ShopBloc>(() => ShopBloc(getIt<SettingsLocalDataSource>()))
        ..registerSingleton<PublicProfileRepository>(repository)
        ..registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending());
      AnalyticsRuntime.instance = FakeAppAnalytics();
      app_state.prismUser = profileUser(
        id: 'me',
        username: 'creator_01',
        bio: 'Finding colour in everyday places.',
        profilePhoto: '',
      )..name = 'Me Myself';
      CoinsService.instance.inventoryNotifier.value = const Inventory(
        owned: <String>{'glow_aurora', 'frame_ring'},
        frame: 'frame_ring',
      );
    },
    (QaShot shot) async {
      addTearDown(AnalyticsRuntime.reset);
      await shot.pump(const ProfileScreen());
      await shot.save('own_profile_xp');
      await shot.tester.tap(find.text('Use Aurora name glow'));
      await shot.settle();
      expect(find.text('Equip'), findsOneWidget);
      await shot.save('own_profile_reward_sheet');
    },
  );
}
