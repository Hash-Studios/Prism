import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_prompt_field.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_remix_chip.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

class _FakeConnectivityService implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

class _RecordingAnalytics extends FakeAppAnalytics {
  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event);
}

class _FakeRemixRepository extends Fake implements AiGenerationRepositoryImpl {
  int generateCalls = 0;
  String? restoredPrompt;

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async =>
      const <AiGenerationRecord>[];

  @override
  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async =>
      const <AiGenerationRecord>[];

  @override
  Future<String?> loadPrompt({required String userId}) async => restoredPrompt;

  @override
  Future<void> savePrompt({required String userId, required String prompt}) async {}

  @override
  Future<AiGenerationRecord> generate({
    required String prompt,
    required AiStylePreset stylePreset,
    required AiQualityTier qualityTier,
    required String targetSize,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    int? seed,
    String? chargeTxId,
    String? remixOf,
  }) {
    generateCalls++;
    throw StateError('generate must not run on open');
  }
}

AiRemixSeed _seed({String prompt = 'neon koi pond at dusk', AiStylePreset? style = AiStylePreset.watercolor}) =>
    AiRemixSeed(
      wallDocId: 'orig_1',
      title: 'Koi',
      creatorName: 'Asha',
      thumbnailUrl: '',
      prompt: prompt,
      sourceType: RemixSourceType.user,
      style: style,
    );

Future<_FakeRemixRepository> _pump(WidgetTester tester, AiRemixSeed? seed, {_RecordingAnalytics? analytics}) async {
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
  if (analytics != null) AnalyticsRuntime.instance = analytics;
  addTearDown(AnalyticsRuntime.reset);
  final _FakeRemixRepository repository = _FakeRemixRepository();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AiWallpaperTabPage(repository: repository, remixSeed: seed),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

String _promptText(WidgetTester tester) {
  final Finder promptField = find.descendant(of: find.byType(AiPromptField), matching: find.byType(TextField));
  return tester.widget<TextField>(promptField).controller!.text;
}

Finder _selectedStyleTile(String label) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is Semantics && widget.properties.selected == true && (widget.properties.label ?? '').contains(label),
);

void main() {
  setUp(AnalyticsRuntime.reset);

  testWidgets('a remix seed fills the prompt, the chip and the seed style', (tester) async {
    await _pump(tester, _seed());

    expect(_promptText(tester), 'neon koi pond at dusk');
    expect(find.byType(AiRemixChip), findsOneWidget);
    expect(find.text('Remixing Koi by Asha'), findsOneWidget);
    expect(_selectedStyleTile('Watercolor'), findsOneWidget);
  });

  testWidgets('a seed without a style keeps the default style', (tester) async {
    await _pump(tester, _seed(style: null));

    expect(_promptText(tester), 'neon koi pond at dusk');
    expect(_selectedStyleTile('Abstract'), findsOneWidget);
    expect(_selectedStyleTile('Watercolor'), findsNothing);
  });

  testWidgets('changing style keeps the remix prompt', (tester) async {
    await _pump(tester, _seed());
    final Finder natureStyle = find.byWidgetPredicate(
      (Widget widget) => widget is Semantics && (widget.properties.label ?? '').contains('Minimal'),
    );
    await tester.ensureVisible(natureStyle);
    await tester.tap(natureStyle);
    await tester.pumpAndSettle();

    expect(_promptText(tester), 'neon koi pond at dusk');
    expect(_selectedStyleTile('Minimal'), findsOneWidget);
  });

  testWidgets('signing in keeps the edited remix prompt instead of restoring the account draft', (tester) async {
    final _FakeRemixRepository repository = await _pump(tester, _seed());
    repository.restoredPrompt = 'saved prompt for the signed-in account';
    await tester.enterText(
      find.descendant(of: find.byType(AiPromptField), matching: find.byType(TextField)),
      'edited remix prompt',
    );
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-2'
      ..loggedIn = true;

    final Future<void> refresh = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pumpAndSettle();
    await refresh;

    expect(_promptText(tester), 'edited remix prompt');
  });

  testWidgets('a 200 character remix prompt is clipped at a word boundary', (tester) async {
    final String longPrompt = 'koi ' * 50;
    await _pump(tester, _seed(prompt: longPrompt.trim()));

    final String text = _promptText(tester);
    expect(text.length, lessThanOrEqualTo(160));
    expect(text, ('koi ' * 40).trim());
  });

  testWidgets('dropping the chip removes the link and keeps the prompt and logs the drop', (tester) async {
    final _RecordingAnalytics analytics = _RecordingAnalytics();
    await _pump(tester, _seed(), analytics: analytics);

    await tester.tap(find.byTooltip('Remove remix link'));
    await tester.pumpAndSettle();

    expect(find.byType(AiRemixChip), findsNothing);
    expect(find.text('Remixing Koi by Asha'), findsNothing);
    expect(_promptText(tester), 'neon koi pond at dusk');
    expect(analytics.events.whereType<RemixLinkDroppedEvent>(), hasLength(1));
  });

  testWidgets('opening a remix never starts a generation', (tester) async {
    final _FakeRemixRepository repository = await _pump(tester, _seed());

    expect(repository.generateCalls, 0);
  });

  testWidgets('no remix seed shows no chip', (tester) async {
    await _pump(tester, null);

    expect(find.byType(AiRemixChip), findsNothing);
  });
}
