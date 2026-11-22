import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism_sheet/prism_sheet_route.dart';
import 'package:Prism/features/ads/views/widgets/coin_gate_sheet.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/features/coin_packs/coin_packs.dart';
import 'package:Prism/features/public_profile/views/widgets/gift_pass_sheet.dart';
import 'package:Prism/features/rewards/views/widgets/daily_claim_sheet.dart';
import 'package:Prism/features/rewards/views/widgets/streak_details.dart';
import 'package:Prism/features/shop/biz/bloc/shop_bloc.j.dart';
import 'package:Prism/features/shop/shop.dart';
import 'package:Prism/features/spin_wheel/views/widgets/get_coins_sheet.dart';
import 'package:Prism/features/streak/data/streak_rescue_service.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

class _Gateway implements CoinPackGateway {
  @override
  Future<List<CoinPack>> loadPacks() async => const <CoinPack>[
    CoinPack(
      def: CoinPackDef(productId: 'prism_coins_100', coins: 100),
      priceString: r'$0.99',
    ),
  ];

  @override
  Future<CoinPackPurchaseResult> buy(CoinPack pack, {VoidCallback? onVerifying}) async => const CoinPackCancelled();
}

class _Rescue extends StreakRescueService {
  @override
  Future<StreakRescueOffer?> fetch() async => const StreakRescueOffer(9);
}

class _AiHistory extends Fake implements AiGenerationRepositoryImpl {
  @override
  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async => [];
  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async => [];
  @override
  Future<String?> loadPrompt({required String userId}) async => 'A mountain at dawn';
}

