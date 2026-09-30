import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_activity_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_collection_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_earn_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_spend_section.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/coins_test_backend.dart';

class _MockShopBloc extends MockBloc<StreakShopEvent, StreakShopState> implements StreakShopBloc {}

PrismWallpaper _wall(String id, {int? days, int? cost}) => PrismWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  requiredStreakDays: days,
  streakShopCoinCost: cost,
);

Widget _host(Widget child, Brightness brightness) => MaterialApp(
  theme: ThemeData(brightness: brightness, useMaterial3: true),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    CoinsService.instance.streakNotifier.value = StreakStatus.empty;
    CoinsService.instance.balanceNotifier.value = 0;
    CoinsService.instance.earnFlagsNotifier.value = CoinEarnFlags.empty;
    await getIt.reset();
  });

  testWidgets('activity refreshes fresh transactions after a balance mutation', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    final firestore = CoinsTestFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    await tester.pumpWidget(_host(const RewardsActivitySection(), Brightness.light));
    await tester.pump();
    expect(find.text('No coin activity yet.'), findsOneWidget);
    firestore.transactions = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'freeze-1',
        'userId': 'user-1',
        'action': 'streakFreeze',
        'delta': -50,
        'createdAt': DateTime.now(),
      },
    ];
    CoinsService.instance.balanceNotifier.value = 50;
    await tester.pump();
    await tester.pump();
    expect(find.text('Streak freeze'), findsOneWidget);
    expect(firestore.dedupeWindowMs, 0);
  });

  testWidgets('activity shows 8 rows, then more after Show more', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    final firestore = CoinsTestFirestore();
    firestore.transactions = <Map<String, dynamic>>[
      for (int i = 0; i < 12; i++)
        <String, dynamic>{
          'id': 'tx-$i',
          'userId': 'user-1',
          'action': 'streakFreeze',
          'delta': -50,
          'createdAt': DateTime.now(),
        },
    ];
    getIt.registerSingleton<FirestoreClient>(firestore);
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(const RewardsActivitySection(), Brightness.dark));
    await tester.pump();
    await tester.pump();
    expect(find.text('-50'), findsNWidgets(8));
    await tester.tap(find.text('Show more'));
    await tester.pump();
    expect(find.text('-50'), findsNWidgets(12));
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('PrismTextStyles titles are not the legacy dark grey on a dark theme', (tester) async {
    late TextStyle style;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Builder(
          builder: (context) {
            style = PrismTextStyles.cardTitle(context);
            return Text('Streak freeze', style: style);
          },
        ),
      ),
    );
    expect(style.color, isNot(const Color(0xFF2F2F2F)));
    expect(style.color!.computeLuminance(), greaterThan(0.5));
  });

  testWidgets('coin activity credit follows the active tertiary color', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    const Color tertiary = Color(0xFF7744AA);
    final ThemeData theme = ThemeData.light().copyWith(
      colorScheme: ThemeData.light().colorScheme.copyWith(tertiary: tertiary),
    );
    final firestore = CoinsTestFirestore()
      ..transactions = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'credit-1',
          'userId': 'user-1',
          'action': 'dailyStreak',
          'delta': 10,
          'createdAt': DateTime.now(),
        },
      ];
    getIt.registerSingleton<FirestoreClient>(firestore);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: RewardsActivitySection()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.widget<Text>(find.text('+10')).style?.color, tertiary);
  });

  for (final Brightness brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      testWidgets('spend section shows prices from CoinPolicy and runs the freeze callback', (tester) async {
        int freezeTaps = 0;
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_host(RewardsSpendSection(onStreakFreeze: () => freezeTaps++), brightness));

        expect(find.text('Use your coins'), findsOneWidget);
        expect(find.text('from ${CoinPolicy.aiGenerationFast}'), findsOneWidget);
        expect(find.text('${CoinPolicy.premiumWallpaperDownload}'), findsOneWidget);
        expect(find.text('${CoinPolicy.premiumFilter} per edit'), findsOneWidget);

        await tester.tap(find.text('Streak freeze'));
        expect(freezeTaps, 1);

        await tester.tap(find.text('Downloads'));
        await tester.pumpAndSettle();
        expect(find.text('See Pro'), findsOneWidget);
      });

      testWidgets('earn section lists every way to earn', (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_host(const RewardsEarnSection(), brightness));

        expect(find.text('Earn coins'), findsOneWidget);
        expect(find.text('Daily streak'), findsOneWidget);
        expect(find.text('Watch a video'), findsOneWidget);
        expect(find.text('Invite a friend'), findsOneWidget);
        expect(find.text('First upload'), findsOneWidget);
        expect(find.text('Complete your profile'), findsOneWidget);
        expect(find.text('+${CoinPolicy.streakDay1To2Daily} to +${CoinPolicy.streakDay7Daily}'), findsOneWidget);
      });

      testWidgets('earn section shows Done for rewarded one-time earns', (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_host(const RewardsEarnSection(), brightness));
        expect(find.text('Done'), findsNothing);
        expect(find.byIcon(Icons.check_rounded), findsNothing);

        CoinsService.instance.earnFlagsNotifier.value = const CoinEarnFlags(
          firstUploadRewarded: true,
          profileCompletionRewarded: false,
        );
        await tester.pumpAndSettle();
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Add a photo and a bio'), findsOneWidget);

        CoinsService.instance.earnFlagsNotifier.value = const CoinEarnFlags(
          firstUploadRewarded: true,
          profileCompletionRewarded: true,
        );
        await tester.pumpAndSettle();
        expect(find.text('Done'), findsNWidgets(2));
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
        expect(find.text('Add a photo and a bio'), findsNothing);
      });

      testWidgets('activity section shows the empty line when there are no transactions', (tester) async {
        await tester.pumpWidget(_host(const RewardsActivitySection(), brightness));
        await tester.pump();
        await tester.pump();
        expect(find.text('Activity'), findsOneWidget);
        expect(find.text('No coin activity yet.'), findsOneWidget);
      });

      testWidgets('collection section shows locked and unlocked captions', (tester) async {
        final _MockShopBloc bloc = _MockShopBloc();
        final StreakShopState loaded = StreakShopState(
          status: StreakShopStatus.success,
          items: <PrismWallpaper>[_wall('a', days: 7, cost: 500), _wall('b', days: 30, cost: 500)],
        );
        whenListen(bloc, const Stream<StreakShopState>.empty(), initialState: loaded);
        getIt.registerFactory<StreakShopBloc>(() => bloc);
        CoinsService.instance.streakNotifier.value = const StreakStatus(
          streakDay: 1,
          count: 8,
          active: true,
          claimedToday: true,
          reminderEnabled: true,
          timezoneOffsetMinutes: 0,
          lastClaimDate: '',
        );
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_host(const RewardsCollectionSection(), brightness));
        await tester.pump();

        expect(find.text('Streak collection'), findsOneWidget);
        expect(find.text('Unlocked at 7 days'), findsOneWidget);
        expect(find.text('Unlocks at 30 days'), findsOneWidget);

        await tester.tap(find.text('Unlocks at 30 days'));
        await tester.pump();
        expect(find.text('Keep your streak for 30 days to unlock this. Or have 500 coins.'), findsOneWidget);
      });

      testWidgets('collection section hides itself when empty', (tester) async {
        final _MockShopBloc bloc = _MockShopBloc();
        whenListen(
          bloc,
          const Stream<StreakShopState>.empty(),
          initialState: const StreakShopState(status: StreakShopStatus.success),
        );
        getIt.registerFactory<StreakShopBloc>(() => bloc);
        await tester.pumpWidget(_host(const RewardsCollectionSection(), brightness));
        await tester.pump();
        expect(find.text('Streak collection'), findsNothing);
      });
    });
  }
}
