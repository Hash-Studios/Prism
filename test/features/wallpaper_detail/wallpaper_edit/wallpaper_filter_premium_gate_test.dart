import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_snapshot_store.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/ads/biz/bloc/ads_bloc.j.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/usecases/ads_usecases.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:async_wallpaper/pigeon_impl_api.dart' as wallpaper_api;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/wait_for_real_io.dart';

const String _functionsChannel = 'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call';
const String _mediaChannel = 'dev.flutter.pigeon.Prism.PrismMediaHostApi.saveMedia';
const String _setWallpaperChannel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.applyWallpaper';
const MethodChannel _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
const MethodChannel _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const StandardMessageCodec _codec = StandardMessageCodec();

Finder _iconButton(String tooltip) => find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton));

Widget _screenHost(String sourcePath, {AdsBloc? adsBloc}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

  home: adsBloc == null
      ? WallpaperFilterScreen(filePath: sourcePath)
      : BlocProvider<AdsBloc>.value(
          value: adsBloc,
          child: WallpaperFilterScreen(filePath: sourcePath),
        ),
);

class _MockCreateRewardedAdUseCase extends Mock implements CreateRewardedAdUseCase {}

class _MockShowRewardedAdUseCase extends Mock implements ShowRewardedAdUseCase {}

Future<Uint8List> _smallPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = const Color(0xFFFF0000));
  final ui.Picture picture = recorder.endRecording();
  try {
    final ui.Image image = await picture.toImage(8, 8);
    try {
      final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory economyDirectory;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() async {
    // The coin gate asks for ad consent before it shows a prompt. The real flow needs the Google UMP plugin.
    AdConsent.instance = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () async => true,
      privacyOptionsRequired: () async => false,
      showPrivacyOptions: () async {},
    );
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'test'
      ..loggedIn = true
      ..coins = 0;
    CoinsService.instance.balanceNotifier.value = 0;
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    economyDirectory = Directory.systemTemp.createTempSync('wallpaper_filter_economy_');
    CoinsService.instance.setEconomySnapshotStoreForTest(
      EconomySnapshotStore(store: DurableJsonStore('wallpaper_filter', directory: economyDirectory)),
    );
  });

  tearDown(() async {
    AdConsent.instance = AdConsent();
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
    if (economyDirectory.existsSync()) economyDirectory.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_functionsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_mediaChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_setWallpaperChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      null,
    );
  });

  testWidgets('spends before saving an edited download and ignores same-frame duplicate actions', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_gate_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);

    final Completer<void> allowSpend = Completer<void>();
    final Completer<void> spendStarted = Completer<void>();
    final Completer<void> mediaSaved = Completer<void>();
    var spendCalls = 0;
    var saveCalls = 0;
    SaveMediaRequest? savedRequest;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _toastChannel,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (_) async => directory.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_functionsChannel, (
      message,
    ) async {
      final List<Object?> arguments = _codec.decodeMessage(message)! as List<Object?>;
      final Map<Object?, Object?> call = arguments.single! as Map<Object?, Object?>;
      if (call['functionName'] == 'spendCoins') {
        spendCalls++;
        if (!spendStarted.isCompleted) spendStarted.complete();
        await allowSpend.future;
        return _codec.encodeMessage(<Object?>[
          <String, Object?>{'success': true, 'changed': false, 'previousBalance': 0, 'currentBalance': 0, 'delta': 0},
        ]);
      }
      fail('Unexpected callable: ${call['functionName']}');
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_mediaChannel, (
      message,
    ) async {
      saveCalls++;
      final List<Object?> arguments = PrismMediaHostApi.pigeonChannelCodec.decodeMessage(message)! as List<Object?>;
      savedRequest = arguments.single! as SaveMediaRequest;
      mediaSaved.complete();
      return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: true)]);
    });

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForEditorReady(tester);
    await _tapInvert(tester);
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();

    final IconButton download = tester.widget<IconButton>(_iconButton('Download'));
    final IconButton set = tester.widget<IconButton>(_iconButton('Set as wallpaper'));
    download.onPressed!();
    download.onPressed!();
    set.onPressed!();
    set.onPressed!();
    await tester.pump();
    await _waitForSignal(tester, spendStarted, 'premium filter spend starts');

    expect(spendCalls, 1);
    expect(saveCalls, 0);
    expect(tester.widget<IconButton>(_iconButton('Reset')).onPressed, isNull);
    expect(tester.widget<IconButton>(_iconButton('Set as wallpaper')).onPressed, isNull);
    final Finder firstSlider = find.byType(Slider).first;
    final double sliderBefore = tester.widget<Slider>(firstSlider).value;
    await tester.drag(firstSlider, const Offset(80, 0), warnIfMissed: false);
    await tester.pump();
    expect(tester.widget<Slider>(firstSlider).value, sliderBefore);

    allowSpend.complete();
    await _waitForSignal(tester, mediaSaved, 'native media save completes');
    expect(savedRequest?.kind, SaveMediaKind.wallpaper);
    await waitForRealIo(
      tester,
      () => tester.widget<IconButton>(_iconButton('Reset')).onPressed != null,
      reason: 'editor re-enabled after native save',
    );
    expect(spendCalls, 1);
    expect(saveCalls, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('does not save an edited image when the screen is disposed during the spend', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_gate_dispose_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);

    final Completer<void> allowSpend = Completer<void>();
    final Completer<void> spendStarted = Completer<void>();
    app_state.prismUser.coins = 20;
    CoinsService.instance.balanceNotifier.value = 20;
    var saveCalls = 0;
    var refundCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _toastChannel,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (_) async => directory.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_functionsChannel, (
      message,
    ) async {
      final List<Object?> arguments = _codec.decodeMessage(message)! as List<Object?>;
      final Map<Object?, Object?> call = arguments.single! as Map<Object?, Object?>;
      if (call['functionName'] == 'spendCoins') {
        spendStarted.complete();
        await allowSpend.future;
        return _codec.encodeMessage(<Object?>[
          <String, Object?>{
            'success': true,
            'changed': true,
            'previousBalance': 20,
            'currentBalance': 15,
            'delta': -CoinPolicy.premiumFilter,
            'transactionId': 'disposed-filter-spend',
          },
        ]);
      }
      if (call['functionName'] == 'awardCoins') {
        refundCalls++;
        final Map<Object?, Object?> parameters = call['parameters']! as Map<Object?, Object?>;
        expect(parameters['transactionId'], 'disposed-filter-spend');
        return _codec.encodeMessage(<Object?>[
          <String, Object?>{
            'success': true,
            'changed': true,
            'previousBalance': 15,
            'currentBalance': 20,
            'delta': CoinPolicy.premiumFilter,
          },
        ]);
      }
      fail('Unexpected callable: ${call['functionName']}');
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_mediaChannel, (_) async {
      saveCalls++;
      return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: true)]);
    });

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForEditorReady(tester);
    await _tapInvert(tester);
    await tester.tap(_iconButton('Download'));
    await tester.pump();
    await _waitForSignal(tester, spendStarted, 'premium filter spend before screen disposal');

    await tester.pumpWidget(const SizedBox());
    allowSpend.complete();
    await _waitForCount(tester, () => refundCalls, 1, 'refund after screen disposal');
    await _waitForCount(tester, () => CoinsService.instance.balanceNotifier.value, 20, 'refunded balance');

    expect(saveCalls, 0);
    expect(refundCalls, 1);
    expect(CoinsService.instance.balanceNotifier.value, 20);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('refunds a failed export and charges again on the next attempt', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_gate_refund_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);
    app_state.prismUser.coins = 20;
    CoinsService.instance.balanceNotifier.value = 20;

    var spendCalls = 0;
    var refundCalls = 0;
    var saveCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _toastChannel,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (_) async => directory.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_functionsChannel, (
      message,
    ) async {
      final List<Object?> arguments = _codec.decodeMessage(message)! as List<Object?>;
      final Map<Object?, Object?> call = arguments.single! as Map<Object?, Object?>;
      switch (call['functionName']) {
        case 'spendCoins':
          spendCalls++;
          return _codec.encodeMessage(<Object?>[
            <String, Object?>{
              'success': true,
              'changed': true,
              'previousBalance': 20,
              'currentBalance': 15,
              'delta': -CoinPolicy.premiumFilter,
              'transactionId': 'filter-spend-$spendCalls',
            },
          ]);
        case 'awardCoins':
          refundCalls++;
          final Map<Object?, Object?> parameters = call['parameters']! as Map<Object?, Object?>;
          expect(parameters['action'], 'refund');
          expect(parameters['transactionId'], 'filter-spend-1');
          return _codec.encodeMessage(<Object?>[
            <String, Object?>{
              'success': true,
              'changed': true,
              'previousBalance': 15,
              'currentBalance': 20,
              'delta': CoinPolicy.premiumFilter,
            },
          ]);
        default:
          fail('Unexpected callable: ${call['functionName']}');
      }
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_mediaChannel, (_) async {
      saveCalls++;
      return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: saveCalls > 1)]);
    });

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForEditorReady(tester);
    await _tapInvert(tester);

    await tester.tap(_iconButton('Download'));
    await _waitForCount(tester, () => saveCalls, 1, 'first native save');
    await _waitForCount(tester, () => refundCalls, 1, 'failed export refund');
    expect(spendCalls, 1);
    expect(CoinsService.instance.balanceNotifier.value, 20);
    await _waitForEditorReady(tester);

    AnalyticsRuntime.instance = _ThrowOnDownloadAnalytics();
    await tester.tap(_iconButton('Download'));
    await _waitForCount(tester, () => saveCalls, 2, 'second native save');
    await _waitForEditorReady(tester);

    expect(spendCalls, 2, reason: 'a failed export must not unlock premium filters for this session');
    expect(refundCalls, 1);
    expect(CoinsService.instance.balanceNotifier.value, 15);

    await tester.tap(_iconButton('Download'));
    await _waitForCount(tester, () => saveCalls, 3, 'session-unlocked native save');
    await _waitForEditorReady(tester);

    expect(spendCalls, 2, reason: 'a successful export should unlock later exports in this session');
    expect(refundCalls, 1);
    expect(CoinsService.instance.balanceNotifier.value, 15);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not refund after native wallpaper set succeeds but analytics throws', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_set_analytics_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);
    app_state.prismUser.coins = 20;
    CoinsService.instance.balanceNotifier.value = 20;

    var spendCalls = 0;
    var refundCalls = 0;
    var setCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _toastChannel,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (_) async => directory.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_functionsChannel, (
      message,
    ) async {
      final List<Object?> arguments = _codec.decodeMessage(message)! as List<Object?>;
      final Map<Object?, Object?> call = arguments.single! as Map<Object?, Object?>;
      if (call['functionName'] == 'spendCoins') {
        spendCalls++;
        return _codec.encodeMessage(<Object?>[
          <String, Object?>{
            'success': true,
            'changed': true,
            'previousBalance': 20,
            'currentBalance': 15,
            'delta': -CoinPolicy.premiumFilter,
            'transactionId': 'set-filter-spend',
          },
        ]);
      }
      if (call['functionName'] == 'awardCoins') {
        refundCalls++;
        return _codec.encodeMessage(<Object?>[
          <String, Object?>{
            'success': true,
            'changed': true,
            'previousBalance': 15,
            'currentBalance': 20,
            'delta': CoinPolicy.premiumFilter,
          },
        ]);
      }
      fail('Unexpected callable: ${call['functionName']}');
    });
    const MessageCodec<Object?> wallpaperCodec = wallpaper_api.WallpaperApi.pigeonChannelCodec;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_setWallpaperChannel, (
      _,
    ) async {
      setCalls++;
      return wallpaperCodec.encodeMessage(<Object?>[
        wallpaper_api.OperationResultData(
          status: wallpaper_api.OperationStatusData.applied,
          requestedTarget: wallpaper_api.WallpaperTargetData.home,
          home: wallpaper_api.TargetResultData(status: wallpaper_api.TargetStatusData.applied),
        ),
      ]);
    });

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForEditorReady(tester);
    await _tapInvert(tester);
    await tester.tap(_iconButton('Set as wallpaper'));
    await waitForRealIo(
      tester,
      () => find.byKey(const ValueKey<String>('set-screen-set')).evaluate().isNotEmpty,
      reason: 'Set screen open',
    );
    await tester.pump(const Duration(milliseconds: 500));

    AnalyticsRuntime.instance = _ThrowOnSetWallpaperAnalytics();
    await tester.tap(find.byKey(const ValueKey<String>('set-screen-set')));
    await _waitForCount(tester, () => setCalls, 1, 'native wallpaper set');
    await tester.pump(const Duration(milliseconds: 100));

    expect(spendCalls, 1);
    expect(refundCalls, 0);
    expect(CoinsService.instance.balanceNotifier.value, 15);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps filter retry tags extended after an ad credit is still insufficient', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_gate_retry_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);
    final _MockCreateRewardedAdUseCase createAd = _MockCreateRewardedAdUseCase();
    final _MockShowRewardedAdUseCase showAd = _MockShowRewardedAdUseCase();
    when(() => createAd(const NoParams())).thenAnswer(
      (_) async =>
          Result.success(const AdsEntity(rewardEarned: false, loadingAd: false, adLoaded: true, adFailed: false)),
    );
    when(() => showAd(const NoParams())).thenAnswer(
      (_) async =>
          Result.success(const AdsEntity(rewardEarned: true, loadingAd: false, adLoaded: false, adFailed: false)),
    );
    final AdsBloc adsBloc = AdsBloc(createAd, showAd);
    addTearDown(adsBloc.close);
    app_state.prismUser.coins = 0;
    CoinsService.instance.balanceNotifier.value = 0;
    final FakeAppAnalytics testAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = testAnalytics;

    final List<String> spendTags = <String>[];
    final List<String> awardTags = <String>[];
    final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _toastChannel,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_functionsChannel, (
      message,
    ) async {
      final List<Object?> arguments = _codec.decodeMessage(message)! as List<Object?>;
      final Map<Object?, Object?> call = arguments.single! as Map<Object?, Object?>;
      final Map<Object?, Object?> parameters = call['parameters']! as Map<Object?, Object?>;
      if (call['functionName'] == 'spendCoins') {
        spendTags.add(parameters['sourceTag']! as String);
        return _codec.encodeMessage(<Object?>[
          <String, Object?>{
            'success': false,
            'changed': false,
            'previousBalance': 0,
            'currentBalance': 0,
            'delta': 0,
            'insufficientBalance': true,
          },
        ]);
      }
      if (call['functionName'] == 'awardCoins') {
        awardTags.add(parameters['sourceTag']! as String);
        return _codec.encodeMessage(<Object?>[
          <String, Object?>{'success': true, 'changed': true, 'previousBalance': 0, 'currentBalance': 10, 'delta': 10},
        ]);
      }
      fail('Unexpected callable: ${call['functionName']}');
    });

    await tester.pumpWidget(_screenHost(source.path, adsBloc: adsBloc));
    await _waitForEditorReady(tester);
    await _tapInvert(tester);
    await tester.tap(_iconButton('Download'));
    await _waitForText(tester, 'Need coins for premium filter');
    await tester.tap(find.textContaining('Watch a video'));
    await _waitForCount(tester, () => spendTags.length, 2, 'retry spend');
    await _waitForText(tester, 'Need coins for premium filter');

    expect(spendTags, <String>['coins.filter.download.spend', 'coins.filter.download.watch_and_retry.retry.spend']);
    expect(awardTags, <String>['coins.filter.download.watch_and_retry.rewarded_ad']);
    expect(
      testAnalytics.events.whereType<CoinPremiumFilterSpendAttemptEvent>().map((event) => event.sourceTag),
      <String>['coins.filter.download', 'coins.filter.download.watch_and_retry.retry'],
    );
    expect(testAnalytics.events.whereType<CoinLowBalanceNudgeShownEvent>().map((event) => event.sourceTag), <String>[
      'coins.filter.download.low_balance_nudge',
      'coins.filter.download.watch_and_retry.retry.low_balance_nudge',
    ]);
    expect(
      testAnalytics.events.whereType<CoinFilterWatchAndRetryUsedEvent>().single.sourceTag,
      'coins.filter.download.watch_and_retry',
    );
    expect(settings.get<int>('paywall_ad_watch_count', defaultValue: 0), 1);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the edited export while set options are open and deletes it when canceled', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_set_cancel_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);
    app_state.prismUser.premium = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _toastChannel,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (_) async => directory.path,
    );

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForEditorReady(tester);
    await _tapInvert(tester);
    await tester.tap(_iconButton('Set as wallpaper'));

    final Finder setButton = find.byKey(const ValueKey<String>('set-screen-set'));
    await waitForRealIo(tester, () => setButton.evaluate().isNotEmpty, reason: 'Set screen open');
    expect(setButton, findsOneWidget);

    final List<File> editedFiles = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('/edited.png'))
        .toList();
    expect(editedFiles, hasLength(1));
    final File editedFile = editedFiles.single;
    expect(editedFile.existsSync(), isTrue);
    expect(tester.widget<IconButton>(_iconButton('Reset')).onPressed, isNull);
    expect(tester.widget<IconButton>(_iconButton('Set as wallpaper')).onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip(AppLocalizationsEn().setScreenClose));
    await tester.pump(const Duration(milliseconds: 300));
    final Finder resetButton = _iconButton('Reset');
    await waitForRealIo(
      tester,
      () => !editedFile.existsSync() && tester.widget<IconButton>(resetButton).onPressed != null,
      reason: 'canceled export removed and editor re-enabled',
    );

    expect(editedFile.existsSync(), isFalse);
    expect(Directory(editedFile.parent.path).existsSync(), isFalse);
    expect(tester.widget<IconButton>(resetButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<void> _waitForEditorReady(WidgetTester tester) async {
  await waitForRealIo(tester, () {
    expect(find.text("Couldn't open this wallpaper."), findsNothing);
    final Finder preview = find.descendant(of: find.byType(AspectRatio).first, matching: find.byType(RawImage));
    return tester.widget<PopScope>(find.byType(PopScope)).canPop &&
        tester.widget<IconButton>(_iconButton('Download')).onPressed != null &&
        preview.evaluate().isNotEmpty &&
        tester.widget<RawImage>(preview).image != null;
  }, reason: 'decoded editor preview and enabled Download');
  await tester.pumpAndSettle();
}

Future<void> _tapInvert(WidgetTester tester) async {
  final Finder filters = find.byType(ListView).first;
  for (var attempt = 0; attempt < 6 && find.text('Invert').evaluate().isEmpty; attempt++) {
    await tester.drag(filters, const Offset(-600, 0));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text('Invert'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Invert'));
  await tester.pump();
  await _waitForEditorReady(tester);
}

Future<void> _waitForSignal(WidgetTester tester, Completer<void> signal, String reason) async {
  await waitForRealIo(tester, () => signal.isCompleted, reason: reason);
  await signal.future;
}

Future<void> _waitForCount(WidgetTester tester, int Function() read, int expected, String description) async {
  await waitForRealIo(tester, () => read() >= expected, reason: description);
  expect(read(), expected, reason: description);
}

Future<void> _waitForText(WidgetTester tester, String text) async {
  await waitForRealIo(tester, () => find.text(text).evaluate().isNotEmpty, reason: 'dialog "$text"');
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text(text), findsOneWidget);
}

class _ThrowOnDownloadAnalytics extends NoopAppAnalytics {
  @override
  Future<void> track(AnalyticsEvent event) {
    if (event is DownloadWallpaperEvent) throw StateError('analytics unavailable');
    return super.track(event);
  }
}

class _ThrowOnSetWallpaperAnalytics extends NoopAppAnalytics {
  @override
  Future<void> track(AnalyticsEvent event) {
    if (event is SetWallEvent) throw StateError('analytics unavailable');
    return super.track(event);
  }
}
