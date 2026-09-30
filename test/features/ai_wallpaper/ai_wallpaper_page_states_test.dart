import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectivityService implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;
}

class _FakeRepository extends Fake implements AiGenerationRepositoryImpl {
  _FakeRepository(this.history);

  final List<AiGenerationRecord> history;

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async => history;
}

AiGenerationRecord _record() => AiGenerationRecord(
  id: 'generation-1',
  userId: 'user-1',
  createdAt: DateTime.utc(2026),
  prompt: 'A quiet mountain lake',
  stylePreset: AiStylePreset.nature,
  qualityTier: AiQualityTier.fast,
  provider: 'test',
  model: 'test',
  seed: 1,
  width: 720,
  height: 1280,
  imageUrl: '',
  watermarkedImageUrl: '',
  chargeMode: AiChargeMode.freeTrial,
  coinsSpent: 0,
  status: 'success',
);

void main() {
  Future<void> pumpPage(WidgetTester tester, {List<AiGenerationRecord> history = const <AiGenerationRecord>[]}) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    CoinsService.instance.balanceNotifier.value = 100;
    await tester.pumpWidget(MaterialApp(home: AiWallpaperTabPage(repository: _FakeRepository(history))));
    await tester.pumpAndSettle();
  }

  testWidgets('compose state puts the prompt first, then style and quality', (tester) async {
    await pumpPage(tester);

    expect(find.text('AI wallpaper'), findsOneWidget);
    expect(find.text('Describe a scene'), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Anime'), findsOneWidget);
    expect(find.text('Quality'), findsWidgets);
    expect(find.text('Generate'), findsOneWidget);
    expect(find.byTooltip('Shuffle a new example description'), findsOneWidget);
    expect(find.byTooltip('Use this scene in your description (editable)'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Each wallpaper you generate appears here, so you can compare or switch back.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Generate is off with a reason while the description is empty', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(find.text('Describe a scene to generate.'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.byType(PrismButton).last).onPressed, isNull);
  });

  testWidgets('picking a style keeps what the user typed', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'my own idea');
    await tester.pump();
    await tester.tap(find.text('Anime'));
    await tester.pump();

    expect(find.text('my own idea'), findsOneWidget);
  });

  testWidgets('picking a style replaces a prompt the app wrote', (tester) async {
    await pumpPage(tester);
    final String before = tester.widget<TextField>(find.byType(TextField)).controller!.text;

    await tester.tap(find.text('Anime'));
    await tester.pump();

    final String after = tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(after, isNot(before));
  });

  testWidgets('short on coins, the main button sends the user to get coins and says why', (tester) async {
    await pumpPage(tester);

    CoinsService.instance.balanceNotifier.value = 0;
    await tester.pump();

    expect(find.text('Get coins'), findsOneWidget);
    expect(find.text('Generate'), findsNothing);
    expect(find.text('You need ${AiQualityTier.fast.coinCost} coins. You have 0.'), findsOneWidget);
  });

  testWidgets('a result shows Save as the accent action and Generate as tonal', (tester) async {
    await pumpPage(tester, history: <AiGenerationRecord>[_record()]);

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Refine'), findsOneWidget);
    expect(find.byTooltip('Set as wallpaper'), findsOneWidget);
    expect(find.bySemanticsLabel('Submit wallpaper for community review'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Save')).variant, PrismButtonVariant.primary);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Generate')).variant, PrismButtonVariant.tonal);
    expect(find.bySemanticsLabel('Generation from 1 Jan'), findsOneWidget);
  });

  testWidgets('a guest sees a sign-in prompt and no compose controls', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: AiWallpaperTabPage(repository: _FakeRepository(const <AiGenerationRecord>[])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to use AI wallpaper'), findsOneWidget);
    expect(find.text('Generate'), findsNothing);
    expect(find.text('Describe a scene'), findsNothing);
  });
}
