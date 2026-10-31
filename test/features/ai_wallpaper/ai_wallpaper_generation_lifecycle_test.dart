import 'dart:async';
import 'dart:convert';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_history_strip.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_remix_chip.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_view.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_firestore_client.dart';
import '../../support/in_memory_local_store.dart';

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService({this.check});

  final Future<bool> Function()? check;

  @override
  Future<bool> hasConnection() => check?.call() ?? Future<bool>.value(true);

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

class _RecordingAnalytics extends FakeAppAnalytics {
  _RecordingAnalytics({this.throwOn});

  final bool Function(AnalyticsEvent event)? throwOn;

  @override
  Future<void> track(AnalyticsEvent event) {
    events.add(event);
    if (throwOn?.call(event) ?? false) throw StateError('analytics failed');
    return Future<void>.value();
  }
}

class _FakeAiGenerationRepository extends Fake implements AiGenerationRepositoryImpl {
  _FakeAiGenerationRepository(
    this.record, {
    this.generation,
    this.variation,
    this.localHistory,
    this.history,
    this.historyForUser,
    this.submissionMetadata,
  });

  final AiGenerationRecord record;
  final Future<AiGenerationRecord> Function()? generation;
  final Future<AiGenerationRecord> Function()? variation;
  final Future<List<AiGenerationRecord>> Function()? localHistory;
  final Future<List<AiGenerationRecord>> Function()? history;
  final Future<List<AiGenerationRecord>> Function(String userId)? historyForUser;
  final AiSubmissionMetadata? submissionMetadata;
  final List<({AiStylePreset style, AiQualityTier quality, int coinsSpent})> requests = [];
  final List<String?> chargeTxIds = <String?>[];
  final List<String?> remixOfValues = <String?>[];
  final Map<String, String> prompts = <String, String>{};
  final List<AiGenerationRecord> savedHistoryRecords = <AiGenerationRecord>[];

  @override
  Future<String?> loadPrompt({required String userId}) async => prompts[userId];

  @override
  Future<void> savePrompt({required String userId, required String prompt}) async {
    prompts[userId] = prompt;
  }

  @override
  Future<void> saveHistoryRecord(AiGenerationRecord record) async => savedHistoryRecords.add(record);

  @override
  Future<AiSubmissionMetadata> prefillSubmissionMetadata({
    required String generationId,
    required List<String> defaultTags,
  }) async {
    final AiSubmissionMetadata? metadata = submissionMetadata;
    if (metadata == null) return (title: 'Remix', description: '', category: 'Nature', tags: defaultTags);
    return (
      title: metadata.title,
      description: metadata.description,
      category: metadata.category,
      tags: metadata.tags.isEmpty ? defaultTags : metadata.tags,
    );
  }

  @override
  Future<void> clearForUser(String userId) async {
    prompts.remove(userId);
  }

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async =>
      historyForUser != null
      ? await historyForUser!(userId)
      : history == null
      ? <AiGenerationRecord>[record]
      : await history!();

  @override
  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async =>
      localHistory == null ? const <AiGenerationRecord>[] : await localHistory!();

  @override
  Future<AiGenerationRecord> generate({
    required String prompt,
    required AiStylePreset stylePreset,
    required AiQualityTier qualityTier,
    required String targetSize,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    int? seed,
    String? format,
    String? foldedPrompt,
    String? revealedPrompt,
    String? chargeTxId,
    String? remixOf,
  }) {
    requests.add((style: stylePreset, quality: qualityTier, coinsSpent: coinsSpent));
    chargeTxIds.add(chargeTxId);
    remixOfValues.add(remixOf);
    return generation!().then((AiGenerationRecord record) {
      final AiGenerationRecord linked = remixOf == null ? record : record.copyWith(remixOf: remixOf);
      savedHistoryRecords.add(linked);
      return linked;
    });
  }

  @override
  Future<AiGenerationRecord> generateVariation({
    required String generationId,
    AiGenerationRecord? originalRecord,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    String variationPrompt = '',
    double strength = 0.45,
    String? chargeTxId,
    String? remixOf,
  }) {
    chargeTxIds.add(chargeTxId);
    remixOfValues.add(remixOf);
    return variation!().then((AiGenerationRecord record) {
      final AiGenerationRecord linked = remixOf == null ? record : record.copyWith(remixOf: remixOf);
      savedHistoryRecords.add(linked);
      return linked;
    });
  }
}

class _StreamSessionRepository extends Fake implements SessionRepository {
  _StreamSessionRepository(this._currentUser);

  PrismUsersV2 _currentUser;
  final StreamController<PrismUsersV2> _users = StreamController<PrismUsersV2>.broadcast();

  @override
  PrismUsersV2 get currentUser => _currentUser;

  @override
  Stream<PrismUsersV2> watchCurrentUser() async* {
    yield _currentUser;
    yield* _users.stream;
  }

  @override
  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 user) async {
    _currentUser = user;
    _users.add(user);
    return Result.success<SessionEntity>(
      SessionEntity(
        userId: user.id,
        loggedIn: user.loggedIn,
        premium: user.premium,
        subscriptionTier: user.subscriptionTier,
      ),
    );
  }

  @override
  Future<Result<SessionEntity>> getSession() async => Result.success<SessionEntity>(
    SessionEntity(
      userId: _currentUser.id,
      loggedIn: _currentUser.loggedIn,
      premium: _currentUser.premium,
      subscriptionTier: _currentUser.subscriptionTier,
    ),
  );

  @override
  Future<Result<SessionEntity>> updateFollowing(List<String> following) => getSession();

  Future<void> dispose() => _users.close();
}

class _MemoryAiStore extends Fake implements DurableJsonStore {
  final Map<String, Map<String, Object?>> records = {};

  @override
  Future<Map<String, Object?>?> read(String key) async => records[key];

  @override
  Future<Map<String, Map<String, Object?>>> readAll() async => Map.of(records);

  @override
  Future<void> write(String key, Map<String, Object?> value) async => records[key] = Map.of(value);

  @override
  Future<void> delete(String key) async => records.remove(key);
}

class _HistorySnapshotFirestore extends FakeFirestoreClient {
  bool delayQueries = false;
  final List<Completer<List<FakeDocRow>>> pending = [];

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    if (!delayQueries) return super.query(spec, map);
    final snapshot = Completer<List<FakeDocRow>>();
    pending.add(snapshot);
    return (await snapshot.future).map((row) => map(row.data, row.id)).toList();
  }
}

class _GenerationUser extends Fake implements User {
  @override
  String get uid => 'user-1';

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'token';
}

class _GenerationAuth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _GenerationUser();
}

class _FailingLiveActivityApi extends PrismLiveActivityHostApi {
  @override
  Future<String?> startAiGeneration(AiActivityRequest request) async => throw StateError('host failed');
}

class _RecordingLiveActivityApi extends PrismLiveActivityHostApi {
  final List<String> calls = <String>[];
  final Completer<void> startEntered = Completer<void>();
  Completer<String?>? startGate;
  int starts = 0;

