// Firebase platform-interface packages are transitive, but these fakes need them.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _FakeConnectivityService implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;
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

class _RecordingAnalytics extends Fake implements AppAnalytics {
  _RecordingAnalytics({this.throwOn});

  final bool Function(AnalyticsEvent event)? throwOn;
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];

  @override
  Future<void> track(AnalyticsEvent event) {
    events.add(event);
    if (throwOn?.call(event) ?? false) throw StateError('analytics failed');
    return Future<void>.value();
  }
}

class _FakeAiGenerationRepository extends Fake implements AiGenerationRepositoryImpl {
  _FakeAiGenerationRepository(this.record, {this.generation, this.variation});

  final AiGenerationRecord record;
  final Future<AiGenerationRecord> Function()? generation;
  final Future<AiGenerationRecord> Function()? variation;

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async => <AiGenerationRecord>[
    record,
  ];

  @override
  Future<AiGenerationRecord> generate({
    required String prompt,
    required AiStylePreset stylePreset,
    required AiQualityTier qualityTier,
    required String targetSize,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    int? seed,
  }) => generation!.call();

  @override
  Future<AiGenerationRecord> generateVariation({
    required String generationId,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    String variationPrompt = '',
    double strength = 0.45,
  }) => variation!.call();
}

AiGenerationRecord _record({String id = 'generation-1'}) => AiGenerationRecord(
  id: id,
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
    _FakeAiGenerationRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await getIt.reset();
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    functions.onCall = onCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..coins = 100
      ..loggedIn = true;
    CoinsService.instance.balanceNotifier.value = 100;
    await tester.pumpWidget(
      MaterialApp(home: AiWallpaperTabPage(repository: repository ?? _FakeAiGenerationRepository(_record()))),
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

    final Finder generate = find.textContaining('Generate  ·');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();
    await reservationStarted.future;
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
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

    final Finder generate = find.textContaining('Generate  ·');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();
    await reservationStarted.future;
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
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
    final Finder refine = find.text('Refine');
    await tester.ensureVisible(refine);
    await tester.tap(refine);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Warmer colors');
    await tester.tap(find.text('Generate refinement'));
    await tester.pump();
    await variationStarted.future;
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
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
        'currentBalance': 10,
        'delta': -10,
        'transactionId': 'reservation-1',
      };
    }, repository: _FakeAiGenerationRepository(_record(), generation: generation));
    final Finder generate = find.textContaining('Generate  ·');
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
  });

  testWidgets('a committed generation is not refunded when a follow-up step throws', (tester) async {
    final _RecordingAnalytics recorder = _RecordingAnalytics(throwOn: (event) => event is AiGenerateSuccessEvent);
    AnalyticsRuntime.instance = recorder;

    final int refunds = await generateAndCountRefunds(tester, () async => _record(id: 'generated-1'));

    expect(recorder.events.whereType<AiChargeCommittedEvent>(), hasLength(1));
    expect(refunds, 0);
    expect(recorder.events.whereType<AiGenerateFailedEvent>(), isEmpty);
  });
}