Future<void> _openShortfall(WidgetTester tester, {void Function(BuildContext)? open}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: kLightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () {
              if (open == null) {
                showCoinShortfall(context, message: 'Short on coins', source: 'test');
              } else {
                open(context);
              }
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  late PrismUsersV2 previousUser;
  late CoinPackGateway Function() previousFactory;

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    previousUser = app_state.prismUser;
    previousFactory = coinPackGatewayFactory;
    coinPackGatewayFactory = _Gateway.new;
  });

  tearDown(() {
    CoinPacksFlag.debugOverride = null;
    app_state.prismUser = previousUser;
    coinPackGatewayFactory = previousFactory;
    AnalyticsRuntime.reset();
  });

  final Map<String, void Function(BuildContext)> entries = <String, void Function(BuildContext)>{
    'gift pass': (context) => showPrismSheet<void>(
      context,
      builder: (_) => const GiftPassSheet(recipientUid: 'ana', recipientName: 'Ana'),
    ),
    'streak details': (context) =>
        showPrismSheet<void>(context, builder: (_) => StreakDetails(rescueService: _Rescue())),
    'daily claim': (context) => showDailyClaimSheet(
      context,
      StreakClaimResult.fromPayload(<String, dynamic>{
        'claimed': true,
        'streakBroken': true,
        'previousStreakCount': 9,
        'streakDay': 1,
      }),
    ),
    'AI generation': (context) => Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => AiWallpaperTabPage(repository: _AiHistory()))),
  };
  for (final entry in entries.entries) {
    testWidgets('${entry.key} offers Buy coins on a short balance', (tester) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      CoinPacksFlag.debugOverride = true;
      app_state.prismUser = profileUser();
      final int balance = CoinsService.instance.balanceNotifier.value;
      CoinsService.instance.balanceNotifier.value = 0;
      addTearDown(() => CoinsService.instance.balanceNotifier.value = balance);

      await _openShortfall(tester, open: entry.value);
      final Finder buy = find.text(_l10n.coinPacksBuyCoins);
      expect(buy, findsOneWidget);
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(r'$0.99'), findsOneWidget);
    });
  }

  testWidgets('a refused AI spend without a shortfall does not offer another purchase', (tester) async {
    final CoinsTestBackend backend = CoinsTestBackend();
    await backend.install();
    addTearDown(getIt.reset);
    CoinPacksFlag.debugOverride = true;
    int spends = 0;
    backend.onCall = (name, _) async {
      if (name == 'spendCoins') spends++;
      return <String, Object?>{'success': false, 'changed': false, 'currentBalance': 100, 'reason': 'spend_refunded'};
    };
    CoinsService.instance.balanceNotifier.value = 100;
    await _openShortfall(tester, open: entries['AI generation']);
    final Finder generate = find.text(_l10n.economyAiGenerate);
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(spends, 1);
    expect(find.byType(CoinPacksSheet), findsNothing);
  });

  final Map<String, (String, void Function(BuildContext))> debtCases = {
    'coin gate': (
      'Missing 15',
      (c) => showCoinGateSheet<void>(c, title: 'Gate', cost: 10, message: (n) => 'Missing $n', options: []),
    ),
    'short-balance sheet': (
      _l10n.economyCoinsMissing(15),
      (c) => showGetCoinsSheet(c, message: 'Spin', sourceTag: 'test', upsellSource: 'test', cost: 10),
    ),
    'shop': (
      _l10n.economyShopCoinsShort(shopPriceFor(shopItem('theme_rose')!) + 5),
      (c) => showShopItemSheet(c, shopItem('theme_rose')!),
    ),
  };
  for (final entry in debtCases.entries) {
    testWidgets('${entry.key} includes refund debt in the shortfall', (tester) async {
      final int previous = CoinsService.instance.balanceNotifier.value;
      CoinsService.instance.balanceNotifier.value = -5;
      addTearDown(() => CoinsService.instance.balanceNotifier.value = previous);
      if (entry.key == 'shop') {
        getIt.registerFactory<ShopBloc>(() => ShopBloc(SettingsLocalDataSource(InMemoryLocalStore())));
        addTearDown(getIt.reset);
      }
      await _openShortfall(tester, open: entry.value.$2);
      expect(find.textContaining(entry.value.$1), findsOneWidget);
    });
  }

  testWidgets('a short balance opens the Get coins sheet when coin packs are on', (WidgetTester tester) async {
    CoinPacksFlag.debugOverride = true;
    app_state.prismUser = profileUser();

    await _openShortfall(tester);

    expect(find.text(_l10n.coinPacksTitle), findsOneWidget);
    expect(find.text('Short on coins'), findsOneWidget);
    expect(find.text(r'$0.99'), findsOneWidget);
  });

  testWidgets('rebuilding an open sheet keeps its loaded purchase gateway', (tester) async {
    CoinPacksFlag.debugOverride = true;
    app_state.prismUser = profileUser();
    await _openShortfall(tester);
    final Finder sheet = find.byType(CoinPacksSheet);
    final CoinPackGateway loaded = tester.widget<CoinPacksSheet>(sheet).gateway;
    tester.element(sheet).visitAncestorElements((element) {
      element.markNeedsBuild();
      return false;
    });
    await tester.pump();
    expect(tester.widget<CoinPacksSheet>(sheet).gateway, same(loaded));
  });

  testWidgets('disabling packs after loading prevents the native store purchase', (tester) async {
    app_state.prismUser = profileUser(id: 'buyer');
    CoinPacksFlag.debugOverride = true;
    const channel = MethodChannel('purchases_flutter');
    final nativeCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call.method);
      if (call.method.startsWith('purchase')) throw PlatformException(code: '1');
      return 'buyer';
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    const package = Package(
      'small',
      PackageType.custom,
      StoreProduct('prism_coins_100', '', '', 0.99, r'$0.99', 'USD'),
      PresentedOfferingContext('coins', null, null),
    );
    final gateway = RevenueCatCoinPackGateway(
      currentUserId: () => app_state.prismUser.id,
      getOfferings: () async => const Offerings({
        'coins': Offering('coins', '', {}, [package]),
      }),
    );
    final pack = (await gateway.loadPacks()).single;
    CoinPacksFlag.debugOverride = false;
    expect(await gateway.buy(pack), isA<CoinPackFailed>());
    expect(nativeCalls.where((method) => method.startsWith('purchase')), isEmpty);
  });

  testWidgets('the flag off keeps the old path and opens no sheet', (WidgetTester tester) async {
    CoinPacksFlag.debugOverride = false;
    app_state.prismUser = profileUser();

    await _openShortfall(tester);

    expect(find.text(_l10n.coinPacksTitle), findsNothing);
  });

  testWidgets('a guest never sees the Get coins sheet', (WidgetTester tester) async {
    CoinPacksFlag.debugOverride = true;
    app_state.prismUser = profileUser(loggedIn: false);

    await _openShortfall(tester);

    expect(CoinPacksFlag.available, isFalse);
    expect(find.text(_l10n.coinPacksTitle), findsNothing);
  });
}
