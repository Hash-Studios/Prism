import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/rewards/views/widgets/freeze_card.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_spend_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService service = CoinsService.instance;
  final List<String> haptics = <String>[];
  final List<Map<String, dynamic>> purchaseRequests = <Map<String, dynamic>>[];
  bool previousHapticsEnabled = true;

  const MethodChannel hapticsChannel = MethodChannel('prism/haptics');
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() async {
    await backend.install();
    service.balanceNotifier.value = 100;
    service.streakNotifier.value = StreakStatus.empty;
    previousHapticsEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    haptics.clear();
    purchaseRequests.clear();
    backend.onCall = (String name, Map<String, dynamic> parameters) async {
      if (name == 'buyStreakFreeze') purchaseRequests.add(parameters);
      return <String, Object>{'success': true, 'changed': true, 'currentBalance': 50, 'delta': -50, 'streakFreezes': 1};
    };
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(hapticsChannel, (MethodCall call) async {
      haptics.add(call.arguments! as String);
      return null;
    });
    messenger.setMockMethodCallHandler(toastChannel, (_) async => true);
  });

  tearDown(() async {
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(hapticsChannel, null);
    messenger.setMockMethodCallHandler(toastChannel, null);
    service.balanceNotifier.value = 0;
    service.streakNotifier.value = StreakStatus.empty;
    app_state.prismUser = app_constants.createGuestPrismUser();
    PrismHaptics.enabled = previousHapticsEnabled;
    await getIt.reset();
  });

  testWidgets('Get one and Buy each emit one tap and purchase a freeze', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FreezeCard(onEarnCoins: _ignore)),
      ),
    );

    await tester.tap(find.textContaining('Get one'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(haptics, <String>['tap']);
    expect(find.text('Buy a streak freeze for 50 coins?'), findsOneWidget);
    expect(find.text('Balance after: 50'), findsOneWidget);

    await tester.tap(find.text('Buy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    expect(haptics, <String>['tap', 'tap', 'success']);
    expect(purchaseRequests, hasLength(1));
    expect(purchaseRequests.single.keys, <String>['requestId']);
    expect(purchaseRequests.single['requestId'], matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
    expect(service.balanceNotifier.value, 50);
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Rewards spend freeze entry keeps one tap while opening the purchase sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: RewardsSpendSection(onStreakFreeze: () => buyStreakFreezeFlow(context, onEarnCoins: _ignore)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Streak freeze, 50 coins'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(haptics, <String>['tap']);
    expect(find.text('Buy a streak freeze for 50 coins?'), findsOneWidget);
    expect(purchaseRequests, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

void _ignore() {}
