import 'dart:async';
import 'dart:io';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_history_strip.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_prompt_field.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_view.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_submission_result.dart';
import 'package:Prism/features/weekly_challenges/biz/challenge_admission_tracker.dart';
import 'package:Prism/features/weekly_challenges/biz/confirm_challenge_submission.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_firestore_client.dart';
import '../../support/in_memory_local_store.dart';

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService({this.online = true});
  final bool online;
  @override
  Future<bool> hasConnection() async => online;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

class _ThrowingShareTapAnalytics extends FakeAppAnalytics {
  @override
  Future<void> track(AnalyticsEvent event) {
    if (event is InviteShareTappedEvent) throw StateError('analytics unavailable');
    return super.track(event);
  }
}

class _AsyncThrowingShareTapAnalytics extends FakeAppAnalytics {
  @override
  Future<void> track(AnalyticsEvent event) {
    if (event is InviteShareTappedEvent) return Future<void>.error(StateError('analytics unavailable'));
    return super.track(event);
  }
}

class _FailingResolveOfflineAssetStore extends OfflineAssetStore {
  _FailingResolveOfflineAssetStore() : super(directory: Directory.systemTemp);

  int resolveCalls = 0;

  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) async {
    resolveCalls++;
    throw const SocketException('offline');
  }
}

class _LocalAiAssetStore extends OfflineAssetStore {
  _LocalAiAssetStore(this.file) : super(directory: file.parent);
  final File file;
  final List<String> retained = <String>[];
  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) async => file;
  @override
  Future<File> retain(String source, {File? file}) async {
    retained.add(source);
    return this.file;
  }
}

class _RecordingChallengeConfirmation extends Fake implements ConfirmChallengeSubmission {
  final List<({String uid, String challengeId, String wallId})> calls = [];
  @override
  Future<void> call({required String uid, required String challengeId, required String wallId}) async {
    calls.add((uid: uid, challengeId: challengeId, wallId: wallId));
  }
}

class _FakeAiGenerationRepository extends Fake implements AiGenerationRepositoryImpl {
  _FakeAiGenerationRepository(this.record, this.metadata, {this.history, this.savedPrompt, this.local = const []});

  final AiGenerationRecord record;
  final Completer<AiSubmissionMetadata> metadata;
  final Future<List<AiGenerationRecord>> Function()? history;
  final String? savedPrompt;
  final List<AiGenerationRecord> local;
  final List<AiGenerationRecord> savedRecords = <AiGenerationRecord>[];
  bool failHistorySave = false;

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) =>
      history?.call() ?? Future<List<AiGenerationRecord>>.value(<AiGenerationRecord>[record]);

  @override
  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async => local;

  @override
  Future<String?> loadPrompt({required String userId}) async => savedPrompt;

  @override
  Future<void> savePrompt({required String userId, required String prompt}) async {}

  @override
  Future<AiSubmissionMetadata> prefillSubmissionMetadata({
    required String generationId,
    required List<String> defaultTags,
  }) => metadata.future;

  @override
  Future<void> saveHistoryRecord(AiGenerationRecord record) async {
    savedRecords.add(record);
    if (failHistorySave) throw StateError('history save failed');
  }
}

AiGenerationRecord _record({
  String id = 'generation-1',
  String? submittedWallId,
  String userId = 'user-1',
  String imageUrl = '',
  String watermarkedImageUrl = '',
  String? format,
}) => AiGenerationRecord(
  id: id,
  userId: userId,
  createdAt: DateTime.utc(2026),
  prompt: 'A quiet mountain lake',
  format: format,
  stylePreset: AiStylePreset.nature,
  qualityTier: AiQualityTier.fast,
  provider: 'test',
  model: 'test',
  seed: 1,
  width: 720,
  height: 1280,
  imageUrl: imageUrl,
  watermarkedImageUrl: watermarkedImageUrl,
  chargeMode: AiChargeMode.freeTrial,
  coinsSpent: 0,
  status: submittedWallId == null ? 'success' : 'submitted',
  submittedWallId: submittedWallId,
);

