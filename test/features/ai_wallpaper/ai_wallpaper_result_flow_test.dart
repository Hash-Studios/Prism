// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_history_strip.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_prompt_field.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_actions.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_view.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/wait_for_real_io.dart';

const String _heroPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

const MethodChannel _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

const Map<String, Object> _coinReply = <String, Object>{
  'success': true,
  'changed': true,
  'currentBalance': 90,
  'delta': -10,
  'transactionId': 'reservation-1',
};

typedef _Counts = ({int generate, int variation, int history, int localHistory, int resolves, int lookups});

class _FakeConnectivityService implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

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
  Future<dynamic> call([dynamic parameters]) => functions.onCall(name!, parameters);
}

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

class _FakeAssetStore extends OfflineAssetStore {
  _FakeAssetStore(this.file, {this.failResolve = false}) : super(directory: file.parent);

  final File file;
  final bool failResolve;
  Completer<File>? resolveGate;
  int resolves = 0;
  int lookups = 0;

  @override
  Future<File?> lookup(String source) async {
    lookups++;
    return file;
  }

  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) async {
    resolves++;
    if (failResolve) throw const SocketException('offline');
    if (resolveGate != null) return resolveGate!.future;
    return file;
  }

  @override
  Future<File> retain(String source, {File? file}) async => this.file;
}

class _InMemoryCopyFile extends Fake implements File {
  _InMemoryCopyFile(this.path);

  @override
  final String path;

  @override
  Future<File> copy(String newPath) async => File(newPath);
}

class _CountingAiGenerationRepository extends Fake implements AiGenerationRepositoryImpl {
  int generateCalls = 0;
  int variationCalls = 0;
  int fetchHistoryCalls = 0;
  int fetchLocalHistoryCalls = 0;
  final Map<String, String> prompts = <String, String>{};

  @override
  Future<String?> loadPrompt({required String userId}) async => prompts[userId];

  @override
  Future<void> savePrompt({required String userId, required String prompt}) async {
    prompts[userId] = prompt;
  }

  @override
  Future<void> clearForUser(String userId) async {
    prompts.remove(userId);
  }

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async {
    fetchHistoryCalls++;
    return <AiGenerationRecord>[];
  }

  @override
  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async {
    fetchLocalHistoryCalls++;
    return <AiGenerationRecord>[];
  }

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
  }) async {
    generateCalls++;
    return _take('take-$generateCalls');
  }

  @override
  Future<AiGenerationRecord> generateVariation({
    required String generationId,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    String variationPrompt = '',
    double strength = 0.45,
    String? chargeTxId,
    String? remixOf,
  }) async {
    variationCalls++;
    return _take('variation-$variationCalls');
  }
}

AiGenerationRecord _take(String id) => AiGenerationRecord(
  id: id,
  userId: 'user-1',
  createdAt: DateTime.utc(2026),
  prompt: 'A glass lighthouse at dawn',
  stylePreset: AiStylePreset.nature,
  qualityTier: AiQualityTier.fast,
  provider: 'test',
  model: 'test',
  seed: 1,
  width: 720,
  height: 1280,
  imageUrl: 'https://cdn.prism.test/$id.png',
  watermarkedImageUrl: 'https://cdn.prism.test/$id-watermarked.png',
  chargeMode: AiChargeMode.freeTrial,
  coinsSpent: 0,
  status: 'success',
);

late _FakeFunctionsPlatform functions;
late Directory tempDir;
late File heroFile;
late FakeAppAnalytics analytics;
late SettingsLocalDataSource settings;
final List<String> toastMessages = <String>[];

_Counts _counts(_CountingAiGenerationRepository repository, _FakeAssetStore store) => (
  generate: repository.generateCalls,
  variation: repository.variationCalls,
  history: repository.fetchHistoryCalls,
  localHistory: repository.fetchLocalHistoryCalls,
  resolves: store.resolves,
  lookups: store.lookups,
);

