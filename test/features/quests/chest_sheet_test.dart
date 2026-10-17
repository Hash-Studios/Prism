import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/quests/views/widgets/chest_sheet.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool?> openSheet(WidgetTester tester, ChestResult result) async {
    bool? shop;
    await tester.pumpWidget(
      MaterialApp(
        theme: kLightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => shop = await showChestSheet(context, result),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    return shop;
  }

  testWidgets('counts the coins up and shows the odds, with no Glint', (tester) async {
    await openSheet(tester, const ChestResult(ChestOutcome.opened, coins: 14, doubled: true));

    expect(find.text('Chest opened'), findsOneWidget);
    expect(find.text('+14'), findsOneWidget);
    expect(find.text('Your bonus quest doubled it.'), findsOneWidget);
    expect(
      find.textContaining('A chest pays ${CoinPolicy.questChestMin} to ${CoinPolicy.questChestMax} coins'),
      findsOneWidget,
    );
    expect(find.textContaining('10% chance of a cosmetic'), findsOneWidget);
    expect(find.text('See it in the Shop'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('without a doubling it tells how to double', (tester) async {
    await openSheet(tester, const ChestResult(ChestOutcome.opened, coins: 6));

    expect(find.text('Do the bonus quest before you open it to double it.'), findsOneWidget);
  });

  testWidgets('a cosmetic shows its name and the Shop button resolves true', (tester) async {
    bool? shop;
    await tester.pumpWidget(
      MaterialApp(
        theme: kLightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => shop = await showChestSheet(
                context,
                const ChestResult(ChestOutcome.opened, coins: 6, itemId: 'frame_ring'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('You also found Ring frame'), findsOneWidget);
    await tester.tap(find.text('See it in the Shop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(shop, isTrue);
  });

  test('cosmeticName reads the catalog id', () {
    expect(cosmeticName('glow_ember'), 'Ember name glow');
    expect(cosmeticName('theme_deep_ocean'), 'Deep Ocean theme');
    expect(cosmeticName('plain'), 'plain');
  });
}
