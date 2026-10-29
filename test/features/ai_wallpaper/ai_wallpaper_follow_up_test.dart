import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_follow_up.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_view.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _FakeConnectivityService implements ConnectivityService {
  @override
  Future<bool> hasConnection() => Future<bool>.value(true);

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

class _FakeFunctionsPlatform extends FirebaseFunctionsPlatform {
  _FakeFunctionsPlatform(super.app, super.region, this.onCall);

  Future<dynamic> Function(String name, dynamic parameters) onCall;

  @override
  FirebaseFunctionsPlatform delegateFor({FirebaseApp? app, required String region}) => this;

  @override
  HttpsCallablePlatform httpsCallable(String? origin, String name, HttpsCallableOptions options) =>
      _FakeHttpsCallable(this, origin, name, options, null);

  @override
  HttpsCallablePlatform httpsCallableWithUri(String? origin, Uri uri, HttpsCallableOptions options) =>
      _FakeHttpsCallable(this, origin, null, options, uri);
}

class _FakeHttpsCallable extends HttpsCallablePlatform {
  _FakeHttpsCallable(super.functions, super.origin, super.name, super.options, super.uri);

  @override
  Future<dynamic> call([dynamic parameters]) => (functions as _FakeFunctionsPlatform).onCall(name!, parameters);
}

class _MockStartupRepository extends Mock implements StartupRepository {}

class _RecordingLiveActivityApi extends PrismLiveActivityHostApi {
  int starts = 0;

  @override
  Future<String?> startAiGeneration(AiActivityRequest request) async => 'activity-${++starts}';

  @override
  Future<void> finishAiGeneration(String activityId, String imageUrl) async {}

  @override
  Future<void> failAiGeneration(String activityId, String detail) async {}

  @override
  Future<void> cancelAiGeneration(String activityId) async {}
}

class _FollowUpRepository extends Fake implements AiGenerationRepositoryImpl {
  _FollowUpRepository({this.heroQuality = AiQualityTier.balanced});

  final AiQualityTier heroQuality;
  final List<({String generationId, String variationPrompt, int coinsSpent})> variations =
      <({String generationId, String variationPrompt, int coinsSpent})>[];
  Completer<void>? variationGate;
  Object? variationError;

  @override
  Future<String?> loadPrompt({required String userId}) async => null;

  @override
  Future<void> savePrompt({required String userId, required String prompt}) async {}

  @override
  Future<void> clearForUser(String userId) async {}

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async =>
      const <AiGenerationRecord>[];

  @override
  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async =>
      const <AiGenerationRecord>[];

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
  }) async => _record(id: 'hero-1', quality: heroQuality);

  @override
  Future<AiGenerationRecord> generateVariation({
    required String generationId,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    String variationPrompt = '',
    double strength = 0.45,
    String? chargeTxId,
  }) async {
    variations.add((generationId: generationId, variationPrompt: variationPrompt, coinsSpent: coinsSpent));
    final Completer<void>? gate = variationGate;
    if (gate != null) await gate.future;
    if (variationError != null) throw variationError!;
    return _record(id: 'var-${variations.length}', quality: heroQuality);
  }
}

