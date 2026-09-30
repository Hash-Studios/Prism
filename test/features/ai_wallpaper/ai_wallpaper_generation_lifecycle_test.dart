// Firebase platform-interface packages are transitive, but these fakes need them.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
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

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService({this.check});

  final Future<bool> Function()? check;

  @override
  Future<bool> hasConnection() => check?.call() ?? Future<bool>.value(true);
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
  _FakeAiGenerationRepository(this.record, {this.generation, this.variation});

  final AiGenerationRecord record;
  final Future<AiGenerationRecord> Function()? generation;
  final Future<AiGenerationRecord> Function()? variation;
  final List<({AiStylePreset style, AiQualityTier quality, int coinsSpent})> requests = [];

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
  }) {
    requests.add((style: stylePreset, quality: qualityTier, coinsSpent: coinsSpent));
    return generation!.call();
  }

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
    ConnectivityService? connectivity,
  }) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await getIt.reset();
    getIt.registerSingleton<ConnectivityService>(connectivity ?? _FakeConnectivityService());
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
      toasts.add(call);
      return true;
    });
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    connection.complete(false);
    await tester.pump();

    expect(toasts, isEmpty);
    expect(spendCalls, 0);
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

    expect(spends.single['amount'], AiQualityTier.fast.coinCost);
    expect(repository.requests.single, (style: AiStylePreset.abstract, quality: AiQualityTier.fast, coinsSpent: 10));
    final started = analytics.events.whereType<AiGenerateStartedEvent>().single;
    expect(started.quality, 'fast');
    expect(started.style, 'abstract');
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
      toasts.add(call);
      return true;
    });
    final generate = find.text('Generate');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    generation.completeError(StateError('generation failed'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(refunds, hasLength(1));
    expect(refunds.single['transactionId'], 'reservation-1');
    expect(refunds.single.containsKey('amount'), isFalse);
    expect(analytics.events.whereType<AiGenerateFailedEvent>(), hasLength(1));
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

    final Finder generate = find.text('Generate');
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
    await tester.pump();
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

  testWidgets('a started-event failure rolls back the reservation and releases loading', (tester) async {
    final recorder = _RecordingAnalytics(throwOn: (event) => event is AiGenerateStartedEvent);
    AnalyticsRuntime.instance = recorder;
    var requests = 0;
    final refunds = await generateAndCountRefunds(tester, () async {
      requests++;
      return _record(id: 'generated-1');
    });

    expect(refunds, 1);
    expect(requests, 0);
    expect(recorder.events.whereType<AiGenerateFailedEvent>(), hasLength(1));
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
}