const AiSubmissionMetadata _emptyMetadata = (title: '', description: '', category: '', tags: <String>[]);

class _EnglishLocaleDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _EnglishLocaleDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizationsEn(locale.toString());

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  bool shouldReload(_EnglishLocaleDelegate old) => false;
}

class _LocaleTestApp extends StatefulWidget {
  const _LocaleTestApp({required this.child, super.key});

  final Widget child;

  @override
  State<_LocaleTestApp> createState() => _LocaleTestAppState();
}

class _LocaleTestAppState extends State<_LocaleTestApp> {
  Locale _locale = const Locale('en');

  void setLocale(Locale locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: _locale,
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[
      const _EnglishLocaleDelegate(),
      ...AppLocalizations.localizationsDelegates.skip(1),
    ],
    supportedLocales: const <Locale>[Locale('en'), Locale('en', 'GB')],
    home: widget.child,
  );
}

Future<void> _openRecent(WidgetTester tester) async {
  final Finder thumb = find.descendant(of: find.byType(AiHistoryStrip), matching: find.byType(AiGenerationThumb)).first;
  await tester.ensureVisible(thumb);
  await tester.tap(thumb);
  await tester.pumpAndSettle();
}

void main() {
  setUp(AnalyticsRuntime.reset);
  tearDown(AnalyticsRuntime.reset);

  testWidgets('offline history uses retained records without fetching remote history', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService(online: false));
    addTearDown(getIt.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    var remoteCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(
            _record(),
            Completer<AiSubmissionMetadata>(),
            local: [_record()],
            history: () async {
              remoteCalls++;
              return [];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(remoteCalls, 0);
    expect(find.byType(AiResultView), findsNothing);
    expect(tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip)).history.first.id, 'generation-1');
    expect(tester.takeException(), isNull);
  });

  for (final success in <bool>[true, false]) {
    testWidgets('AI save ${success ? 'retains the saved image' : 'reports native failure without retaining'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
      addTearDown(getIt.reset);
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'user-1'
        ..loggedIn = true;
      addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
      final directory = Directory.systemTemp.createTempSync('ai_native_save_');
      final file = File('${directory.path}/saved.png')..writeAsBytesSync([1]);
      addTearDown(() => directory.deleteSync(recursive: true));
      final assets = _LocalAiAssetStore(file);
      const imageUrl = 'https://cdn.prism.test/ai/generated-original.png';
      const watermarkedUrl = 'https://cdn.prism.test/ai/generated-watermarked.png';
      OfflineAssetStore.testOverride = assets;
      addTearDown(() => OfflineAssetStore.testOverride = null);
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
        PrismMediaHostApi.pigeonChannelCodec,
      );
      final requests = <DownloadRequest>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
        requests.add((message! as List<Object?>).single! as DownloadRequest);
        return <Object?>[OperationResult(success: success)];
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, null));
      final messages = <String>[];
      const toast = MethodChannel('PonnamKarthik/fluttertoast');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toast, (call) async {
        if (call.method == 'showToast') messages.add((call.arguments as Map)['msg'] as String);
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toast, null));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiWallpaperTabPage(
            repository: _FakeAiGenerationRepository(
              _record(imageUrl: imageUrl, watermarkedImageUrl: watermarkedUrl),
              Completer<AiSubmissionMetadata>(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openRecent(tester);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.link, file.path);
      expect(requests.single.isLocalFile, isTrue);
      expect(assets.retained, success ? <String>[watermarkedUrl] : isEmpty);
      expect(messages, <String>[
        if (success) 'Wall downloaded in Pictures/Prism!' else AppLocalizationsEn().economyAiDownloadFailed,
      ]);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('locale changes preserve restored and explicitly generated prompts', (tester) async {
    const String savedPrompt = 'A saved prompt that should stay untouched';
    final GlobalKey<_LocaleTestAppState> appKey = GlobalKey<_LocaleTestAppState>();
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
    await tester.pumpWidget(
      _LocaleTestApp(
        key: appKey,
        child: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(
            _record(),
            Completer<AiSubmissionMetadata>(),
            history: () async => const <AiGenerationRecord>[],
            savedPrompt: savedPrompt,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder promptField = find.descendant(of: find.byType(AiPromptField), matching: find.byType(TextField));
    String promptText() => tester.widget<TextField>(promptField).controller!.text;

    expect(promptText(), savedPrompt);
    appKey.currentState!.setLocale(const Locale('en', 'GB'));
    await tester.pumpAndSettle();
    expect(promptText(), savedPrompt);

    final Finder sceneIdeaButton = find.text('Scene idea');
    await tester.ensureVisible(sceneIdeaButton);
    await tester.tap(sceneIdeaButton);
    await tester.pumpAndSettle();
    final String generatedSceneIdea = promptText();
    expect(generatedSceneIdea, isNot(savedPrompt));

    appKey.currentState!.setLocale(const Locale('en'));
    await tester.pumpAndSettle();
    expect(promptText(), generatedSceneIdea);

    const String manualPrompt = 'A prompt entered by the user';
    await tester.enterText(promptField, manualPrompt);
    appKey.currentState!.setLocale(const Locale('en', 'GB'));
    await tester.pumpAndSettle();
    expect(promptText(), manualPrompt);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed save resolution clears the saving lock so the user can retry', (tester) async {
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
    final _FailingResolveOfflineAssetStore assets = _FailingResolveOfflineAssetStore();
    OfflineAssetStore.testOverride = assets;
    addTearDown(() => OfflineAssetStore.testOverride = null);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(
            _record(imageUrl: 'https://cdn/full.png', watermarkedImageUrl: 'https://cdn/watermarked.png'),
            Completer<AiSubmissionMetadata>(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(assets.resolveCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI share is single-flight, reports the chosen image and records tap and success', (tester) async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    tester.view.physicalSize = const Size(320, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    final Completer<void> share = Completer<void>();
    var shareCalls = 0;
    String? sharedImageUrl;
    String? sharedSourceContext;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(
            _record(imageUrl: 'https://cdn/full.png', watermarkedImageUrl: 'https://cdn/watermarked.png'),
            Completer<AiSubmissionMetadata>(),
          ),
          shareSheet: (context, content, sourceContext) {
            shareCalls++;
            sharedImageUrl = content.imageUrl;
            sharedSourceContext = sourceContext;
            expect(content.link, 'https://prismwalls.com');
            expect(content.contextLine, 'Made with Prism AI');
            return shareCalls == 1 ? share.future : Future<void>.value();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    expect(tester.takeException(), isNull);
    final Finder shareButton = find.byTooltip('Share');
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.tap(shareButton, warnIfMissed: false);
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(shareCalls, 1);
    expect(sharedImageUrl, 'https://cdn/watermarked.png');
    expect(sharedSourceContext, 'ai_wallpaper');
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(analytics.events.whereType<InviteShareTappedEvent>(), hasLength(1));
    expect(analytics.events.whereType<InviteShareResultEvent>(), isEmpty);

    share.complete();
    await tester.pumpAndSettle();
    expect(analytics.events.whereType<InviteShareResultEvent>(), isEmpty);
    expect(find.byTooltip('Share'), findsOneWidget);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();
    expect(shareCalls, 2);
    expect(analytics.events.whereType<InviteShareTappedEvent>(), hasLength(2));
    expect(analytics.events.whereType<InviteShareResultEvent>(), isEmpty);
  });

  testWidgets('Duo apply opens the preview and preserves existing apply analytics', (tester) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(_record(format: 'duo-reveal'), Completer<AiSubmissionMetadata>()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    Navigator.of(tester.element(find.byType(ClockOverlay))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.byType(ClockOverlay, skipOffstage: false), findsOneWidget);
    expect(analytics.events.whereType<AiResultAppliedEvent>().map((event) => event.platform), <String>['ios']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Duo AI share opens the Duo card sheet rather than reopening preview', (tester) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    var shareCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(
            _record(
              format: 'duo-reveal',
              imageUrl: 'https://cdn/full.png',
              watermarkedImageUrl: 'https://cdn/watermarked.png',
            ),
            Completer<AiSubmissionMetadata>(),
          ),
          shareSheet: (_, content, sourceContext) async {
            shareCalls++;
            expect(content.duoReveal, isTrue);
            expect(content.contentId, 'generation-1');
            expect(content.imageUrl, 'https://cdn/watermarked.png');
            expect(content.foldedLabel, 'Folded');
            expect(content.unfoldedLabel, 'Unfolded');
            expect(content.cta, 'Get it on Prism');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    expect(find.byType(ClockOverlay), findsOneWidget);
    Navigator.of(tester.element(find.byType(ClockOverlay))).pop();
    await tester.pumpAndSettle();
    final Finder shareButton = find.byTooltip('Share');
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();
    expect(shareCalls, 1);
    expect(find.byType(ClockOverlay), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('AI share failure records failure and restores the action', (tester) async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true
      ..premium = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    final List<MethodCall> toastCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastCalls.add(call);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));

    var shareCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(
            _record(imageUrl: 'https://cdn/full.png', watermarkedImageUrl: 'https://cdn/watermarked.png'),
            Completer<AiSubmissionMetadata>(),
          ),
          shareSheet: (_, content, sourceContext) {
            shareCalls++;
            expect(content.imageUrl, 'https://cdn/full.png');
            return Future<void>.error(StateError('share unavailable'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    final Finder shareButton = find.byTooltip('Share');
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    final InviteShareResultEvent result = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(result.result, EventResultValue.failure);
    expect(result.reason, AnalyticsReasonValue.error);
    expect(analytics.events.whereType<InviteShareTappedEvent>(), hasLength(1));
    expect((toastCalls.single.arguments as Map<Object?, Object?>)['msg'], 'Could not share. Please try again.');
    expect(find.byTooltip('Share'), findsOneWidget);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();
    expect(shareCalls, 2);
    expect(analytics.events.whereType<InviteShareResultEvent>(), hasLength(2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('AI share still completes and unlocks when tap analytics throws', (tester) async {
    final analytics = _ThrowingShareTapAnalytics();
    AnalyticsRuntime.instance = analytics;
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
    var shareCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(_record(), Completer<AiSubmissionMetadata>()),
          shareSheet: (_, content, sourceContext) async {
            shareCalls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    final Finder shareButton = find.byTooltip('Share');
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(shareCalls, 1);
    expect(analytics.events.whereType<InviteShareResultEvent>(), isEmpty);
    expect(find.byTooltip('Share'), findsOneWidget);

    final asyncAnalytics = _AsyncThrowingShareTapAnalytics();
    AnalyticsRuntime.instance = asyncAnalytics;
    await tester.tap(shareButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(shareCalls, 2);
    expect(asyncAnalytics.events.whereType<InviteShareResultEvent>(), isEmpty);
    expect(find.byTooltip('Share'), findsOneWidget);
  });

  testWidgets('AI share handles asynchronous tap analytics failure', (tester) async {
    final analytics = _AsyncThrowingShareTapAnalytics();
    AnalyticsRuntime.instance = analytics;
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
    var shareCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(_record(), Completer<AiSubmissionMetadata>()),
          shareSheet: (_, content, sourceContext) async {
            shareCalls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    final Finder shareButton = find.byTooltip('Share');
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(shareCalls, 1);
    expect(analytics.events.whereType<InviteShareResultEvent>(), isEmpty);
    expect(find.byTooltip('Share'), findsOneWidget);
  });

  testWidgets('AI share completion after disposal does not report a false success', (tester) async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
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

    final Completer<void> share = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(_record(), Completer<AiSubmissionMetadata>()),
          shareSheet: (_, content, sourceContext) => share.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    final Finder shareButton = find.byTooltip('Share');
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink(),
      ),
    );
    share.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(analytics.events.whereType<InviteShareResultEvent>(), isEmpty);
    expect(analytics.events.whereType<InviteShareTappedEvent>(), hasLength(1));
  });

  test('confirmed submission remains confirmed when a refresh returns stale history', () {
    final submitted = _record(submittedWallId: 'AIWALL1');
    final stale = _record();
    final confirmed = <String, AiGenerationRecord>{submitted.id: submitted};

    expect(
      mergeAiSubmissionHistory(<AiGenerationRecord>[stale], confirmed, fetchedUserId: 'user-1').single.submittedWallId,
      'AIWALL1',
    );
    expect(
      mergeAiSubmissionHistory(<AiGenerationRecord>[], confirmed, fetchedUserId: 'user-1').single.submittedWallId,
      'AIWALL1',
    );
    expect(
      mergeAiSubmissionHistory(
        <AiGenerationRecord>[_record(userId: 'user-2')],
        confirmed,
        fetchedUserId: 'user-2',
      ).single.submittedWallId,
      isNull,
    );
    expect(canSubmitAiGeneration(submitted, currentUserId: 'user-1'), isFalse);
    expect(canSubmitAiGeneration(stale, currentUserId: 'user-1'), isTrue);
    expect(canSubmitAiGeneration(stale, currentUserId: 'user-2'), isFalse);
  });

  testWidgets('does not report a history error when the page is disposed during fetch', (tester) async {
    InMemoryLogSink.instance.clear();
    addTearDown(InMemoryLogSink.instance.clear);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    final Completer<List<AiGenerationRecord>> history = Completer<List<AiGenerationRecord>>();
    var historyRequested = false;
    final List<String> toastCalls = <String>[];
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastCalls.add(call.method);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    final user = app_state.prismUser
      ..id = 'user-1'
      ..loggedIn = true;
    app_state.prismUser = user;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(
            _record(),
            Completer<AiSubmissionMetadata>(),
            history: () {
              historyRequested = true;
              return history.future;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(historyRequested, isTrue);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink(),
      ),
    );
    history.complete(<AiGenerationRecord>[_record()]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(toastCalls, isEmpty);
    expect(InMemoryLogSink.instance.records.where((record) => record.message == 'AI history fetch failed'), isEmpty);
  });

  testWidgets('does not open submit editor after the page is disposed during metadata fetch', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);

    final AiGenerationRecord record = _record();
    final Completer<AiSubmissionMetadata> metadata = Completer<AiSubmissionMetadata>();
    final repository = _FakeAiGenerationRepository(record, metadata);
    final List<String> toastCalls = <String>[];
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastCalls.add(call.method);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    final PrismUsersV2 user = app_state.prismUser
      ..id = 'user-1'
      ..loggedIn = true;
    app_state.prismUser = user;
    addTearDown(() {
      app_state.prismUser = app_constants.createGuestPrismUser();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    expect(find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview), findsOneWidget);

    final submitButton = find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink(),
      ),
    );
    metadata.complete(_emptyMetadata);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(toastCalls, isEmpty);
  });

  testWidgets('does not submit a generation after the active account changes during metadata fetch', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    final Completer<AiSubmissionMetadata> metadata = Completer<AiSubmissionMetadata>();
    final List<String> toastCalls = <String>[];
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastCalls.add(call.method);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(repository: _FakeAiGenerationRepository(_record(), metadata)),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    final submitButton = find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-2'
      ..loggedIn = true;
    metadata.complete(_emptyMetadata);
    await tester.pump();

    expect(toastCalls, isEmpty);
  });

  testWidgets('keeps a confirmed submission disabled after history save fails and refresh is stale', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    final List<String> toastCalls = <String>[];
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastCalls.add(call.method);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    final record = _record();
    final metadata = Completer<AiSubmissionMetadata>()..complete(_emptyMetadata);
    final repository = _FakeAiGenerationRepository(record, metadata)..failHistorySave = true;
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: repository,
          submitForTesting: () async {
            submissions++;
            return WallSubmissionResult.submitted;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    final submitButton = find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().economyAiSubmitForReview));
    await tester.pumpAndSettle();

    expect(submissions, 1);
    await tester.tap(find.text(AppLocalizationsEn().aiResultEditPrompt));
    await tester.pumpAndSettle();
    final Future<void> refresh = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pumpAndSettle();
    await refresh;
    await _openRecent(tester);

    expect(find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview), findsNothing);
    expect(submissions, 1);
    expect(toastCalls, isNotEmpty);
  });

  testWidgets('history submission keeps its own challenge rather than the current form seed', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    final store = InMemoryLocalStore();
    final confirmation = _RecordingChallengeConfirmation();
    getIt.registerSingleton<ConfirmChallengeSubmission>(confirmation);
    getIt.registerSingleton<ChallengeAdmissionTracker>(ChallengeAdmissionTracker(store));
    addTearDown(getIt.reset);
    const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    final record = _record().copyWith(challengeId: '2026-10-19', challengeTheme: 'Morning light', remixOf: 'original');
    final repository = _FakeAiGenerationRepository(record, Completer<AiSubmissionMetadata>()..complete(_emptyMetadata));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(
          repository: repository,
          challengeSeed: const ChallengeSeed(id: '2026-10-26', theme: 'Quiet oceans'),
          submitForTesting: () async => WallSubmissionResult.submitted,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _openRecent(tester);
    final submit = find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(of: find.byType(PrismSheetBody), matching: find.text('Challenge · Morning light')),
      findsOneWidget,
    );
    await tester.tap(find.text(AppLocalizationsEn().economyAiSubmitForReview));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.savedRecords.single.challengeId, '2026-10-19');
    expect(confirmation.calls.single.challengeId, '2026-10-19');
    expect(confirmation.calls.single.wallId, startsWith('wall_AI'));
    expect(repository.savedRecords.single.remixOf, 'original');
    expect(store.data.keys.where((key) => key.startsWith('challenge.entry.user-1.2026-10-19.')), hasLength(1));
    expect(store.data.keys.where((key) => key.startsWith('challenge.entry.user-1.2026-10-26.')), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('quota-exceeded stays retryable but an unconfirmed submission does not', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    final List<String> toastCalls = <String>[];
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastCalls.add(call.method);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    final metadata = Completer<AiSubmissionMetadata>()..complete(_emptyMetadata);
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(_record(), metadata),
          submitForTesting: () async {
            if (submissions++ == 0) return WallSubmissionResult.quotaExceeded;
            throw StateError('write outcome is unknown');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);

    Future<void> submitOnce() async {
      final button = find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizationsEn().economyAiSubmitForReview));
      await tester.pumpAndSettle();
    }

    await submitOnce();
    expect(find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview), findsOneWidget);
    await submitOnce();
    expect(find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview), findsNothing);
    expect(find.textContaining('Submission status is unconfirmed'), findsOneWidget);
    expect(submissions, 2);
    expect(toastCalls, isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('does not apply a completed submission to a newly active account', (tester) async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    final Completer<AiSubmissionMetadata> metadata = Completer<AiSubmissionMetadata>()..complete(_emptyMetadata);
    final Completer<WallSubmissionResult> submission = Completer<WallSubmissionResult>();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(_record(), metadata),
          submitForTesting: () => submission.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    final submitButton = find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().economyAiSubmitForReview));
    await tester.pump();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-2'
      ..loggedIn = true;
    submission.complete(WallSubmissionResult.submitted);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview), findsNothing);
    expect(analytics.events.whereType<AiSubmitStartedEvent>(), hasLength(1));
    expect(analytics.events.whereType<AiSubmitSuccessEvent>(), hasLength(1));
  });

  testWidgets('persists confirmed submission history if the page is disposed during the write', (tester) async {
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
    final repository = _FakeAiGenerationRepository(
      _record(),
      Completer<AiSubmissionMetadata>()..complete(_emptyMetadata),
    );
    final Completer<WallSubmissionResult> submission = Completer<WallSubmissionResult>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(repository: repository, submitForTesting: () => submission.future),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecent(tester);
    final submitButton = find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().economyAiSubmitForReview));
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink(),
      ),
    );
    submission.complete(WallSubmissionResult.submitted);
    await tester.pump();

    expect(repository.savedRecords.single.submittedWallId, 'AI26B598D3D55679CADFAA60FFA00EAAE58');
  });

  testWidgets('real AI submit writes backend identity and current premium image across premium transitions', (
    tester,
  ) async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(AnalyticsRuntime.reset);
    addTearDown(getIt.reset);
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    final List<Object?> toastArguments = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      toastArguments.add(call.arguments);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    const generation = 'gen_mlt7o22q_7a9688a037a47de6';
    const originalUrl = 'https://prismwalls.com/api/ai/assets/ai/original/$generation.png';
    const previewUrl = 'https://prismwalls.com/api/ai/assets/ai/public/$generation.png';

    for (final (bool initialPremium, bool confirmationPremium) in <(bool, bool)>[
      (true, false),
      (true, true),
      (false, false),
      (false, true),
    ]) {
      await getIt.reset();
      getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
      final firestore = FakeFirestoreClient();
      final localStore = InMemoryLocalStore();
      final confirmation = _RecordingChallengeConfirmation();
      getIt.registerSingleton<ConfirmChallengeSubmission>(confirmation);
      getIt.registerSingleton<ChallengeAdmissionTracker>(ChallengeAdmissionTracker(localStore));
      getIt.registerSingleton<FirestoreClient>(firestore);
      getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(localStore));
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'user-1'
        ..email = 'maker@example.com'
        ..loggedIn = true
        ..premium = initialPremium;
      toastArguments.clear();
      final repository = _FakeAiGenerationRepository(
        _record(id: generation, imageUrl: originalUrl, watermarkedImageUrl: previewUrl).copyWith(
          challengeId: initialPremium && confirmationPremium ? '2026-10-26' : null,
          challengeTheme: initialPremium && confirmationPremium ? 'Quiet oceans' : null,
        ),
        Completer<AiSubmissionMetadata>()..complete(_emptyMetadata),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiWallpaperTabPage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await _openRecent(tester);
      final submitButton = find.bySemanticsLabel(AppLocalizationsEn().economyAiSubmitForReview);
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      app_state.prismUser.premium = confirmationPremium;
      await tester.tap(find.text(AppLocalizationsEn().economyAiSubmitForReview));
      await tester.pumpAndSettle();

      final wallWrites = firestore.writes.where((write) => write.collection == 'walls').toList();
      expect(
        wallWrites,
        hasLength(1),
        reason: '$initialPremium -> $confirmationPremium: quota=${localStore.data}, toasts=$toastArguments',
      );
      final wall = wallWrites.single.data!;
      expect(wall['id'], 'AI2B83C297CF7C420FF33FA03823705EA95');
      if (initialPremium && confirmationPremium) {
        expect(wall['challengeId'], '2026-10-26');
        expect(wallWrites.single.id, 'wall_AI2B83C297CF7C420FF33FA03823705EA95');
        expect(confirmation.calls.single.wallId, wallWrites.single.id);
      } else {
        expect(wall.containsKey('challengeId'), isFalse);
      }
      expect(wall['aiGenerationId'], generation);
      expect(wall['isAiGenerated'], true);
      expect(wall['wallpaper_url'], confirmationPremium ? originalUrl : previewUrl);
      expect(wall['wallpaper_thumb'], previewUrl);
      expect(repository.savedRecords.single.submittedWallId, 'AI2B83C297CF7C420FF33FA03823705EA95');

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    }
  });
}
