import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/rewards/views/widgets/freeze_card.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_spend_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel hapticsChannel = MethodChannel('prism/haptics');
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> haptics = <String>[];

  setUp(() {
    PrismHaptics.enabled = true;
    CoinsService.instance.streakNotifier.value = StreakStatus.empty;
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      hapticsChannel,
      (MethodCall call) async => haptics.add(call.arguments! as String),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (_) async => true,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(hapticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    CoinsService.instance.streakNotifier.value = StreakStatus.empty;
  });

  Future<void> pumpSpendSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: RewardsSpendSection(onStreakFreeze: () => buyStreakFreezeFlow(context, onEarnCoins: () {})),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const String freezeLabel = 'Streak freeze, ${CoinPolicy.streakFreezeCost} coins';

  testWidgets('capped freeze action emits only the error outcome haptic', (tester) async {
    CoinsService.instance.streakNotifier.value = StreakStatus.empty.copyWith(freezes: CoinPolicy.maxStreakFreezes);
    await pumpSpendSection(tester);

    await tester.tap(find.bySemanticsLabel(freezeLabel));
    await tester.pump();

    expect(haptics, <String>['error']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('available freeze action emits one tap haptic while opening the sheet', (tester) async {
    await pumpSpendSection(tester);

    await tester.tap(find.bySemanticsLabel(freezeLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(haptics, <String>['tap']);
    expect(find.text('You need ${CoinPolicy.streakFreezeCost} coins.'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('premium tile semantics action shares the pointer haptic path', (tester) async {
    await pumpSpendSection(tester);
    final SemanticsHandle semanticsHandle = tester.ensureSemantics();
    tester.semantics.tap(find.semantics.byLabel('Premium wallpaper, ${CoinPolicy.premiumWallpaperDownload} coins'));
    await tester.pump();

    expect(haptics, <String>['tap']);
    semanticsHandle.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