AiGenerationRecord _record({required String id, required AiQualityTier quality}) => AiGenerationRecord(
  id: id,
  userId: 'user-1',
  createdAt: DateTime.utc(2026),
  prompt: 'A quiet mountain lake',
  stylePreset: AiStylePreset.nature,
  qualityTier: quality,
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

StartupConfigEntity _startupConfig({required bool aiVariationsEnabled}) => StartupConfigEntity(
  topImageLink: app_constants.defaultTopImageLink,
  bannerText: '',
  bannerTextOn: false,
  bannerUrl: '',
  obsoleteAppVersion: '',
  verifiedUsers: const <String>[],
  premiumCollections: const <String>[],
  aiEnabled: true,
  aiRolloutPercent: 100,
  aiSubmitEnabled: true,
  aiVariationsEnabled: aiVariationsEnabled,
  useRcPaywalls: true,
  onboardingV2Enabled: true,
);

/// Price in coins for a tier, as the server charges a non-Pro user.
int _priceOf(String qualityTier) => switch (qualityTier) {
  'fast' => 10,
  'balanced' => 75,
  'quality' => 100,
  _ => 0,
};

String _tierOf(Object? parameters) => (parameters! as Map<Object?, Object?>)['qualityTier']! as String;

Map<String, Object> _coinReply(String name, Object? parameters) {
  final int cost = name == 'spendCoins' ? _priceOf(_tierOf(parameters)) : 0;
  return <String, Object>{
    'success': true,
    'changed': true,
    'currentBalance': 1000,
    'delta': -cost,
    'transactionId': 'reservation-1',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late _FakeFunctionsPlatform functions;
  late FakeAppAnalytics analytics;
  late SettingsLocalDataSource settings;
  late _MockStartupRepository startup;
  late List<Map<String, Object?>> spends;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    functions = _FakeFunctionsPlatform(null, 'asia-south1', (name, parameters) async => <String, Object>{});
    FirebaseFunctionsPlatform.instance = functions;
  });

  setUp(() {
    spends = <Map<String, Object?>>[];
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    startup = _MockStartupRepository();
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
    });
    LiveActivityChannel.api = _RecordingLiveActivityApi();
    LiveActivityChannel.isSupportedPlatform = () => true;
  });

  Future<void> setUpPage(
    WidgetTester tester, {
    required _FollowUpRepository repository,
    required bool aiVariationsEnabled,
    int? confirmedCost,
  }) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await getIt.reset();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    if (confirmedCost != null) await settings.set(PersistenceKeys.aiFollowUpConfirmedCost, confirmedCost);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<StartupRepository>(startup);
    when(() => startup.currentConfig).thenReturn(_startupConfig(aiVariationsEnabled: aiVariationsEnabled));
    functions.onCall = (name, parameters) async {
      if (name == 'spendCoins') spends.add(Map<String, Object?>.from(parameters as Map<Object?, Object?>));
      return _coinReply(name, parameters);
    };
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..coins = 1000
      ..loggedIn = true;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Makes the hero wallpaper from the compose page, then clears the reservations that generation made.
  Future<void> generateHero(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'A quiet mountain lake');
    await tester.pump();
    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.byType(AiResultView), findsOneWidget);
    spends.clear();
  }

  Future<void> tapChip(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(ValueKey<String>('ai-follow-up-$name')));
  }

  List<PrismChip> followUpChips(WidgetTester tester) => tester
      .widgetList<PrismChip>(
        find.descendant(
          of: find.byType(AiResultView),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is PrismChip &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('ai-follow-up-'),
          ),
        ),
      )
      .toList();

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  testWidgets('chips run the variation of the hero with their prompt and the hero tier price', (tester) async {
    final repository = _FollowUpRepository();
    await setUpPage(tester, repository: repository, aiVariationsEnabled: true, confirmedCost: 1000);
    await generateHero(tester);

    await tapChip(tester, 'night');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1400));

    expect(repository.variations, hasLength(1));
    expect(repository.variations.single.generationId, 'hero-1');
    expect(repository.variations.single.variationPrompt, AiFollowUp.night.prompt);
    expect(repository.variations.single.coinsSpent, 75);
    expect(spends, hasLength(1));
    expect(spends.single['qualityTier'], 'balanced');
    expect(analytics.events.whereType<AiFollowUpUsedEvent>().map((e) => e.chipId), ['night']);
    expect(tester.widget<AiResultView>(find.byType(AiResultView)).session.map((r) => r.id), <String>[
      'hero-1',
      'var-1',
    ]);
  });

  testWidgets('chips are hidden when variations are off', (tester) async {
    await setUpPage(tester, repository: _FollowUpRepository(), aiVariationsEnabled: false);
    await generateHero(tester);

    expect(find.byType(AiResultView), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ai-follow-up-watercolour')), findsNothing);
    expect(find.byTooltip('Try another'), findsNothing);
  });

  testWidgets('all five chips show', (tester) async {
    await setUpPage(tester, repository: _FollowUpRepository(), aiVariationsEnabled: true, confirmedCost: 1000);
    await generateHero(tester);

    expect(find.text('As watercolour'), findsOneWidget);
    expect(find.text('Night version'), findsOneWidget);
    expect(find.text('More minimal'), findsOneWidget);
    expect(find.text('Warmer'), findsOneWidget);
    expect(find.text('Add depth'), findsOneWidget);
  });

  testWidgets('chips are off while a take is being made and a second tap does not charge again', (tester) async {
    final repository = _FollowUpRepository()..variationGate = Completer<void>();
    await setUpPage(tester, repository: repository, aiVariationsEnabled: true, confirmedCost: 1000);
    await generateHero(tester);

    await tapChip(tester, 'night');
    await tester.pump();

    final List<PrismChip> busy = followUpChips(tester);
    expect(busy, hasLength(5));
    expect(busy.every((PrismChip chip) => chip.onTap == null), isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('ai-follow-up-warmer')), warnIfMissed: false);
    await tester.pump();

    expect(repository.variations, hasLength(1));
    expect(spends, hasLength(1));

    repository.variationGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    final List<PrismChip> idle = followUpChips(tester);
    expect(idle, hasLength(5));
    expect(idle.every((PrismChip chip) => chip.onTap != null), isTrue);
  });

  testWidgets('two taps in the same frame start one take', (tester) async {
    final repository = _FollowUpRepository()..variationGate = Completer<void>();
    await setUpPage(tester, repository: repository, aiVariationsEnabled: true, confirmedCost: 1000);
    await generateHero(tester);

    final Offset chip = tester.getCenter(find.byKey(const ValueKey<String>('ai-follow-up-night')));
    final TestGesture first = await tester.createGesture(pointer: 1);
    await first.down(chip);
    await first.up();
    final TestGesture second = await tester.createGesture(pointer: 2);
    await second.down(chip);
    await second.up();
    await tester.pump();

    expect(repository.variations, hasLength(1));
    expect(spends, hasLength(1));

    repository.variationGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(repository.variations, hasLength(1));
  });

  testWidgets('the first chip asks before it spends coins', (tester) async {
    final repository = _FollowUpRepository();
    await setUpPage(tester, repository: repository, aiVariationsEnabled: true, confirmedCost: 0);
    await generateHero(tester);

    await tapChip(tester, 'night');
    await tester.pumpAndSettle();

    expect(find.text('Make a new take?'), findsOneWidget);
    expect(find.text('A follow-up makes a new wallpaper from this one. Each one costs 75 coins.'), findsOneWidget);
    expect(repository.variations, isEmpty);

    await tester.tap(find.widgetWithText(PrismButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repository.variations, isEmpty);
    expect(settings.get<int>(PersistenceKeys.aiFollowUpConfirmedCost, defaultValue: 0), 0);

    await tapChip(tester, 'night');
    await tester.pumpAndSettle();
    expect(find.text('Make a new take?'), findsOneWidget);

    await tester.tap(find.widgetWithText(PrismButton, 'Make it'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1400));

    expect(repository.variations, hasLength(1));
    expect(settings.get<int>(PersistenceKeys.aiFollowUpConfirmedCost, defaultValue: 0), 75);

    await tapChip(tester, 'warmer');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1400));

    expect(find.text('Make a new take?'), findsNothing);
    expect(repository.variations, hasLength(2));
    expect(repository.variations.last.variationPrompt, AiFollowUp.warmer.prompt);
  });

  testWidgets('a higher price asks again', (tester) async {
    final repository = _FollowUpRepository(heroQuality: AiQualityTier.quality);
    await setUpPage(tester, repository: repository, aiVariationsEnabled: true, confirmedCost: 10);
    await generateHero(tester);

    await tapChip(tester, 'night');
    await tester.pumpAndSettle();

    expect(find.text('Make a new take?'), findsOneWidget);
    expect(find.text('A follow-up makes a new wallpaper from this one. Each one costs 100 coins.'), findsOneWidget);
    expect(repository.variations, isEmpty);
  });

  testWidgets('a failed take keeps the current wallpaper', (tester) async {
    final repository = _FollowUpRepository()
      ..variationError = AiGenerationApiException(message: 'Worker unavailable', code: 'internal', statusCode: 500);
    await setUpPage(tester, repository: repository, aiVariationsEnabled: true, confirmedCost: 1000);
    await generateHero(tester);

    await tapChip(tester, 'night');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1400));

    expect(repository.variations, hasLength(1));
    final AiResultView result = tester.widget<AiResultView>(find.byType(AiResultView));
    expect(result.record.id, 'hero-1');
    expect(result.session.map((r) => r.id), <String>['hero-1']);
    expect(followUpChips(tester).every((PrismChip chip) => chip.onTap != null), isTrue);
    expect(tester.takeException(), isNull);
  });
}