  @override
  Future<String?> startAiGeneration(AiActivityRequest request) {
    starts++;
    if (!startEntered.isCompleted) startEntered.complete();
    return startGate?.future ?? Future<String?>.value('activity-$starts');
  }

  @override
  Future<void> finishAiGeneration(String activityId, String imageUrl) async {
    calls.add('finish:$activityId:$imageUrl');
  }

  @override
  Future<void> failAiGeneration(String activityId, String detail) async {
    calls.add('fail:$activityId');
  }

  @override
  Future<void> cancelAiGeneration(String activityId) async {
    calls.add('cancel:$activityId');
  }
}

AiGenerationRecord _record({
  String id = 'generation-1',
  String userId = 'user-1',
  String prompt = 'A quiet mountain lake',
  AiStylePreset stylePreset = AiStylePreset.nature,
  String? remixOf,
  int width = 720,
  int height = 1280,
}) => AiGenerationRecord(
  id: id,
  userId: userId,
  createdAt: DateTime.utc(2026),
  prompt: prompt,
  stylePreset: stylePreset,
  qualityTier: AiQualityTier.fast,
  provider: 'test',
  model: 'test',
  seed: 1,
  width: width,
  height: height,
  imageUrl: '',
  watermarkedImageUrl: '',
  chargeMode: AiChargeMode.freeTrial,
  coinsSpent: 0,
  status: 'success',
  remixOf: remixOf,
);

