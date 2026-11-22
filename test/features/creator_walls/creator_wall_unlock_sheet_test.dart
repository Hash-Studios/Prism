import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_walls/creator_walls.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

PrismWallpaper _wall() => const PrismWallpaper(
  core: WallpaperCore(
    id: 'neon',
    source: WallpaperSource.prism,
    fullUrl: '',
    thumbnailUrl: 'https://example.com/neon.jpg',
    authorUid: 'maker',
    authorName: 'Ava',
  ),
  firestoreDocumentId: 'neon',
  creatorPrice: 40,
);

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
  theme: kLightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    PrismHaptics.enabled = true;
    messenger.setMockMethodCallHandler(const MethodChannel('prism/haptics'), (MethodCall call) async => null);
    messenger.setMockMethodCallHandler(toastChannel, (MethodCall call) async => true);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(toastChannel, null);
    AnalyticsRuntime.reset();
  });

  // Opens the sheet the way the detail page does, through showPrismSheet, so it has a sheet ancestor.
  Future<void> pumpSheet(
    WidgetTester tester, {
    required CreatorWallUnlocks unlocks,
    required Future<CreatorWallUnlockResult> Function({required String wallDocId, required int expectedPrice}) unlock,
    ValueListenable<int>? balance,
    ValueChanged<bool?>? onResult,
    double textScale = 1,
  }) async {
    final ValueListenable<int> coins = balance ?? ValueNotifier<int>(200);
    final PrismWallpaper wall = _wall();
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final bool? result = await showPrismSheet<bool>(
                  context,
                  builder: (BuildContext sheetContext) =>
                      CreatorWallUnlockSheet(wall: wall, unlock: unlock, balance: coins, unlocks: unlocks),
                );
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
        textScale: textScale,
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  CreatorWallUnlocks freshUnlocks() => CreatorWallUnlocks(owner: () => 'fan', read: (_, _) async => null);

  testWidgets('shows the price, the balance and an enabled unlock button', (WidgetTester tester) async {
    await pumpSheet(
      tester,
      unlocks: freshUnlocks(),
      unlock: ({required wallDocId, required expectedPrice}) async =>
          const CreatorWallUnlockResult(CreatorWallUnlockOutcome.failed),
    );

    expect(find.text('Unlock this wall'), findsOneWidget);
    expect(find.text('Your balance: 200 coins'), findsOneWidget);
    expect(find.text('Unlock for 40 coins'), findsOneWidget);
    expect(find.text('You need 30 more coins.'), findsNothing);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Unlock for 40 coins')).onPressed, isNotNull);
  });

  testWidgets('a short balance shows the short-by line and Get coins but still allows an idempotent retry', (
    WidgetTester tester,
  ) async {
    await pumpSheet(
      tester,
      unlocks: freshUnlocks(),
      balance: ValueNotifier<int>(10),
      unlock: ({required wallDocId, required expectedPrice}) async =>
          const CreatorWallUnlockResult(CreatorWallUnlockOutcome.failed),
    );

    expect(find.text('Your balance: 10 coins'), findsOneWidget);
    expect(find.text('You need 30 more coins.'), findsOneWidget);
    expect(find.text('Get coins'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Unlock for 40 coins')).onPressed, isNotNull);
  });

  testWidgets('a successful unlock shows the unlocked moment and marks the wall unlocked', (WidgetTester tester) async {
    final CreatorWallUnlocks unlocks = freshUnlocks();
    String? sentId;
    int? sentPrice;
    bool? popped;
    await pumpSheet(
      tester,
      unlocks: unlocks,
      onResult: (bool? result) => popped = result,
      unlock: ({required wallDocId, required expectedPrice}) async {
        sentId = wallDocId;
        sentPrice = expectedPrice;
        return const CreatorWallUnlockResult(CreatorWallUnlockOutcome.unlocked, price: 40);
      },
    );

    await tester.tap(find.widgetWithText(PrismButton, 'Unlock for 40 coins'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(sentId, 'neon');
    expect(sentPrice, 40);
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(unlocks.accessFor(_wall()), CreatorWallAccess.unlocked);
    expect(analytics.events.map((event) => event.eventName), contains('creator_wall_unlocked'));

    await tester.tap(find.text('Done'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(popped, isTrue);
  });

  testWidgets('a price change updates the displayed price for the next attempt', (
    WidgetTester tester,
  ) async {
    final CreatorWallUnlocks unlocks = freshUnlocks();
    bool? popped;
    await pumpSheet(
      tester,
      unlocks: unlocks,
      onResult: (bool? result) => popped = result,
      unlock: ({required wallDocId, required expectedPrice}) async =>
          const CreatorWallUnlockResult(CreatorWallUnlockOutcome.priceChanged, price: 50),
    );

    await tester.tap(find.widgetWithText(PrismButton, 'Unlock for 40 coins'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Unlock this wall'), findsOneWidget);
    expect(find.text('Unlock for 50 coins'), findsOneWidget);
    expect(popped, isNull);
    expect(unlocks.accessFor(_wall()), isNot(CreatorWallAccess.unlocked));
  });

  testWidgets('a thrown unlock request returns the sheet to a retryable state', (tester) async {
    await pumpSheet(
      tester,
      unlocks: freshUnlocks(),
      unlock: ({required wallDocId, required expectedPrice}) async => throw StateError('network'),
    );
    await tester.tap(find.widgetWithText(PrismButton, 'Unlock for 40 coins'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Unlock this wall'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Unlock for 40 coins')).onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('large text (2.0) in a 320x640 sheet does not overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpSheet(
      tester,
      unlocks: freshUnlocks(),
      balance: ValueNotifier<int>(10),
      textScale: 2.0,
      unlock: ({required wallDocId, required expectedPrice}) async =>
          const CreatorWallUnlockResult(CreatorWallUnlockOutcome.failed),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Unlock this wall'), findsOneWidget);
  });
}
