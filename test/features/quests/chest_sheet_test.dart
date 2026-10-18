import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/quests/views/widgets/chest_sheet.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool? shop;
  final List<Object?> haptics = <Object?>[];

  setUp(() {
    shop = null;
    haptics.clear();
    PrismHaptics.enabled = true;
  });

  Future<void> openSheet(WidgetTester tester, ChestResult result, {bool reduceMotion = false}) async {
    const MethodChannel channel = MethodChannel('prism/haptics');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      MaterialApp(
        theme: kLightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
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
  }

  const Duration sequence = Duration(milliseconds: 1500);

  testWidgets('counts the coins up and shows the odds, with no Glint', (tester) async {
    await openSheet(tester, const ChestResult(ChestOutcome.opened, coins: 14, doubled: true));
    await tester.pump(sequence);

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

  testWidgets('without a doubling it tells how to double and shows no tag', (tester) async {
    await openSheet(tester, const ChestResult(ChestOutcome.opened, coins: 6));
    await tester.pump(sequence);

    expect(find.text('Do the bonus quest before you open it to double it.'), findsOneWidget);
    expect(find.text('×2'), findsNothing);
  });

  testWidgets('a doubled chest shows the ×2 tag', (tester) async {
    await openSheet(tester, const ChestResult(ChestOutcome.opened, coins: 6, doubled: true));
    await tester.pump(sequence);

    expect(find.text('×2'), findsOneWidget);
  });

  testWidgets('a cosmetic shows its name and the Shop button resolves true', (tester) async {
    await openSheet(tester, const ChestResult(ChestOutcome.opened, coins: 6, itemId: 'frame_ring'));
    await tester.pump(sequence);

    expect(find.text('You also found Ring frame'), findsOneWidget);
    await tester.tap(find.text('See it in the Shop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(shop, isTrue);
  });

  testWidgets('the Nice button resolves false', (tester) async {
    await openSheet(tester, const ChestResult(ChestOutcome.opened, coins: 6, itemId: 'frame_ring'));
    await tester.pump(sequence);

    await tester.tap(find.text('Nice'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(shop, isFalse);
  });

  testWidgets('the success haptic fires once at the burst, not at the start', (tester) async {
    await openSheet(tester, const ChestResult(ChestOutcome.opened, coins: 6));
    await tester.pump(const Duration(milliseconds: 100));
    expect(haptics, isEmpty);

    await tester.pump(const Duration(milliseconds: 300));
    expect(haptics, <Object?>['success']);

    await tester.pump(sequence);
    expect(haptics, <Object?>['success']);
  });

  testWidgets('with reduced motion the final amount shows at once, with no coins flying', (tester) async {
    await openSheet(tester, const ChestResult(ChestOutcome.opened, coins: 14, doubled: true), reduceMotion: true);
    await tester.pump();

    expect(find.text('+14'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(haptics, isEmpty);
  });

  test('cosmeticName reads the catalog id', () {
    expect(cosmeticName('glow_ember'), 'Ember name glow');
    expect(cosmeticName('theme_deep_ocean'), 'Deep Ocean theme');
    expect(cosmeticName('plain'), 'plain');
  });
}