Future<void> _onPlatform(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpPage(WidgetTester tester, _CountingAiGenerationRepository repository) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await getIt.reset();
  getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
  settings = SettingsLocalDataSource(InMemoryLocalStore());
  getIt.registerSingleton<SettingsLocalDataSource>(settings);
  functions.onCall = (name, parameters) async => _coinReply;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, (call) async {
    if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
    return true;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, null));
  app_state.prismUser = app_constants.createGuestPrismUser()
    ..id = 'user-1'
    ..coins = 100
    ..loggedIn = true;
  CoinsService.instance.balanceNotifier.value = 100;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AiWallpaperTabPage(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _typePrompt(WidgetTester tester, String prompt) async {
  await tester.enterText(_promptField(), prompt);
  await tester.pump();
}

Finder _promptField() => find.descendant(of: find.byType(AiPromptField), matching: find.byType(TextField));

Future<void> _generate(WidgetTester tester) async {
  final Finder generate = find.text('Generate');
  await tester.ensureVisible(generate);
  await tester.tap(generate);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _editPrompt(WidgetTester tester) async {
  await tester.tap(find.text('Edit prompt'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _sessionThumb(String id) =>
    find.descendant(of: find.byType(AiResultView), matching: find.byKey(ValueKey<String>(id)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    functions = _FakeFunctionsPlatform(null, 'asia-south1', (name, parameters) async => _coinReply);
    FirebaseFunctionsPlatform.instance = functions;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ai_result_flow_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    heroFile = File('${tempDir.path}/hero.png')..writeAsBytesSync(base64Decode(_heroPngBase64));
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    toastMessages.clear();
    IosWallpaperGuideSession.shown = false;
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    OfflineAssetStore.testOverride = null;
    IosWallpaperGuideSession.shown = false;
    await getIt.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('a finished wallpaper fills the screen and Edit prompt returns to the prompt', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final repository = _CountingAiGenerationRepository();
      OfflineAssetStore.testOverride = _FakeAssetStore(heroFile);
      await _pumpPage(tester, repository);
      const String typed = 'A glass lighthouse at dawn';
      await _typePrompt(tester, typed);

      await _generate(tester);
      expect(tester.widget<AiResultView>(find.byType(AiResultView)).record.id, 'take-1');
      expect(find.byType(AiPromptField).hitTestable(), findsNothing);

      await _editPrompt(tester);
      expect(find.byType(AiResultView), findsNothing);
      expect(find.byType(AiPromptField).hitTestable(), findsOneWidget);
      expect(tester.widget<TextField>(_promptField()).controller!.text, typed);
    });
  });

  testWidgets('result text has the theme style, not the no-Material fallback', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      OfflineAssetStore.testOverride = _FakeAssetStore(heroFile);
      await _pumpPage(tester, _CountingAiGenerationRepository());
      await _typePrompt(tester, 'A glass lighthouse at dawn');
      await _generate(tester);

      final Iterable<RichText> texts = tester.widgetList<RichText>(
        find.descendant(of: find.byType(AiResultView), matching: find.byType(RichText)),
      );
      expect(
        texts.map((RichText t) => t.text.toPlainText()),
        containsAll(<String>['Edit prompt', '90', '10', 'Night version']),
      );
      for (final RichText text in texts) {
        expect(
          text.text.style?.decoration ?? TextDecoration.none,
          TextDecoration.none,
          reason: text.text.toPlainText(),
        );
      }
    });
  });

  testWidgets('Edit prompt and the coin balance sit at the top of the result', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      OfflineAssetStore.testOverride = _FakeAssetStore(heroFile);
      await _pumpPage(tester, _CountingAiGenerationRepository());
      tester.view.physicalSize = const Size(320, 2200);
      await _typePrompt(tester, 'A glass lighthouse at dawn');
      await _generate(tester);

      final Finder result = find.byType(AiResultView);
      final Finder coins = find.descendant(of: result, matching: find.byType(CoinBalanceChip));
      expect(tester.getRect(find.descendant(of: result, matching: find.text('Edit prompt'))).bottom, lessThan(60));
      expect(tester.getSize(coins).height, 44);
      expect(tester.getRect(coins).top, lessThan(60));
      expect(tester.getRect(coins).right, lessThanOrEqualTo(tester.view.physicalSize.width));
    });
  });

  testWidgets('result transition fades and scales while compose is excluded, then restores on close', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        OfflineAssetStore.testOverride = _FakeAssetStore(heroFile);
        await _pumpPage(tester, _CountingAiGenerationRepository());
        const String prompt = 'A glass lighthouse at dawn';
        await _typePrompt(tester, prompt);
        final SemanticsFinder promptSemantics = find.semantics.byValue(prompt);
        expect(promptSemantics, findsOne);
        final Finder generate = find.text('Generate');
        await tester.ensureVisible(generate);
        await tester.tap(generate);
        await waitForRealIo(
          tester,
          () => find.byType(AiResultView).evaluate().isNotEmpty,
          reason: 'the generated result to enter the page',
          pumpDuration: const Duration(milliseconds: 16),
        );
        await tester.pump(const Duration(milliseconds: 80));

        final Finder result = find.byType(AiResultView);
        expect(result, findsOneWidget);
        final double enteringOpacity = tester
            .widget<FadeTransition>(find.ancestor(of: result, matching: find.byType(FadeTransition)).first)
            .opacity
            .value;
        final double enteringScale = tester
            .widget<ScaleTransition>(find.ancestor(of: result, matching: find.byType(ScaleTransition)).first)
            .scale
            .value;
        expect(enteringOpacity, greaterThan(0));
        expect(enteringOpacity, lessThan(1));
        expect(enteringScale, greaterThan(0.96));
        expect(enteringScale, lessThan(1));
        expect(find.byType(AiPromptField).hitTestable(), findsNothing);
        expect(promptSemantics, findsNothing);

        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Edit prompt'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        expect(result, findsOneWidget);
        final double exitingOpacity = tester
            .widget<FadeTransition>(find.ancestor(of: result, matching: find.byType(FadeTransition)).first)
            .opacity
            .value;
        final double exitingScale = tester
            .widget<ScaleTransition>(find.ancestor(of: result, matching: find.byType(ScaleTransition)).first)
            .scale
            .value;
        expect(exitingOpacity, greaterThan(0));
        expect(exitingOpacity, lessThan(1));
        expect(exitingScale, greaterThan(0.96));
        expect(exitingScale, lessThan(1));

        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AiResultView), findsNothing);
        expect(find.byType(AiPromptField).hitTestable(), findsOneWidget);
        expect(promptSemantics, findsOne);
        await tester.pump(const Duration(seconds: 2));
      } finally {
        semantics.dispose();
      }
    });
  });

  testWidgets('system back on a result returns to the prompt without leaving the page', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final repository = _CountingAiGenerationRepository();
      OfflineAssetStore.testOverride = _FakeAssetStore(heroFile);
      await _pumpPage(tester, repository);

      await _generate(tester);
      expect(find.byType(AiResultView), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AiResultView), findsNothing);
      expect(find.byType(AiPromptField).hitTestable(), findsOneWidget);
      expect(find.byType(AiWallpaperTabPage), findsOneWidget);
    });
  });

  testWidgets('the session strip holds this session in order and a tap swaps the hero without a fetch', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final repository = _CountingAiGenerationRepository();
      final store = _FakeAssetStore(heroFile);
      OfflineAssetStore.testOverride = store;
      await _pumpPage(tester, repository);

      await _generate(tester);
      await _editPrompt(tester);
      await _generate(tester);
      await _editPrompt(tester);
      await _generate(tester);

      final AiResultView result = tester.widget<AiResultView>(find.byType(AiResultView));
      expect(result.session.map((AiGenerationRecord take) => take.id).toList(), <String>['take-1', 'take-2', 'take-3']);
      expect(result.record.id, 'take-3');
      expect(
        find.descendant(of: find.byType(AiResultView), matching: find.byType(AiGenerationThumb)),
        findsNWidgets(3),
      );

      final _Counts before = _counts(repository, store);
      await tester.tap(_sessionThumb('take-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.widget<AiResultView>(find.byType(AiResultView)).record.id, 'take-1');
      final List<AiStripSwappedEvent> swaps = analytics.events.whereType<AiStripSwappedEvent>().toList();
      expect(swaps, hasLength(1));
      expect(swaps.single.position, 0);
      expect(swaps.single.count, 3);

      expect(_counts(repository, store).generate, before.generate, reason: 'a swap must not generate');
      expect(_counts(repository, store).variation, before.variation, reason: 'a swap must not vary');
      expect(_counts(repository, store).history, before.history, reason: 'a swap must not fetch history');
      expect(
        _counts(repository, store).localHistory,
        before.localHistory,
        reason: 'a swap must not read local history',
      );
      expect(_counts(repository, store).resolves, before.resolves, reason: 'a swap must not download the image');

      await tester.tap(_sessionThumb('take-3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final _Counts afterFirstVisit = _counts(repository, store);
      await tester.tap(_sessionThumb('take-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<AiResultView>(find.byType(AiResultView)).record.id, 'take-1');
      expect(_counts(repository, store).resolves, afterFirstVisit.resolves, reason: 'a swap back must not download');
      expect(
        _counts(repository, store).lookups,
        afterFirstVisit.lookups,
        reason: 'a swap back reuses the decoded take',
      );
    });
  });

  testWidgets('one result shows no strip', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final repository = _CountingAiGenerationRepository();
      OfflineAssetStore.testOverride = _FakeAssetStore(heroFile);
      await _pumpPage(tester, repository);

      await _generate(tester);

      expect(tester.widget<AiResultView>(find.byType(AiResultView)).session, hasLength(1));
      expect(find.descendant(of: find.byType(AiResultView), matching: find.byType(AiGenerationThumb)), findsNothing);
    });
  });

  testWidgets('Apply on Android opens the Set screen with this wall', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final List<SetScreenRequest> opened = <SetScreenRequest>[];
      final originalOpener = SetWallpaperFlow.screenOpener;
      SetWallpaperFlow.screenOpener = (BuildContext context, SetScreenRequest request) async {
        opened.add(request);
        return null;
      };
      addTearDown(() => SetWallpaperFlow.screenOpener = originalOpener);
      final repository = _CountingAiGenerationRepository();
      OfflineAssetStore.testOverride = _FakeAssetStore(heroFile);
      await _pumpPage(tester, repository);
      await settings.set(PersistenceKeys.defaultApplyTarget, 'home');

      await _generate(tester);
      await tester.tap(find.text('Apply'));
      await waitForRealIo(tester, () => opened.length == 1, reason: 'the Set screen request');
      await tester.pump(const Duration(milliseconds: 400));

      expect(opened, hasLength(1));
      expect(opened.single.url, startsWith(tempDir.path));
      expect(opened.single.wallpaperSource, WallpaperSource.downloaded);
      final List<AiResultAppliedEvent> applied = analytics.events.whereType<AiResultAppliedEvent>().toList();
      expect(applied, hasLength(1));
      expect(applied.single.platform, 'android');
      expect(applied.single.from, AiApplyFromValue.hero);

      await _editPrompt(tester);
      await _generate(tester);
      expect(tester.widget<AiResultView>(find.byType(AiResultView)).record.id, 'take-2');
      await tester.tap(_sessionThumb('take-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<AiResultView>(find.byType(AiResultView)).record.id, 'take-1');

      await tester.tap(find.text('Apply'));
      await waitForRealIo(tester, () => opened.length == 2, reason: 'the second Set screen request');
      await tester.pump(const Duration(milliseconds: 400));

      expect(opened, hasLength(2));
      expect(opened.last.url, startsWith(tempDir.path));
      final List<AiResultAppliedEvent> appliedAgain = analytics.events.whereType<AiResultAppliedEvent>().toList();
      expect(appliedAgain, hasLength(2));
      expect(appliedAgain.last.platform, 'android');
      expect(appliedAgain.last.from, AiApplyFromValue.strip);
    });
  });

  for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.iOS]) {
    for (final bool returnToOriginalOwner in <bool>[false, true]) {
      testWidgets('Apply on ${platform.name} stops after an owner ${returnToOriginalOwner ? 'round trip' : 'change'}', (
        tester,
      ) async {
        await _onPlatform(platform, () async {
          final List<SetScreenRequest> opened = <SetScreenRequest>[];
          final originalOpener = SetWallpaperFlow.screenOpener;
          SetWallpaperFlow.screenOpener = (BuildContext context, SetScreenRequest request) async {
            opened.add(request);
            return null;
          };
          addTearDown(() => SetWallpaperFlow.screenOpener = originalOpener);
          const BasicMessageChannel<Object?> downloadChannel = BasicMessageChannel<Object?>(
            'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
            PrismMediaHostApi.pigeonChannelCodec,
          );
          final List<DownloadRequest> downloads = <DownloadRequest>[];
          tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(downloadChannel, (message) async {
            downloads.add((message! as List<Object?>).single! as DownloadRequest);
            return <Object?>[OperationResult(success: true)];
          });
          addTearDown(
            () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(downloadChannel, null),
          );
          final _FakeAssetStore store = _FakeAssetStore(heroFile)..resolveGate = Completer<File>();
          OfflineAssetStore.testOverride = store;
          await _pumpPage(tester, _CountingAiGenerationRepository());
          await _generate(tester);
          toastMessages.clear();
          await tester.tap(find.text('Apply'));
          await tester.pump();
          expect(store.resolves, 1);
          expect(tester.widget<AiResultActions>(find.byType(AiResultActions)).applying, isTrue);

          app_state.prismUser = app_constants.createGuestPrismUser()
            ..id = 'user-2'
            ..loggedIn = true;
          CoinsService.instance.resetSession();
          if (returnToOriginalOwner) {
            app_state.prismUser = app_constants.createGuestPrismUser()
              ..id = 'user-1'
              ..loggedIn = true;
            CoinsService.instance.resetSession();
          }
          store.resolveGate!.complete(_InMemoryCopyFile(heroFile.path));
          await tester.pumpAndSettle();

          expect(opened, isEmpty, reason: 'an old account action must not open the Set screen');
          expect(downloads, isEmpty, reason: 'an old account action must not save to Photos');
          expect(find.byType(IosWallpaperGuideSheet), findsNothing);
          expect(toastMessages, isEmpty);
          if (find.byType(AiResultActions).evaluate().isNotEmpty) {
            expect(tester.widget<AiResultActions>(find.byType(AiResultActions)).applying, isFalse);
          }
          await tester.pump(const Duration(seconds: 2));
        });
      });
    }
  }

  testWidgets('a same-owner Save continues after the AI page closes', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      const BasicMessageChannel<Object?> downloadChannel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
        PrismMediaHostApi.pigeonChannelCodec,
      );
      final List<DownloadRequest> downloads = <DownloadRequest>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(downloadChannel, (message) async {
        downloads.add((message! as List<Object?>).single! as DownloadRequest);
        return <Object?>[OperationResult(success: true)];
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(downloadChannel, null),
      );
      final _FakeAssetStore store = _FakeAssetStore(heroFile)..resolveGate = Completer<File>();
      OfflineAssetStore.testOverride = store;
      await _pumpPage(tester, _CountingAiGenerationRepository());
      await _generate(tester);
      await tester.tap(find.byTooltip(AppLocalizationsEn().economyAiSave));
      await tester.pump();
      expect(store.resolves, 1);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      store.resolveGate!.complete(_InMemoryCopyFile(heroFile.path));
      await tester.pumpAndSettle();

      expect(downloads, hasLength(1), reason: 'closing the page must not cancel an authorized same-owner Save');
      expect(downloads.single.link, heroFile.path);
      expect(find.byType(IosWallpaperGuideSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  testWidgets('Apply with an image that will not download shows an error and opens nothing', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final List<SetScreenRequest> opened = <SetScreenRequest>[];
      final originalOpener = SetWallpaperFlow.screenOpener;
      SetWallpaperFlow.screenOpener = (BuildContext context, SetScreenRequest request) async {
        opened.add(request);
        return null;
      };
      addTearDown(() => SetWallpaperFlow.screenOpener = originalOpener);
      final repository = _CountingAiGenerationRepository();
      final store = _FakeAssetStore(heroFile, failResolve: true);
      OfflineAssetStore.testOverride = store;
      await _pumpPage(tester, repository);

      await _generate(tester);
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.resolves, 1);
      expect(opened, isEmpty);
      expect(toastMessages, contains(AppLocalizationsEn().economyAiNoConnection));
      await tester.pump(const Duration(seconds: 2));
    });
  });

  testWidgets('Apply on iOS saves to Photos, then shows the set guide', (tester) async {
    await _onPlatform(TargetPlatform.iOS, () async {
      final List<SetScreenRequest> opened = <SetScreenRequest>[];
      final originalOpener = SetWallpaperFlow.screenOpener;
      SetWallpaperFlow.screenOpener = (BuildContext context, SetScreenRequest request) async {
        opened.add(request);
        return null;
      };
      addTearDown(() => SetWallpaperFlow.screenOpener = originalOpener);
      const BasicMessageChannel<Object?> downloadChannel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
        PrismMediaHostApi.pigeonChannelCodec,
      );
      final List<DownloadRequest> downloads = <DownloadRequest>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(downloadChannel, (message) async {
        downloads.add((message! as List<Object?>).single! as DownloadRequest);
        return <Object?>[OperationResult(success: true)];
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(downloadChannel, null),
      );
      final repository = _CountingAiGenerationRepository();
      OfflineAssetStore.testOverride = _FakeAssetStore(heroFile);
      await _pumpPage(tester, repository);

      await _generate(tester);
      expect(find.byTooltip(AppLocalizationsEn().economyAiSave), findsNothing);
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(downloads, hasLength(1));
      expect(downloads.single.link, heroFile.path);
      expect(downloads.single.isLocalFile, isTrue);
      expect(find.byType(IosWallpaperGuideSheet), findsOneWidget);
      expect(find.text(AppLocalizationsEn().coreSetItAsWallpaper), findsOneWidget);
      expect(opened, isEmpty);
      final List<AiResultAppliedEvent> applied = analytics.events.whereType<AiResultAppliedEvent>().toList();
      expect(applied.single.platform, 'ios');
      await tester.pump(const Duration(seconds: 2));
    });
  });

  testWidgets('Android shows Save next to Apply', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final repository = _CountingAiGenerationRepository();
      OfflineAssetStore.testOverride = _FakeAssetStore(heroFile);
      await _pumpPage(tester, repository);

      await _generate(tester);

      expect(find.byTooltip(AppLocalizationsEn().economyAiSave).hitTestable(), findsOneWidget);
    });
  });
}
