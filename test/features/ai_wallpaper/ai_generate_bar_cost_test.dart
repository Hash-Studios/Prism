import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_generate_bar.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required int cost,
  required int balance,
  required bool hasPrompt,
  required bool loading,
  required VoidCallback onGenerate,
  required VoidCallback onGetCoins,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: AiGenerateBar(
            cost: cost,
            balance: balance,
            hasPrompt: hasPrompt,
            loading: loading,
            prominent: true,
            onGenerate: onGenerate,
            onGetCoins: onGetCoins,
          ),
        ),
      ),
    ),
  );
}

void main() {
  late EconomyConfig original;

  setUp(() {
    original = EconomyConfig.current;
  });

  tearDown(() {
    EconomyConfig.current = original;
  });

  group('AiQualityTier.costFor', () {
    test('default config: free pays list price, Pro pays half rounded up', () {
      EconomyConfig.current = EconomyConfig.defaults;
      expect(
        <int>[
          AiQualityTier.fast.costFor(isPro: false),
          AiQualityTier.balanced.costFor(isPro: false),
          AiQualityTier.quality.costFor(isPro: false),
        ],
        <int>[10, 75, 100],
      );
      expect(
        <int>[
          AiQualityTier.fast.costFor(isPro: true),
          AiQualityTier.balanced.costFor(isPro: true),
          AiQualityTier.quality.costFor(isPro: true),
        ],
        <int>[5, 38, 50],
      );
    });

    test('Pro pays full price when the config does not list aiGeneration', () {
      EconomyConfig.current = const EconomyConfig(proDiscountActions: <String>['dropWall', 'dropPack']);
      expect(
        <int>[
          AiQualityTier.fast.costFor(isPro: true),
          AiQualityTier.balanced.costFor(isPro: true),
          AiQualityTier.quality.costFor(isPro: true),
        ],
        <int>[10, 75, 100],
      );
    });

    test('Pro rounds half up and never goes below 1', () {
      EconomyConfig.current = const EconomyConfig(spend: EconomySpend(aiFast: 7));
      expect(AiQualityTier.fast.costFor(isPro: true), 4);

      EconomyConfig.current = const EconomyConfig(spend: EconomySpend(aiFast: 1));
      expect(AiQualityTier.fast.costFor(isPro: true), 1);
    });
  });

  group('AiGenerateBar', () {
    for (final AiQualityTier tier in AiQualityTier.values) {
      for (final bool isPro in <bool>[false, true]) {
        testWidgets('shows Generate and the ${isPro ? 'Pro' : 'free'} cost for ${tier.name}', (tester) async {
          EconomyConfig.current = EconomyConfig.defaults;
          final int cost = tier.costFor(isPro: isPro);
          var generated = 0;
          var gotCoins = 0;

          await tester.pumpWidget(
            _host(
              cost: cost,
              balance: 1000,
              hasPrompt: true,
              loading: false,
              onGenerate: () => generated++,
              onGetCoins: () => gotCoins++,
            ),
          );

          expect(find.text('Generate'), findsOneWidget);
          expect(find.text('$cost'), findsOneWidget);

          await tester.tap(find.text('Generate'));
          expect(generated, 1);
          expect(gotCoins, 0);
        });
      }
    }

    testWidgets('balanced Pro shows 38 on the button', (tester) async {
      EconomyConfig.current = EconomyConfig.defaults;
      await tester.pumpWidget(
        _host(
          cost: AiQualityTier.balanced.costFor(isPro: true),
          balance: 1000,
          hasPrompt: true,
          loading: false,
          onGenerate: () {},
          onGetCoins: () {},
        ),
      );
      expect(find.text('38'), findsOneWidget);
    });

    testWidgets('short balance shows the reason, Earn coins, no cost, and opens Rewards', (tester) async {
      var generated = 0;
      var gotCoins = 0;

      await tester.pumpWidget(
        _host(
          cost: 75,
          balance: 20,
          hasPrompt: true,
          loading: false,
          onGenerate: () => generated++,
          onGetCoins: () => gotCoins++,
        ),
      );

      expect(find.text('You need 75 coins. You have 20.'), findsOneWidget);
      expect(find.text('Earn coins'), findsOneWidget);
      expect(find.text('Generate'), findsNothing);
      expect(find.text('75'), findsNothing);

      await tester.tap(find.text('Earn coins'));
      expect(gotCoins, 1);
      expect(generated, 0);
    });

    testWidgets('exact balance counts as enough', (tester) async {
      await tester.pumpWidget(
        _host(cost: 75, balance: 75, hasPrompt: true, loading: false, onGenerate: () {}, onGetCoins: () {}),
      );

      expect(find.text('Generate'), findsOneWidget);
      expect(find.text('Earn coins'), findsNothing);
    });

    testWidgets('no prompt with enough coins shows the describe hint and a disabled button', (tester) async {
      var generated = 0;
      var gotCoins = 0;

      await tester.pumpWidget(
        _host(
          cost: 75,
          balance: 1000,
          hasPrompt: false,
          loading: false,
          onGenerate: () => generated++,
          onGetCoins: () => gotCoins++,
        ),
      );

      expect(find.text('Describe a scene to generate.'), findsOneWidget);
      expect(tester.widget<PrismButton>(find.byType(PrismButton)).onPressed, isNull);

      await tester.tap(find.text('Generate'));
      expect(generated, 0);
      expect(gotCoins, 0);
    });

    testWidgets('loading shows no reason text', (tester) async {
      await tester.pumpWidget(
        _host(cost: 75, balance: 20, hasPrompt: false, loading: true, onGenerate: () {}, onGetCoins: () {}),
      );

      expect(find.text('You need 75 coins. You have 20.'), findsNothing);
      expect(find.text('Describe a scene to generate.'), findsNothing);
    });
  });
}