Future<void> openFirstRecent(WidgetTester tester) async {
  final Finder thumb = find.descendant(of: find.byType(AiHistoryStrip), matching: find.byType(AiGenerationThumb)).first;
  await tester.ensureVisible(thumb);
  await tester.tap(thumb);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late _FakeFunctionsPlatform functions;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    functions = _FakeFunctionsPlatform(null, 'asia-south1', (name, parameters) async => <String, Object>{});
    FirebaseFunctionsPlatform.instance = functions;
  });

  Future<void> setUpPage(
    WidgetTester tester,
    Future<dynamic> Function(String, dynamic) onCall, {
    AiGenerationRepositoryImpl? repository,
    FirestoreClient? firestore,
    ConnectivityService? connectivity,
    List<MethodCall>? toastCalls,
    bool disableAnimations = false,
    AiRemixSeed? remixSeed,
    SessionRepository? sessionRepository,
  }) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await getIt.reset();
    getIt.registerSingleton<ConnectivityService>(connectivity ?? _FakeConnectivityService());
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    if (sessionRepository != null) getIt.registerSingleton<SessionRepository>(sessionRepository);
    if (firestore != null) getIt.registerSingleton<FirestoreClient>(firestore);
    functions.onCall = onCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastCalls?.add(call);
      return true;
    });
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..coins = 100
      ..loggedIn = true;
    CoinsService.instance.balanceNotifier.value = 100;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData.fromView(tester.view).copyWith(disableAnimations: disableAnimations),
          child: AiWallpaperTabPage(
            repository: repository ?? _FakeAiGenerationRepository(_record()),
            remixSeed: remixSeed,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  testWidgets('stale remote history cannot hide a completed generation after its local record is synced', (
    tester,
  ) async {
    final store = _MemoryAiStore();
    final firestore = _HistorySnapshotFirestore();
    final repository = AiGenerationRepositoryImpl.forTest(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'generationId': 'gen_mlt7o22q_7a9688a037a47de6',
            'imageUrls': {
              'imageUrl': 'https://example.test/full.png',
              'watermarkedImageUrl': 'https://example.test/wm.png',
            },
          }),
          200,
        ),
      ),
      auth: _GenerationAuth(),
      localStore: store,
    );
    await setUpPage(
      tester,
      (name, parameters) async => <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': 90,
        'delta': -10,
        'transactionId': 'reservation-1',
      },
      repository: repository,
      firestore: firestore,
    );
    firestore.delayQueries = true;
    final refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    expect(firestore.pending, hasLength(1));

    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    expect(store.records['history/user-1/gen_mlt7o22q_7a9688a037a47de6']?['_syncState'], 'synced');
    expect(tester.widget<AiResultView>(find.byType(AiResultView)).record.id, 'gen_mlt7o22q_7a9688a037a47de6');

    firestore.pending.single.complete([]);
    await refresh;
    await tester.pumpAndSettle();
    expect(tester.widget<AiResultView>(find.byType(AiResultView)).record.id, 'gen_mlt7o22q_7a9688a037a47de6');
    expect(tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip)).history.map((r) => r.id), [
      'gen_mlt7o22q_7a9688a037a47de6',
    ]);

    // A new, authoritative empty window must still remove synced history from the page.
    final nextRefresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    firestore.pending.last.complete([]);
    await nextRefresh;
    await tester.pumpAndSettle();
    expect(tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip)).history, isEmpty);
    expect(
      tester.widget<AiResultView>(find.byType(AiResultView)).record.id,
      'gen_mlt7o22q_7a9688a037a47de6',
      reason: 'a history refresh does not close the result the user is looking at',
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('generating and submitting while remix linked writes remixOf to the uploaded wall', (tester) async {
    final FakeFirestoreClient firestore = FakeFirestoreClient();
    const String generatedId = 'gen_mlt7o22q_7a9688a037a47de6';
    final AiGenerationRecord generated = _record(id: generatedId);
    final _FakeAiGenerationRepository repository = _FakeAiGenerationRepository(
      generated,
      generation: () async => generated,
    );
    await setUpPage(
      tester,
      (name, parameters) async => <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': 90,
        'delta': -10,
        'transactionId': 'reservation-1',
      },
      repository: repository,
      firestore: firestore,
      remixSeed: const AiRemixSeed(
        wallDocId: 'orig_1',
        title: 'Koi',
        creatorName: 'Asha',
        thumbnailUrl: '',
        prompt: 'neon koi pond at dusk',
        sourceType: RemixSourceType.user,
      ),
    );
    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(tester.widget<AiResultView>(find.byType(AiResultView)).record.remixOf, 'orig_1');
    expect(repository.remixOfValues, <String?>['orig_1']);
    expect(repository.savedHistoryRecords, hasLength(1));
    expect(repository.savedHistoryRecords.single.remixOf, 'orig_1');

    final String submitLabel = AppLocalizations.of(
      tester.element(find.byType(AiWallpaperTabPage)),
    ).economyAiSubmitForReview;
    final Finder submitButton = find.bySemanticsLabel(submitLabel);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(submitLabel));
    await tester.pumpAndSettle();

    final Map<String, dynamic>? uploadedWall = firestore.docs['walls']?.values.single;
    expect(uploadedWall?['aiGenerationId'], generatedId);
    expect(uploadedWall?['remixOf'], 'orig_1');
  });

  testWidgets('submitting a selected recent uses that generation prompt and style as metadata fallbacks', (
    tester,
  ) async {
    final AiGenerationRecord recent = _record(
      id: 'recent-wall',
      prompt: 'silver fox beneath a winter moon',
      stylePreset: AiStylePreset.watercolor,
      remixOf: 'orig_1',
    );
    final FakeFirestoreClient firestore = FakeFirestoreClient();
    await setUpPage(
      tester,
      (name, parameters) async => <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': 90,
        'delta': -10,
        'transactionId': 'reservation-1',
      },
      repository: _FakeAiGenerationRepository(
        recent,
        history: () async => <AiGenerationRecord>[recent],
        submissionMetadata: (title: '', description: '', category: '', tags: <String>[]),
      ),
      firestore: firestore,
      remixSeed: const AiRemixSeed(
        wallDocId: 'compose-seed',
        title: 'Compose seed',
        creatorName: 'Asha',
        thumbnailUrl: '',
        prompt: 'neon koi pond at dusk',
        sourceType: RemixSourceType.user,
      ),
    );
    app_state.prismUser.premium = true;
    await openFirstRecent(tester);

    final String submitLabel = AppLocalizations.of(
      tester.element(find.byType(AiWallpaperTabPage)),
    ).economyAiSubmitForReview;
    final Finder submitButton = find.bySemanticsLabel(submitLabel);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(submitLabel));
    await tester.pumpAndSettle();

    final Map<String, dynamic>? uploadedWall = firestore.docs['walls']?.values.single;
    expect(
      uploadedWall,
      isNotNull,
      reason: 'the selected recent must complete submission before fallback fields are checked',
    );
    expect(uploadedWall?['title'], 'silver fox beneath a winter moon');
    expect(uploadedWall?['desc'], 'silver fox beneath a winter moon');
    expect(uploadedWall?['category'], AiStylePreset.watercolor.label);
    expect(uploadedWall?['tags'], containsAll(<String>['silver', 'fox', 'beneath', AiStylePreset.watercolor.apiValue]));
    expect(uploadedWall?['aiPrompt'], recent.prompt);
    expect(uploadedWall?['aiStylePreset'], AiStylePreset.watercolor.apiValue);
    expect(uploadedWall?['remixOf'], 'orig_1');
  });

  testWidgets('a remix link is saved when generation finishes after the owner session changes', (tester) async {
    final Completer<AiGenerationRecord> generation = Completer<AiGenerationRecord>();
    final AiGenerationRecord completed = _record(id: 'old-account-generation');
    final _FakeAiGenerationRepository repository = _FakeAiGenerationRepository(
      completed,
      generation: () => generation.future,
      history: () async => <AiGenerationRecord>[],
    );
    await setUpPage(
      tester,
      (name, parameters) async => <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': 90,
        'delta': -10,
        'transactionId': 'reservation-1',
      },
      repository: repository,
      remixSeed: const AiRemixSeed(
        wallDocId: 'orig_1',
        title: 'Koi',
        creatorName: 'Asha',
        thumbnailUrl: '',
        prompt: 'neon koi pond at dusk',
        sourceType: RemixSourceType.user,
      ),
    );

    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pump();
    expect(repository.requests, hasLength(1));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-2'
      ..loggedIn = true;
    CoinsService.instance.resetSession();
    generation.complete(completed);
    await tester.pumpAndSettle();

    expect(repository.savedHistoryRecords, hasLength(1));
    expect(repository.savedHistoryRecords.single.remixOf, 'orig_1');
    expect(find.byType(AiResultView), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a late local history load cannot replace a completed generation', (tester) async {
    final local = Completer<List<AiGenerationRecord>>();
    var localCalls = 0;
    await setUpPage(
      tester,
      (name, parameters) async => <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': 90,
        'delta': -10,
        'transactionId': 'reservation-1',
      },
      repository: _FakeAiGenerationRepository(
        _record(),
        generation: () async => _record(id: 'new-generation'),
        localHistory: () => ++localCalls == 1 ? Future.value([]) : local.future,
      ),
    );
    final refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    local.complete([_record()]);
    await refresh;
    await tester.pumpAndSettle();
    expect(tester.widget<AiResultView>(find.byType(AiResultView)).record.id, 'new-generation');
    expect(tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip)).loading, false);
    await tester.pump(const Duration(seconds: 2));
  });

  for (final staleFails in [false, true]) {
    testWidgets('latest refresh wins when an older remote response ${staleFails ? 'fails' : 'succeeds'} last', (
      tester,
    ) async {
      final firestore = _HistorySnapshotFirestore();
      final repository = AiGenerationRepositoryImpl.forTest(
        client: MockClient((_) async => http.Response('{}', 200)),
        auth: _GenerationAuth(),
        localStore: _MemoryAiStore(),
      );
      await setUpPage(tester, (name, parameters) async => {}, repository: repository, firestore: firestore);
      firestore.delayQueries = true;
      final refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh;
      final older = refresh();
      await tester.pump();
      final newer = refresh();
      await tester.pump();
      expect(firestore.pending, hasLength(2));
      firestore.pending[1].complete([(id: 'newer', data: _record(id: 'newer').toJson())]);
      await newer;
      await tester.pumpAndSettle();
      if (staleFails) {
        firestore.pending[0].completeError(StateError('old refresh failed'));
      } else {
        firestore.pending[0].complete([(id: 'older', data: _record(id: 'older').toJson())]);
      }
      await older;
      await tester.pumpAndSettle();
      expect(find.byType(AiResultView), findsNothing);
      final history = tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip));
      expect(history.history.map((r) => r.id), ['newer']);
      expect(history.failed, false);
      expect(history.loading, false);
    });
  }

  testWidgets('history from a previous A session is ignored after A to B to A without another load', (tester) async {
    final oldHistory = Completer<List<AiGenerationRecord>>();
    var reads = 0;
    await setUpPage(
      tester,
      (name, parameters) async => {},
      repository: _FakeAiGenerationRepository(
        _record(),
        history: () => ++reads == 1 ? Future.value([_record()]) : oldHistory.future,
      ),
    );
    final refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    expect(reads, 2);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-2'
      ..loggedIn = true;
    CoinsService.instance.resetSession();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    CoinsService.instance.resetSession();
    oldHistory.complete([_record(id: 'old-session-history')]);
    await refresh;
    await tester.pumpAndSettle();
    expect(tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip)).history.map((r) => r.id), ['generation-1']);
    expect(tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip)).loading, false);
  });

  for (final outcome in ['success', 'failure', 'return-to-A']) {
    testWidgets('old generation $outcome cannot publish, commit or refund in a replacement session', (tester) async {
      final analytics = _RecordingAnalytics();
      AnalyticsRuntime.instance = analytics;
      final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
      final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
      addTearDown(() {
        LiveActivityChannel.api = originalApi;
        LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
      });
      final api = _RecordingLiveActivityApi();
      LiveActivityChannel.api = api;
      LiveActivityChannel.isSupportedPlatform = () => true;
      final generation = Completer<AiGenerationRecord>();
      final refunds = <String>[];
      var historyReads = 0;
      final toasts = <MethodCall>[];
      await setUpPage(
        tester,
        (name, parameters) async {
          if (name == 'awardCoins') refunds.add(app_state.prismUser.id);
          return <String, Object>{
            'success': true,
            'changed': true,
            'currentBalance': 90,
            'delta': -10,
            'transactionId': 'reservation-1',
          };
        },
        repository: _FakeAiGenerationRepository(
          _record(),
          generation: () => generation.future,
          history: () async => [
            if (++historyReads == 1) _record() else _record(id: 'replacement-history', userId: app_state.prismUser.id),
          ],
        ),
        toastCalls: toasts,
      );
      await tester.ensureVisible(find.text('Generate'));
      await tester.tap(find.text('Generate'));
      await tester.pump();
      expect(analytics.events.whereType<AiGenerateStartedEvent>(), hasLength(1));
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'user-2'
        ..loggedIn = true
        ..coins = 77;
      CoinsService.instance.resetSession();
      if (outcome == 'return-to-A') {
        app_state.prismUser = app_constants.createGuestPrismUser()
          ..id = 'user-1'
          ..loggedIn = true
          ..coins = 77;
        CoinsService.instance.resetSession();
      }
      final refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
      await tester.pump();
      await refresh;
      if (outcome == 'failure') {
        generation.completeError(StateError('old account request failed'));
      } else {
        generation.complete(_record(id: 'old-account-generation'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AiResultView), findsNothing);
      expect(tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip)).history.map((r) => r.id), [
        'replacement-history',
      ]);
      expect(analytics.events.whereType<AiChargeCommittedEvent>(), isEmpty);
      expect(refunds, isEmpty);
      expect(api.calls, <String>['cancel:activity-1']);
      expect(toasts, isEmpty);
      expect(app_state.prismUser.coins, 77);
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets('initial history failures do not play an error haptic', (tester) async {
    final List<Object?> hapticTypes = <Object?>[];
    final List<MethodCall> toastCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await setUpPage(
      tester,
      (name, parameters) async => <String, Object>{},
      connectivity: _FakeConnectivityService(check: () async => false),
      toastCalls: toastCalls,
    );

    expect(hapticTypes, isEmpty);
    expect(toastCalls, isEmpty);

    hapticTypes.clear();
    toastCalls.clear();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(hapticTypes, <Object?>['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.errorNotification']);
    expect(toastCalls, hasLength(1));
    expect(
      (toastCalls.single.arguments as Map<Object?, Object?>)['msg'],
      "You're offline. Saved history is still available.",
    );
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('an empty description keeps Generate off and plays no haptic', (tester) async {
    final List<Object?> hapticTypes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await setUpPage(tester, (name, parameters) async => <String, Object>{});

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    final Finder generate = find.text('Generate');
    await tester.ensureVisible(generate);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Generate')).onPressed, isNull);
    hapticTypes.clear();
    await tester.tap(generate, warnIfMissed: false);
    await tester.pump();

    expect(hapticTypes, isEmpty);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('an empty refinement keeps Generate another off and plays no haptic', (tester) async {
    final List<Object?> hapticTypes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await setUpPage(tester, (name, parameters) async => <String, Object>{});

    await openFirstRecent(tester);
    await tester.tap(find.byTooltip('Try another'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '');
    await tester.pump();
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Generate another')).onPressed, isNull);
    hapticTypes.clear();
    await tester.tap(find.text('Generate another'), warnIfMissed: false);
    await tester.pump();

    expect(hapticTypes, isEmpty);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a crop warning after successful generation does not add an error haptic', (tester) async {
    final List<Object?> hapticTypes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await setUpPage(
      tester,
      (name, parameters) async => <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': 90,
        'delta': -10,
        'transactionId': 'reservation-1',
      },
      repository: _FakeAiGenerationRepository(
        _record(),
        generation: () async => _record(id: 'generated-wide', width: 1600, height: 900),
      ),
    );

    final Finder generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    // Reserving coins starts a short-lived local-balance timer; let the fake clock drain it.
    await tester.pump(const Duration(seconds: 2));

    expect(hapticTypes, contains('HapticFeedbackType.successNotification'));
    expect(hapticTypes, isNot(contains('HapticFeedbackType.errorNotification')));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('concurrent connectivity checks reserve and generate only once', (tester) async {
    final connection = Completer<bool>();
    final generation = Completer<AiGenerationRecord>();
    var connectionCalls = 0;
    var spendCalls = 0;
    final repository = _FakeAiGenerationRepository(_record(), generation: () => generation.future);
    await setUpPage(
      tester,
      (name, parameters) async {
        if (name == 'spendCoins') spendCalls++;
        return <String, Object>{
          'success': true,
          'changed': true,
          'currentBalance': 90,
          'delta': -10,
          'transactionId': 'reservation-1',
        };
      },
      repository: repository,
      connectivity: _FakeConnectivityService(
        check: () => ++connectionCalls == 1 ? Future<bool>.value(true) : connection.future,
      ),
    );
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.tap(generate);
    await tester.pump();
    expect(find.text('This takes about 20 seconds'), findsOneWidget);
    connection.complete(true);
    await tester.pump();
    final actualSpends = spendCalls;
    final actualRequests = repository.requests.length;
    generation.complete(_record(id: 'generated-1'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(actualSpends, 1);
    expect(actualRequests, 1);
  });

  testWidgets('a queued second connectivity result cannot start a second paid request', (tester) async {
    final firstConnection = Completer<bool>();
    final secondConnection = Completer<bool>();
    var connectionCalls = 0;
    var spendCalls = 0;
    final repository = _FakeAiGenerationRepository(_record(), generation: () async => _record(id: 'generated-1'));
    await setUpPage(
      tester,
      (name, parameters) async {
        if (name == 'spendCoins') spendCalls++;
        return <String, Object>{
          'success': true,
          'changed': true,
          'currentBalance': 90,
          'delta': -10,
          'transactionId': 'reservation-1',
        };
      },
      repository: repository,
      connectivity: _FakeConnectivityService(
        check: () {
          connectionCalls++;
          if (connectionCalls == 1) return Future<bool>.value(true);
          return connectionCalls == 2 ? firstConnection.future : secondConnection.future;
        },
      ),
    );
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.tap(generate);
    firstConnection.complete(true);
    await tester.pumpAndSettle();
    secondConnection.complete(true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(spendCalls, 1);
    expect(repository.requests, hasLength(1));
  });

  testWidgets('offline connectivity completing after disposal has no toast or charge', (tester) async {
    final recorder = _RecordingAnalytics();
    AnalyticsRuntime.instance = recorder;
    final connection = Completer<bool>();
    var connectionCalls = 0;
    var spendCalls = 0;
    await setUpPage(
      tester,
      (name, parameters) async {
        if (name == 'spendCoins') spendCalls++;
        return <String, Object>{};
      },
      connectivity: _FakeConnectivityService(
        check: () => ++connectionCalls == 1 ? Future<bool>.value(true) : connection.future,
      ),
    );
    final toasts = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toasts.add(call);
      return true;
    });
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink(),
      ),
    );
    connection.complete(false);
    await tester.pump();

    expect(toasts, isEmpty);
    expect(spendCalls, 0);
    expect(recorder.events.whereType<AiGenerateFailedEvent>().single.refundResult, 'not_required');
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending reservation retains the requested quality and style', (tester) async {
    final reservation = Completer<dynamic>();
    final analytics = _RecordingAnalytics();
    AnalyticsRuntime.instance = analytics;
    final repository = _FakeAiGenerationRepository(_record(), generation: () async => _record(id: 'generated-1'));
    final spends = <Map<String, Object?>>[];
    await setUpPage(tester, (name, parameters) {
      spends.add(Map<String, Object?>.from(parameters as Map<Object?, Object?>));
      return reservation.future;
    }, repository: repository);
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();
    await tester.ensureVisible(find.text('Quality').last);
    await tester.tap(find.text('Quality').last);
    await tester.pump();
    await tester.ensureVisible(find.byType(ListView).first);
    await tester.pump();
    await tester.tap(find.text('Anime'));
    reservation.complete(<String, Object>{
      'success': true,
      'changed': true,
      'currentBalance': 90,
      'delta': -10,
      'transactionId': 'reservation-1',
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(spends.single['qualityTier'], AiQualityTier.fast.apiValue);
    expect(repository.requests.single, (style: AiStylePreset.abstract, quality: AiQualityTier.fast, coinsSpent: 10));
    final started = analytics.events.whereType<AiGenerateStartedEvent>().single;
    expect(started.quality, 'fast');
    expect(started.style, 'abstract');
    final reserved = analytics.events.whereType<AiChargeReservedEvent>().single;
    final committed = analytics.events.whereType<AiChargeCommittedEvent>().single;
    final success = analytics.events.whereType<AiGenerateSuccessEvent>().single;
    expect(started.operationId, isNotEmpty);
    expect(reserved.operationId, started.operationId);
    expect(committed.operationId, started.operationId);
    expect(success.operationId, started.operationId);
    expect(success.generationId, 'generated-1');
    expect(success.chargeTransactionId, 'reservation-1');
    expect(success.durationMs, greaterThanOrEqualTo(0));
  });

  testWidgets('failed generation after disposal refunds its debit once without a toast', (tester) async {
    final analytics = _RecordingAnalytics();
    AnalyticsRuntime.instance = analytics;
    final generation = Completer<AiGenerationRecord>();
    final refunds = <Map<String, Object?>>[];
    await setUpPage(tester, (name, parameters) async {
      if (name == 'awardCoins') refunds.add(Map<String, Object?>.from(parameters as Map<Object?, Object?>));
      return <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': name == 'awardCoins' ? 100 : 90,
        'delta': name == 'awardCoins' ? 10 : -10,
        'transactionId': 'reservation-1',
      };
    }, repository: _FakeAiGenerationRepository(_record(), generation: () => generation.future));
    final toasts = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toasts.add(call);
      return true;
    });
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink(),
      ),
    );
    generation.completeError(StateError('generation failed'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(refunds, hasLength(1));
    expect(refunds.single['transactionId'], 'reservation-1');
    expect(refunds.single.containsKey('amount'), isFalse);
    expect(analytics.events.whereType<AiGenerateFailedEvent>(), hasLength(1));
    final failure = analytics.events.whereType<AiGenerateFailedEvent>().single;
    final rollback = analytics.events.whereType<AiChargeRolledBackEvent>().single;
    expect(failure.error, 'generation_failed');
    expect(failure.errorCategory, 'generation_failed');
    expect(failure.refundResult, 'refunded');
    expect(failure.chargeTransactionId, 'reservation-1');
    expect(failure.operationId, rollback.operationId);
    expect(analytics.events.whereType<AiChargeCommittedEvent>(), isEmpty);
    expect(toasts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed reservation completing after disposal does not set state', (tester) async {
    final Completer<void> reservationStarted = Completer<void>();
    final Completer<dynamic> reservation = Completer<dynamic>();
    await setUpPage(tester, (name, parameters) async {
      if (name == 'spendCoins') {
        reservationStarted.complete();
        return reservation.future;
      }
      return <String, Object>{'success': true, 'changed': false, 'currentBalance': 100};
    });

    final Finder generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();
    await reservationStarted.future;
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink(),
      ),
    );
    reservation.complete(<String, Object>{
      'success': false,
      'changed': false,
      'insufficientBalance': true,
      'currentBalance': 0,
    });
    await tester.pump();

    final Object? exception = tester.takeException();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(exception, isNull);
  });

  testWidgets('successful reservation completing after disposal is refunded without generation', (tester) async {
    final Completer<void> reservationStarted = Completer<void>();
    final Completer<dynamic> reservation = Completer<dynamic>();
    var generationCalls = 0;
    var refundCalls = 0;
    await setUpPage(
      tester,
      (name, parameters) async {
        if (name == 'spendCoins') {
          reservationStarted.complete();
          return reservation.future;
        }
        if (name == 'awardCoins') refundCalls++;
        return <String, Object>{'success': true, 'changed': false, 'currentBalance': 10};
      },
      repository: _FakeAiGenerationRepository(
        _record(),
        generation: () async {
          generationCalls++;
          return _record(id: 'generated-1');
        },
      ),
    );

    final Finder generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();
    await reservationStarted.future;
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink(),
      ),
    );
    reservation.complete(<String, Object>{
      'success': true,
      'changed': true,
      'currentBalance': 10,
      'delta': -10,
      'transactionId': 'reservation-1',
    });
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(tester.takeException(), isNull);
    expect(generationCalls, 0);
    expect(refundCalls, 1);
  });

  Future<List<String?>> refineWithSeed(WidgetTester tester, AiGenerationRecord source) async {
    final _FakeAiGenerationRepository repository = _FakeAiGenerationRepository(
      source,
      variation: () async => _record(id: 'variation-1'),
    );
    await setUpPage(
      tester,
      (name, parameters) async => <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': 90,
        'delta': -10,
        'transactionId': 'reservation-1',
      },
      repository: repository,
      remixSeed: const AiRemixSeed(
        wallDocId: 'orig_1',
        title: 'Koi',
        creatorName: 'Asha',
        thumbnailUrl: '',
        prompt: 'neon koi pond at dusk',
        sourceType: RemixSourceType.user,
      ),
    );
    await openFirstRecent(tester);
    final Finder refine = find.byTooltip('Try another');
    await tester.ensureVisible(refine);
    await tester.tap(refine);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Warmer colors');
    await tester.pump();
    await tester.tap(find.text('Generate another'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    return repository.remixOfValues;
  }

  testWidgets('a variation of an unlinked history wall does not credit the remix seed', (tester) async {
    expect(await refineWithSeed(tester, _record()), <String?>[null]);
  });

  testWidgets('a variation of a result linked to the seed keeps the credit', (tester) async {
    expect(await refineWithSeed(tester, _record().copyWith(remixOf: 'orig_1')), <String?>['orig_1']);
  });

  testWidgets('successful variation completing after disposal is not rolled back', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Completer<void> variationStarted = Completer<void>();
    final Completer<AiGenerationRecord> variation = Completer<AiGenerationRecord>();
    var refundCalls = 0;
    functions.onCall = (name, parameters) async {
      if (name == 'awardCoins') refundCalls++;
      return <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': 10,
        'delta': -10,
        'transactionId': 'reservation-1',
      };
    };
    await getIt.reset();
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..coins = 100
      ..loggedIn = true;
    CoinsService.instance.balanceNotifier.value = 100;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(
            _record(),
            variation: () {
              variationStarted.complete();
              return variation.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openFirstRecent(tester);
    final Finder refine = find.byTooltip('Try another');
    await tester.ensureVisible(refine);
    await tester.tap(refine);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Warmer colors');
    await tester.pump();
    await tester.tap(find.text('Generate another'));
    await tester.pump();
    await variationStarted.future;
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink(),
      ),
    );
    variation.complete(_record(id: 'variation-1'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(refundCalls, 0);
  });

  Future<int> generateAndCountRefunds(WidgetTester tester, Future<AiGenerationRecord> Function() generation) async {
    var refundCalls = 0;
    await setUpPage(tester, (name, parameters) async {
      if (name == 'awardCoins') refundCalls++;
      return <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': name == 'awardCoins' ? 100 : 90,
        'delta': name == 'awardCoins' ? 10 : -10,
        'transactionId': 'reservation-1',
      };
    }, repository: _FakeAiGenerationRepository(_record(), generation: generation));
    final Finder generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    return refundCalls;
  }

  testWidgets('a failed generation is refunded exactly once', (tester) async {
    final _RecordingAnalytics recorder = _RecordingAnalytics();
    AnalyticsRuntime.instance = recorder;

    final int refunds = await generateAndCountRefunds(tester, () async => throw StateError('provider failed'));

    expect(refunds, 1);
    expect(recorder.events.whereType<AiGenerateFailedEvent>(), hasLength(1));
    expect(app_state.prismUser.coins, 100);
  });

  Map<String, Object> coinReply(String name, {bool refundChanged = true}) => <String, Object>{
    'success': name != 'awardCoins' || refundChanged,
    'changed': name != 'awardCoins' || refundChanged,
    'currentBalance': name == 'awardCoins' ? 100 : 90,
    'delta': name == 'awardCoins' ? 10 : -10,
    'transactionId': 'reservation-1',
  };

  testWidgets('a started-event failure cannot cancel a paid generation', (tester) async {
    final recorder = _RecordingAnalytics(throwOn: (event) => event is AiGenerateStartedEvent);
    AnalyticsRuntime.instance = recorder;
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
    });
    final api = _RecordingLiveActivityApi();
    LiveActivityChannel.api = api;
    LiveActivityChannel.isSupportedPlatform = () => true;
    var requests = 0;
    final refunds = await generateAndCountRefunds(tester, () async {
      requests++;
      return _record(id: 'generated-1');
    });

    expect(refunds, 0);
    expect(requests, 1);
    expect(api.starts, 1);
    expect(recorder.events.whereType<AiGenerateFailedEvent>(), isEmpty);
    expect(find.text('Generate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a committed generation is not refunded when a follow-up step throws', (tester) async {
    final _RecordingAnalytics recorder = _RecordingAnalytics(throwOn: (event) => event is AiGenerateSuccessEvent);
    AnalyticsRuntime.instance = recorder;

    final int refunds = await generateAndCountRefunds(tester, () async => _record(id: 'generated-1'));

    expect(recorder.events.whereType<AiChargeCommittedEvent>(), hasLength(1));
    expect(refunds, 0);
    expect(recorder.events.whereType<AiGenerateFailedEvent>(), isEmpty);
    expect(app_state.prismUser.coins, 90);
  });

  testWidgets('a successful generation finishes its activity before follow-up analytics can fail', (tester) async {
    final recorder = _RecordingAnalytics(throwOn: (event) => event is AiGenerateSuccessEvent);
    AnalyticsRuntime.instance = recorder;
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
    });
    final api = _RecordingLiveActivityApi();
    LiveActivityChannel.api = api;
    LiveActivityChannel.isSupportedPlatform = () => true;
    final repository = _FakeAiGenerationRepository(_record(), generation: () async => _record(id: 'generated-1'));
    await setUpPage(tester, (name, parameters) async => coinReply(name), repository: repository);

    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(api.calls, hasLength(1));
    expect(api.calls.single, startsWith('finish:activity-1:'));
    expect(app_state.prismUser.coins, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a retry starts a fresh activity after the first request fails', (tester) async {
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
    });
    final api = _RecordingLiveActivityApi();
    LiveActivityChannel.api = api;
    LiveActivityChannel.isSupportedPlatform = () => true;
    var requests = 0;
    final repository = _FakeAiGenerationRepository(
      _record(),
      generation: () async {
        if (++requests == 1) throw StateError('provider failed');
        return _record(id: 'retry-success');
      },
    );
    await setUpPage(tester, (name, parameters) async => coinReply(name), repository: repository);

    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(api.starts, 2);
    expect(api.calls, <String>['fail:activity-1', 'finish:activity-2:']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('generation continues when starting a live activity fails unexpectedly', (tester) async {
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
    });
    LiveActivityChannel.api = _FailingLiveActivityApi();
    LiveActivityChannel.isSupportedPlatform = () => true;
    final repository = _FakeAiGenerationRepository(_record(), generation: () async => _record(id: 'generated-1'));

    await setUpPage(tester, (name, parameters) async => coinReply(name), repository: repository);
    final Finder generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(repository.requests, hasLength(1));
    expect(app_state.prismUser.coins, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline generation does not start a live activity', (tester) async {
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
    });
    final api = _RecordingLiveActivityApi();
    LiveActivityChannel.api = api;
    LiveActivityChannel.isSupportedPlatform = () => true;
    await setUpPage(
      tester,
      (name, parameters) async => coinReply(name),
      connectivity: _FakeConnectivityService(check: () async => false),
    );

    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(api.starts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected charge does not start a live activity', (tester) async {
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
    });
    final api = _RecordingLiveActivityApi();
    LiveActivityChannel.api = api;
    LiveActivityChannel.isSupportedPlatform = () => true;
    await setUpPage(tester, (name, parameters) async {
      if (name == 'spendCoins') {
        throw FirebaseFunctionsException(code: 'permission-denied', message: 'denied');
      }
      return coinReply(name);
    });

    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(api.starts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a session change during activity startup cancels activity without starting generation', (tester) async {
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
    });
    final api = _RecordingLiveActivityApi()..startGate = Completer<String?>();
    LiveActivityChannel.api = api;
    LiveActivityChannel.isSupportedPlatform = () => true;
    var refunds = 0;
    final repository = _FakeAiGenerationRepository(_record(), generation: () async => _record());
    await setUpPage(tester, (name, parameters) async {
      if (name == 'awardCoins') refunds++;
      return coinReply(name);
    }, repository: repository);

    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pump();
    await api.startEntered.future;
    app_state.prismUser = app_constants.createGuestPrismUser();
    api.startGate!.complete('delayed-activity');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(repository.requests, isEmpty);
    expect(api.calls, <String>['cancel:delayed-activity']);
    expect(refunds, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposal during activity startup cancels activity and rolls back reservation', (tester) async {
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
    });
    final api = _RecordingLiveActivityApi()..startGate = Completer<String?>();
    LiveActivityChannel.api = api;
    LiveActivityChannel.isSupportedPlatform = () => true;
    var refunds = 0;
    final repository = _FakeAiGenerationRepository(_record(), generation: () async => _record());
    await setUpPage(tester, (name, parameters) async {
      if (name == 'awardCoins') refunds++;
      return coinReply(name);
    }, repository: repository);

    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pump();
    await api.startEntered.future;
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    api.startGate!.complete('delayed-activity');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(repository.requests, isEmpty);
    expect(api.calls, <String>['cancel:delayed-activity']);
    expect(refunds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unmounted generation failure settles its activity with one cancellation', (tester) async {
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalPlatformCheck = LiveActivityChannel.isSupportedPlatform;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalPlatformCheck;
    });
    final api = _RecordingLiveActivityApi();
    LiveActivityChannel.api = api;
    LiveActivityChannel.isSupportedPlatform = () => true;
    final request = Completer<AiGenerationRecord>();
    final repository = _FakeAiGenerationRepository(_record(), generation: () => request.future);
    var refunds = 0;
    await setUpPage(tester, (name, parameters) async {
      if (name == 'awardCoins') refunds++;
      return coinReply(name);
    }, repository: repository);

    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pump();
    await tester.pump();
    expect(repository.requests, hasLength(1));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    request.completeError(StateError('provider failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(api.calls, <String>['cancel:activity-1']);
    expect(refunds, 1);
    expect(tester.takeException(), isNull);
  });

  List<String> toastMessages(List<MethodCall> calls) =>
      calls.map((call) => (call.arguments as Map<Object?, Object?>)['msg']! as String).toList();

  testWidgets('a failed generation says the coins were refunded', (tester) async {
    final toastCalls = <MethodCall>[];
    await setUpPage(
      tester,
      (name, parameters) async => coinReply(name),
      repository: _FakeAiGenerationRepository(_record(), generation: () async => throw StateError('provider failed')),
      toastCalls: toastCalls,
    );
    toastCalls.clear();
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(toastMessages(toastCalls), contains('Something went wrong. Try again. Coins refunded.'));
  });

  testWidgets('a failed generation whose refund did not land says the refund is pending and keeps it', (tester) async {
    final recorder = _RecordingAnalytics();
    AnalyticsRuntime.instance = recorder;
    final toastCalls = <MethodCall>[];
    await setUpPage(
      tester,
      (name, parameters) async {
        if (name == 'awardCoins') throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
        return coinReply(name);
      },
      repository: _FakeAiGenerationRepository(_record(), generation: () async => throw StateError('provider failed')),
      toastCalls: toastCalls,
    );
    toastCalls.clear();
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(toastMessages(toastCalls), contains('Something went wrong. Try again. Refund pending.'));
    expect(recorder.events.whereType<AiGenerateFailedEvent>().single.refundResult, 'pending');
    expect(
      getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''),
      contains('reservation-1'),
    );

    await getIt<SettingsLocalDataSource>().delete('pendingAiRefunds');
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('a terminal refund denial is not reported or retained as pending', (tester) async {
    final recorder = _RecordingAnalytics();
    AnalyticsRuntime.instance = recorder;
    await setUpPage(tester, (name, parameters) async {
      if (name == 'awardCoins') throw FirebaseFunctionsException(code: 'permission-denied', message: 'denied');
      return coinReply(name);
    }, repository: _FakeAiGenerationRepository(_record(), generation: () async => throw StateError('provider failed')));
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(recorder.events.whereType<AiGenerateFailedEvent>().single.refundResult, 'denied');
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''), isEmpty);
    await tester.pump(const Duration(milliseconds: 1400));
  });

  testWidgets('a failed generation that charged no coins does not mention a refund', (tester) async {
    final recorder = _RecordingAnalytics();
    AnalyticsRuntime.instance = recorder;
    final toastCalls = <MethodCall>[];
    await setUpPage(
      tester,
      (name, parameters) async => <String, Object>{
        'success': true,
        'changed': true,
        'currentBalance': 100,
        'delta': 0,
        'transactionId': 'reservation-1',
      },
      repository: _FakeAiGenerationRepository(_record(), generation: () async => throw StateError('provider failed')),
      toastCalls: toastCalls,
    );
    toastCalls.clear();
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(toastMessages(toastCalls), contains('Something went wrong. Try again.'));
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''), isEmpty);
    expect(recorder.events.whereType<AiGenerateFailedEvent>().single.refundResult, 'not_required');
  });

  testWidgets('a charge with no reply queues a refund and tells the user', (tester) async {
    final toastCalls = <MethodCall>[];
    var generations = 0;
    await setUpPage(
      tester,
      (name, parameters) async {
        if (name == 'spendCoins') throw FirebaseFunctionsException(code: 'unavailable', message: 'no reply');
        return coinReply(name);
      },
      repository: _FakeAiGenerationRepository(
        _record(),
        generation: () async {
          generations++;
          return _record();
        },
      ),
      toastCalls: toastCalls,
    );
    toastCalls.clear();
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(generations, 0);
    expect(toastMessages(toastCalls), contains("Couldn't confirm the charge. Any coins taken will be refunded."));
    expect(
      getIt<SettingsLocalDataSource>().get<String>('pendingAiRefunds', defaultValue: ''),
      contains('spend_${app_state.prismUser.id}_'),
    );

    await getIt<SettingsLocalDataSource>().delete('pendingAiRefunds');
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('free users see the watermark note and Pro users do not', (tester) async {
    await setUpPage(tester, (name, parameters) async => <String, Object>{});
    expect(find.text('Free images carry a Prism watermark. Pro removes it.'), findsOneWidget);

    app_state.prismUser.premium = true;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(repository: _FakeAiGenerationRepository(_record()), key: UniqueKey()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Free images carry a Prism watermark. Pro removes it.'), findsNothing);
  });

  testWidgets('the description field stops at 160 characters and shows a counter', (tester) async {
    await setUpPage(tester, (name, parameters) async => <String, Object>{});
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.maxLength, 160);

    await tester.enterText(find.byType(TextField).first, 'x' * 200);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text.length, 160);
    expect(find.text('160/160'), findsOneWidget);
  });

  testWidgets('a refinement is charged at the parent generation tier, not the selected tier', (tester) async {
    final spends = <Map<String, Object?>>[];
    await setUpPage(tester, (name, parameters) async {
      if (name == 'spendCoins') spends.add(Map<String, Object?>.from(parameters as Map<Object?, Object?>));
      return coinReply(name);
    }, repository: _FakeAiGenerationRepository(_record(), variation: () async => _record(id: 'variation-1')));
    await tester.ensureVisible(find.text('Quality').last);
    await tester.tap(find.text('Quality').last);
    await tester.pump();
    await openFirstRecent(tester);
    await tester.tap(find.byTooltip('Try another'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'warmer palette');
    await tester.pump();
    await tester.tap(find.text('Generate another'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(spends, hasLength(1));
    expect(spends.single['qualityTier'], AiQualityTier.fast.apiValue);
  });

  testWidgets('generate and Try another send the charge transaction id to the repository', (tester) async {
    final repository = _FakeAiGenerationRepository(
      _record(),
      generation: () async => _record(id: 'generated-1'),
      variation: () async => _record(id: 'variation-1'),
    );
    await setUpPage(tester, (name, parameters) async => coinReply(name), repository: repository);
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.ensureVisible(find.byTooltip('Try another'));
    await tester.tap(find.byTooltip('Try another'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'warmer palette');
    await tester.pump();
    await tester.tap(find.text('Generate another'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(repository.chargeTxIds, <String?>['reservation-1', 'reservation-1']);
  });

  testWidgets('a worker error shows calm copy, never the worker message', (tester) async {
    final toastCalls = <MethodCall>[];
    await setUpPage(
      tester,
      (name, parameters) async => coinReply(name),
      repository: _FakeAiGenerationRepository(
        _record(),
        generation: () async => throw AiGenerationApiException(
          message: 'Quota coordinator unavailable',
          code: 'rate_limited',
          statusCode: 429,
        ),
      ),
      toastCalls: toastCalls,
    );
    toastCalls.clear();
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(toastMessages(toastCalls), contains("You reached today's AI limit. Coins refunded."));
    expect(toastMessages(toastCalls).any((m) => m.contains('Quota coordinator')), isFalse);
  });

  testWidgets('a signed-out user gets the sign-in prompt and its sheet, not a toast', (tester) async {
    final toastCalls = <MethodCall>[];
    await setUpPage(
      tester,
      (name, parameters) async => coinReply(name),
      repository: _FakeAiGenerationRepository(_record()),
      toastCalls: toastCalls,
    );
    app_state.prismUser = app_constants.createGuestPrismUser();
    toastCalls.clear();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: AiWallpaperTabPage(repository: _FakeAiGenerationRepository(_record()), key: UniqueKey()),
      ),
    );
    // The Glint state animates for ever, so settle by time.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Generate'), findsNothing);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Sign in to Prism'), findsOneWidget);
    expect(toastMessages(toastCalls), isEmpty);
  });

  // Guards lib: `_scrollToTop` jumps when `context.reduceMotion` is true. A zero-duration animateTo asserts.
  testWidgets('generation scrolls to top without a zero-duration animation under reduced motion', (tester) async {
    await setUpPage(
      tester,
      (name, parameters) async => coinReply(name),
      repository: _FakeAiGenerationRepository(_record(), generation: () async => _record()),
      disableAnimations: true,
    );
    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();
    await tester.ensureVisible(find.text('Quality').last);
    expect(Scrollable.of(tester.element(find.text('Quality').last)).position.pixels, greaterThan(0));

    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(find.byType(AiResultView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account changes clear account-bound AI result, history, and remix state', (tester) async {
    final AiGenerationRecord generated = _record();
    final repository = _FakeAiGenerationRepository(
      generated,
      generation: () async => _record(userId: app_state.prismUser.id),
      historyForUser: (String userId) async =>
          userId == 'user-1' ? <AiGenerationRecord>[generated] : <AiGenerationRecord>[],
    );
    await setUpPage(
      tester,
      (name, parameters) async => coinReply(name),
      repository: repository,
      remixSeed: const AiRemixSeed(
        wallDocId: 'orig_1',
        title: 'Koi',
        creatorName: 'Asha',
        thumbnailUrl: '',
        prompt: 'neon koi pond at dusk',
        sourceType: RemixSourceType.user,
      ),
    );
    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.byType(AiResultView), findsOneWidget);
    expect(tester.widget<AiResultView>(find.byType(AiResultView)).session, hasLength(1));

    await tester.ensureVisible(find.byTooltip('Try another'));
    await tester.tap(find.byTooltip('Try another'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'A private refine draft');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-2'
      ..coins = 100
      ..loggedIn = true;
    tester.element(find.byType(AiWallpaperTabPage)).markNeedsBuild();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AiResultView), findsNothing);
    expect(
      find.byType(AiRemixChip),
      findsNothing,
      reason: 'a remix seed from user-1 must not remain active for user-2',
    );
    expect(
      tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip)).history,
      isEmpty,
      reason: 'user-2 must not see user-1 AI history before a pull-to-refresh',
    );

    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..coins = 100
      ..loggedIn = true;
    tester.element(find.byType(AiWallpaperTabPage)).markNeedsBuild();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AiResultView), findsNothing, reason: 'switching back must not resurrect the old result/session');

    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-2'
      ..coins = 100
      ..loggedIn = true;
    tester.element(find.byType(AiWallpaperTabPage)).markNeedsBuild();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Generate'));
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(repository.remixOfValues, <String?>['orig_1', null]);
    await tester.ensureVisible(find.byTooltip('Try another'));
    await tester.tap(find.byTooltip('Try another'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('session stream owner changes clear remix and history without a page rebuild', (tester) async {
    final _StreamSessionRepository session = _StreamSessionRepository(
      app_constants.createGuestPrismUser()
        ..id = 'user-1'
        ..coins = 100
        ..loggedIn = true,
    );
    addTearDown(session.dispose);
    final AiGenerationRecord firstUserRecord = _record();
    await setUpPage(
      tester,
      (name, parameters) async => coinReply(name),
      sessionRepository: session,
      repository: _FakeAiGenerationRepository(
        firstUserRecord,
        historyForUser: (String userId) async =>
            userId == 'user-1' ? <AiGenerationRecord>[firstUserRecord] : <AiGenerationRecord>[],
      ),
      remixSeed: const AiRemixSeed(
        wallDocId: 'orig_1',
        title: 'Koi',
        creatorName: 'Asha',
        thumbnailUrl: '',
        prompt: 'neon koi pond at dusk',
        sourceType: RemixSourceType.user,
      ),
    );
    expect(find.byType(AiRemixChip), findsOneWidget);
    expect(tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip)).history, hasLength(1));

    await session.replaceCurrentUser(
      app_constants.createGuestPrismUser()
        ..id = 'user-2'
        ..coins = 100
        ..loggedIn = true,
    );
    await tester.pumpAndSettle();

    expect(find.byType(AiRemixChip), findsNothing);
    expect(tester.widget<AiHistoryStrip>(find.byType(AiHistoryStrip)).history, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
