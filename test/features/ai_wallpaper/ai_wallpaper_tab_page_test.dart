import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/wallpaper/wall_submission.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _FakeConnectivityService implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;
}

class _FakeAiGenerationRepository extends Fake implements AiGenerationRepositoryImpl {
  _FakeAiGenerationRepository(this.record, this.metadata, {this.history});

  final AiGenerationRecord record;
  final Completer<AiSubmissionMetadata> metadata;
  final Future<List<AiGenerationRecord>> Function()? history;
  final List<AiGenerationRecord> savedRecords = <AiGenerationRecord>[];
  bool failHistorySave = false;

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) =>
      history?.call() ?? Future<List<AiGenerationRecord>>.value(<AiGenerationRecord>[record]);

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

AiGenerationRecord _record({String? submittedWallId, String userId = 'user-1'}) => AiGenerationRecord(
  id: 'generation-1',
  userId: userId,
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
  status: submittedWallId == null ? 'success' : 'submitted',
  submittedWallId: submittedWallId,
);

const AiSubmissionMetadata _emptyMetadata = (title: '', description: '', category: '', tags: <String>[]);

void main() {
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
      toastCalls.add(call.method);
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
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
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
      toastCalls.add(call.method);
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

    await tester.pumpWidget(MaterialApp(home: AiWallpaperTabPage(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Submit wallpaper for community review'), findsOneWidget);

    final submitButton = find.bySemanticsLabel('Submit wallpaper for community review');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
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
      toastCalls.add(call.method);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

    await tester.pumpWidget(
      MaterialApp(home: AiWallpaperTabPage(repository: _FakeAiGenerationRepository(_record(), metadata))),
    );
    await tester.pumpAndSettle();
    final submitButton = find.bySemanticsLabel('Submit wallpaper for community review');
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
      toastCalls.add(call.method);
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
    final submitButton = find.bySemanticsLabel('Submit wallpaper for community review');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(submissions, 1);
    final Future<void> refresh = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pumpAndSettle();
    await refresh;

    expect(find.bySemanticsLabel('Submit wallpaper for community review'), findsNothing);
    expect(submissions, 1);
    expect(toastCalls, isNotEmpty);
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
      toastCalls.add(call.method);
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

    Future<void> submitOnce() async {
      final button = find.bySemanticsLabel('Submit wallpaper for community review');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
    }

    await submitOnce();
    expect(find.bySemanticsLabel('Submit wallpaper for community review'), findsOneWidget);
    await submitOnce();
    expect(find.bySemanticsLabel('Submit wallpaper for community review'), findsNothing);
    expect(find.textContaining('Submission status is unconfirmed'), findsOneWidget);
    expect(submissions, 2);
    expect(toastCalls, isNotEmpty);
  });

  testWidgets('does not apply a completed submission to a newly active account', (tester) async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);
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
        home: AiWallpaperTabPage(
          repository: _FakeAiGenerationRepository(_record(), metadata),
          submitForTesting: () => submission.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final submitButton = find.bySemanticsLabel('Submit wallpaper for community review');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pump();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-2'
      ..loggedIn = true;
    submission.complete(WallSubmissionResult.submitted);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Submit wallpaper for community review'), findsNothing);
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
        home: AiWallpaperTabPage(repository: repository, submitForTesting: () => submission.future),
      ),
    );
    await tester.pumpAndSettle();
    final submitButton = find.bySemanticsLabel('Submit wallpaper for community review');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    submission.complete(WallSubmissionResult.submitted);
    await tester.pump();

    expect(repository.savedRecords.single.submittedWallId, 'AIGENERATION');
  });
}
