import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/coin_packs/coin_packs.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
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

Future<void> _openShortfall(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: kLightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => showCoinShortfall(context, message: 'Short on coins', source: 'test'),
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

  testWidgets('a short balance opens the Get coins sheet when coin packs are on', (WidgetTester tester) async {
    CoinPacksFlag.debugOverride = true;
    app_state.prismUser = profileUser();

    await _openShortfall(tester);

    expect(find.text(_l10n.coinPacksTitle), findsOneWidget);
    expect(find.text('Short on coins'), findsOneWidget);
    expect(find.text(r'$0.99'), findsOneWidget);
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
