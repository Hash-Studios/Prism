import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/views/widgets/coin_gate_sheet.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/offline_asset_fixture.dart';
import '../../support/wait_for_real_io.dart';

class _OrderedAnalytics extends FakeAppAnalytics {
  _OrderedAnalytics(this.onTrack);

  final void Function(AnalyticsEvent event) onTrack;

  @override
  Future<void> track(AnalyticsEvent event) {
    onTrack(event);
    return super.track(event);
  }
}

class _RecordingStats extends Fake implements ViewStatsRepository {
  final List<(String, WallpaperAction)> actions = <(String, WallpaperAction)>[];

  @override
  Future<Result<void>> recordWallpaperAction(String wallId, WallpaperAction action) async {
    actions.add((wallId, action));
    return Result.success(null);
  }
}

const String _link = 'https://example.com/walls/sunset.jpg';
const String _encodedLink = 'https://example.com/walls/wall%231.jpg';
const String _ledgerKey = 'pendingDownloads_v2';
const String _legacyMarkerKey = 'pendingDownloadMarker';

const Map<String, Object> _spent = <String, Object>{
  'success': true,
  'changed': true,
  'previousBalance': 100,
  'currentBalance': 95,
  'delta': -5,
  'transactionId': 'spend_tx',
};

class _FailingRetainAssetStore extends OfflineAssetStore {
  _FailingRetainAssetStore({required this.cachedFile, required super.directory});

  final File cachedFile;
  bool retainAttempted = false;

  @override
  Future<File?> lookup(String source) async => cachedFile;

  @override
  Future<File> retain(String source, {File? file}) async {
    retainAttempted = true;
    throw FileSystemException('Could not persist the offline original.');
  }
}

class _CacheMissOfflineAssetStore extends OfflineAssetStore {
  _CacheMissOfflineAssetStore({required super.directory});

  @override
  Future<File?> lookup(String source) async => null;
}

class _SwitchingAccountAssetStore extends OfflineAssetStore {
  _SwitchingAccountAssetStore({required this.onLookup, required super.directory});

  final void Function() onLookup;

  @override
  Future<File?> lookup(String source) async {
    onLookup();
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = CoinsTestBackend();
  late FakeAppAnalytics fakeAnalytics;
  late List<Map<String, dynamic>> spendCalls;
  late List<Object?> enqueued;
  late List<SaveMediaRequest> saved;
  late List<Object?> toastMessages;
  late bool enqueueSucceeds;
  late void Function() onEnqueue;
  late List<String> downloadsOnDisk;
  late Directory tempDir;
  late OfflineAssetFixture offlineFixture;
  late String tinted;

  const enqueueChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
    PrismMediaHostApi.pigeonChannelCodec,
  );
  const saveChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.Prism.PrismMediaHostApi.saveMedia',
    PrismMediaHostApi.pigeonChannelCodec,
  );
  const listChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
    PrismMediaHostApi.pigeonChannelCodec,
  );
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  /// Tells the service the server has [left] grace downloads, as a spend reply does.
  Future<void> useGraceDownloads(int left) async {
    final prior = backend.onCall;
    backend.onCall = (name, parameters) async => <String, Object>{
      'success': true,
      'changed': false,
      'bypassed': true,
      'currentBalance': 100,
      'graceDownloadsLeft': left,
      'reason': 'grace_download',
    };
    await CoinsService.instance.spend(CoinSpendAction.wallpaperDownload);
    backend.onCall = prior;
  }

  setUp(() async {
    await backend.install();
    offlineFixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineFixture.install(immediateResolver: true);
    tinted = offlineFixture.createImageSync('tinted.png').path;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    fakeAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = fakeAnalytics;
    spendCalls = <Map<String, dynamic>>[];
    enqueued = <Object?>[];
    saved = <SaveMediaRequest>[];
    toastMessages = <Object?>[];
    enqueueSucceeds = true;
    onEnqueue = () {};
    downloadsOnDisk = <String>[];
    tempDir = Directory.systemTemp.createTempSync('prism_dl_test');
    backend.onCall = (name, parameters) async {
      if (name == 'spendCoins') spendCalls.add(parameters);
      return _spent;
    };
    messenger.setMockDecodedMessageHandler<Object?>(enqueueChannel, (message) async {
      enqueued.add((message! as List<Object?>).single);
      onEnqueue();
      return <Object?>[OperationResult(success: enqueueSucceeds, message: enqueueSucceeds ? null : 'no space')];
    });
    messenger.setMockDecodedMessageHandler<Object?>(saveChannel, (message) async {
      saved.add((message! as List<Object?>).single! as SaveMediaRequest);
      return <Object?>[OperationResult(success: true)];
    });
    messenger.setMockDecodedMessageHandler<Object?>(
      listChannel,
      (_) async => <Object?>[DownloadItemsResult(success: true, items: downloadsOnDisk)],
    );
    messenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']);
      return true;
    });
    AdConsent.instance = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () async => true,
    );
    CoinsService.instance.isLinkDownloaded = (_) => false;
    app_state.prismUser.coins = 100;
    CoinsService.instance.balanceNotifier.value = 100;
    await useGraceDownloads(0);
    await getIt<SettingsLocalDataSource>().set('notificationPermissionPromptedV2', true);
  });

  tearDown(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(enqueueChannel, null);
    messenger.setMockDecodedMessageHandler<Object?>(saveChannel, null);
    messenger.setMockDecodedMessageHandler<Object?>(listChannel, null);
    messenger.setMockMethodCallHandler(toastChannel, null);
    AnalyticsRuntime.reset();
    AdConsent.instance = AdConsent();
    tempDir.deleteSync(recursive: true);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt<SettingsLocalDataSource>().delete(_ledgerKey);
    await getIt<SettingsLocalDataSource>().delete(_legacyMarkerKey);
    await getIt<SettingsLocalDataSource>().delete('notificationPermissionPromptedV2');
    CoinsService.instance.abandonedDownloadAfter = const Duration(minutes: 2);
    CoinsService.instance.pendingRetryInterval = const Duration(seconds: 30);
    await offlineFixture.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool premiumContent = false,
    String? title,
    String? creator,
    String contentId = 'wall-1',
    String sourceContext = 'detail',
    String? requestId,
    VoidCallback? onOpen,
    VoidCallback? onDownloaded,
    DownloadVariant? variant,
    String link = _link,
    WallpaperSource source = WallpaperSource.wallhaven,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: DownloadButton(
            link: link,
            label: 'Save',
            isPremiumContent: premiumContent,
            contentId: contentId,
            wallpaperSource: source,
            sourceContext: sourceContext,
            requestId: requestId,
            wallpaperTitle: title,
            creatorName: creator,
            onOpenDownloads: onOpen,
            variant: variant,
            onDownloaded: onDownloaded,
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    for (int i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    final Stopwatch elapsed = Stopwatch()..start();
    while (!condition()) {
      if (elapsed.elapsed >= const Duration(seconds: 5)) {
        throw TimeoutException('Download action did not complete.');
      }
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byType(PrimaryActionPill));
    await settle(tester);
  }

  Future<File> fixtureImage(WidgetTester tester, String name) async =>
      (await tester.runAsync(() => offlineFixture.createImage(name)))!;

  String semanticsLabel(WidgetTester tester) => tester.getSemantics(find.byType(PrimaryActionPill)).label;

  Iterable<DownloadResultEvent> results() => fakeAnalytics.events.whereType<DownloadResultEvent>();

  List<Map<String, dynamic>> ledger() {
    final String raw = getIt<SettingsLocalDataSource>().get<String>(_ledgerKey, defaultValue: '');
    return raw.isEmpty ? <Map<String, dynamic>>[] : (jsonDecode(raw) as List<Object?>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> restart(WidgetTester tester) async {
    return (await tester.runAsync(() async {
      final List<Map<String, dynamic>> refunds = <Map<String, dynamic>>[];
      backend.onCall = (name, parameters) async {
        refunds.add(parameters);
        return const <String, Object>{
          'success': true,
          'changed': true,
          'previousBalance': 95,
          'currentBalance': 100,
          'delta': 5,
        };
      };
      CoinsService.instance.abandonedDownloadAfter = Duration.zero;
      await CoinsService.instance.refundAbandonedDownload();
      return refunds;
    }))!;
  }

  Future<dynamic> Function(String name, Map<String, dynamic> parameters) offlineRefunds() => (name, parameters) async {
    if (name == 'spendCoins') {
      spendCalls.add(parameters);
      return _spent;
    }
    throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
  };

  String txIdOf(int spendIndex) => 'spend_${backend.userId}_${spendCalls[spendIndex]['requestId']}';

  Iterable<Object?> refundedIds(List<Map<String, dynamic>> refunds) =>
      refunds.map((Map<String, dynamic> refund) => refund['transactionId']);

  void signOut() => app_state.prismUser = app_constants.createGuestPrismUser();

  void signInAgain() => app_state.prismUser = app_constants.createGuestPrismUser()
    ..id = backend.userId
    ..loggedIn = true
    ..coins = 100;

  Completer<bool> holdSaves() {
    final Completer<bool> result = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      enqueueChannel,
      (message) async {
        enqueued.add((message! as List<Object?>).single);
        onEnqueue();
        return <Object?>[OperationResult(success: await result.future)];
      },
    );
    return result;
  }

  group('price on the pill', () {
    testWidgets('a signed-in user sees the coin price', (tester) async {
      await pump(tester);

      expect(find.text('Save · ${CoinPolicy.wallpaperDownload}'), findsOneWidget);
      expect(semanticsLabel(tester), 'Save. Costs ${CoinPolicy.wallpaperDownload} coins');
    });

    testWidgets('a Pro wallpaper shows its higher price', (tester) async {
      await pump(tester, premiumContent: true);

      expect(find.text('Save · ${CoinPolicy.premiumWallpaperDownload}'), findsOneWidget);
      expect(semanticsLabel(tester), 'Save. Costs ${CoinPolicy.premiumWallpaperDownload} coins');
    });

    testWidgets('free downloads left show on a standard wallpaper', (tester) async {
      await tester.runAsync(() => useGraceDownloads(2));
      await pump(tester);

      expect(find.text('Save · Free · 2 left'), findsOneWidget);
      expect(semanticsLabel(tester), 'Save. Free, 2 free downloads left');
    });

    testWidgets('free downloads do not apply to a Pro wallpaper', (tester) async {
      await tester.runAsync(() => useGraceDownloads(2));
      await pump(tester, premiumContent: true);

      expect(find.text('Save · ${CoinPolicy.premiumWallpaperDownload}'), findsOneWidget);
    });

    testWidgets('an active premium pass makes a Pro wallpaper free', (tester) async {
      CoinsService.instance.setPassesForTest(Passes(premiumPassUntil: DateTime.now().add(const Duration(hours: 3))));
      addTearDown(() => CoinsService.instance.passesNotifier.value = Passes.empty);
      await pump(tester, premiumContent: true);

      expect(find.text('Save · Free'), findsOneWidget);
      expect(semanticsLabel(tester), 'Save. Free with your pass');
    });

    testWidgets('a free download with an empty balance goes to the server, not to the low balance sheet', (
      tester,
    ) async {
      await tester.runAsync(() => useGraceDownloads(1));
      app_state.prismUser.coins = 0;
      CoinsService.instance.balanceNotifier.value = 0;
      await pump(tester);
      await tapSave(tester);

      expect(find.text('Not enough coins'), findsNothing);
      expect(spendCalls, hasLength(1));
      expect(enqueued, hasLength(1));
    });

    testWidgets('a Pro user sees that saving is free', (tester) async {
      app_state.prismUser.premium = true;
      await pump(tester);

      expect(find.text('Free with Pro'), findsOneWidget);
      expect(semanticsLabel(tester), 'Save. Free with Pro');
    });

    testWidgets('a guest sees the plain label', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      await pump(tester);

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('a wallpaper already in Downloads reads Saved', (tester) async {
      CoinsService.instance.isLinkDownloaded = (link) => link == _link;
      await pump(tester);

      expect(find.text('Saved'), findsOneWidget);
      expect(semanticsLabel(tester), 'Saved. Already in Downloads');
    });

    testWidgets('a legacy basename/link hit without exact acquisition metadata does not claim Saved', (tester) async {
      CoinsService.instance.isLinkDownloaded = (_) => true;
      await pump(tester, contentId: '', link: 'https://other.example/walls/sunset.jpg');

      expect(find.text('Saved'), findsNothing);
      expect(semanticsLabel(tester), 'Save. Costs 10 coins');
    });

    testWidgets('a legacy row opens the Saved prompt only when its identified native file exists', (tester) async {
      signInAgain();
      await tester.runAsync(
        () => getIt<SettingsLocalDataSource>().set(
          'downloaded_walls_v1',
          jsonEncode(<String, Object>{
            'sunset': <String, String>{'id': 'wall-1', 'source': 'prism'},
          }),
        ),
      );
      final File legacyFile = await fixtureImage(tester, 'sunset.jpg');
      downloadsOnDisk.add(legacyFile.path);

      await pump(tester);
      await tapSave(tester);

      expect(find.text('Already in Downloads'), findsOneWidget);
      expect(spendCalls, isEmpty);
    });

    testWidgets('the pill reads Saved after a download finishes', (tester) async {
      await pump(tester);
      await tapSave(tester);

      expect(find.text('Saved'), findsOneWidget);
    });
  });

  group('an unlocked Drop wall', () {
    setUp(() {
      CoinsService.instance.setDropUnlocksForTest(const <String, DropUnlock>{
        'wall-1': DropUnlock(wallId: 'wall-1', weekKey: '2026-W43', url: _link),
      });
      addTearDown(() => CoinsService.instance.dropsUnlockedNotifier.value = const <String, DropUnlock>{});
    });

    testWidgets('reads free because the unlock already paid for it', (tester) async {
      await pump(tester, source: WallpaperSource.prism);

      expect(find.text('Save · Free'), findsOneWidget);
      expect(semanticsLabel(tester), 'Save. Free, you own this wallpaper');
    });

    testWidgets('saves the unlock url without a coin spend or an original grant', (tester) async {
      final List<String> calls = <String>[];
      backend.onCall = (name, parameters) async {
        calls.add(name);
        return _spent;
      };
      await pump(tester, source: WallpaperSource.prism);
      await tapSave(tester);

      expect(calls, isNot(contains('spendCoins')));
      expect(calls, isNot(contains('resolveOriginalAccess')));
      expect(enqueued, hasLength(1));
      expect((enqueued.single! as DownloadRequest).link, _link);
      expect(results().single.result, 'success');
    });

    testWidgets('another url for the same wall id keeps the normal price', (tester) async {
      await pump(tester, source: WallpaperSource.prism, link: 'https://example.com/walls/other.jpg');

      expect(find.text('Save · ${CoinPolicy.wallpaperDownload}'), findsOneWidget);
    });

    testWidgets('a wallpaper from another source keeps its normal price', (tester) async {
      await pump(tester);

      expect(find.text('Save · ${CoinPolicy.wallpaperDownload}'), findsOneWidget);
    });
  });

  group('saving with enough coins', () {
    testWidgets('a bundled starter saves its local original without coins or server download stats', (tester) async {
      const String original = '/starter-sunset.jpg';
      final File starter = (await tester.runAsync<File?>(
        () => BundledWallpapers.localFileForStarter('starter-sunset', WallpaperSource.prism),
      ))!;
      final OfflineAssetStore assets = OfflineAssetStore.instance;
      final DownloadedWallIndex index = DownloadedWallIndex(getIt<SettingsLocalDataSource>());
      getIt.registerSingleton<DownloadedWallIndex>(index);
      addTearDown(() => getIt.unregister<DownloadedWallIndex>());
      final _RecordingStats stats = _RecordingStats();
      getIt.registerSingleton<RecordWallpaperActionUseCase>(RecordWallpaperActionUseCase(stats));
      addTearDown(() => getIt.unregister<RecordWallpaperActionUseCase>());
      await pump(
        tester,
        contentId: 'starter-sunset',
        link: original,
        requestId: 'browse-request',
        source: WallpaperSource.prism,
      );

      await tester.tap(find.byType(PrimaryActionPill));
      await waitForRealIo(tester, () => results().isNotEmpty, reason: 'bundled original save and durable retention');
      await settle(tester);

      expect(spendCalls, isEmpty);
      expect(enqueued, hasLength(1));
      final DownloadRequest request = enqueued.single! as DownloadRequest;
      expect(request.isLocalFile, isTrue);
      expect(request.link, starter.path);
      expect(request.filenameWithoutExtension, 'starter-sunset');
      final DownloadAttemptEvent attempt = fakeAnalytics.events.whereType<DownloadAttemptEvent>().single;
      final DownloadResultEvent result = results().single;
      expect(result.result, 'success');
      final DownloadWallpaperEvent saved = fakeAnalytics.events.whereType<DownloadWallpaperEvent>().single;
      expect(attempt.operationId, isNotEmpty);
      expect(result.operationId, attempt.operationId);
      expect(saved.operationId, attempt.operationId);
      expect(attempt.requestId, 'browse-request');
      expect(result.requestId, attempt.requestId);
      expect(saved.requestId, attempt.requestId);
      expect(result.itemId, 'starter-sunset');
      expect(result.provider, WallpaperSource.prism.name);
      expect(fakeAnalytics.events.indexOf(attempt), lessThan(fakeAnalytics.events.indexOf(saved)));
      expect(stats.actions, isEmpty);
      expect(ledger(), isEmpty);
      final Map<String, String> retained = (await tester.runAsync(assets.localPaths))!;
      expect(retained, contains(original));
      expect(
        await tester.runAsync(() => File(retained[original]!).readAsBytes()),
        await tester.runAsync(starter.readAsBytes),
      );
      expect(index.hasAcquired(link: original, id: 'starter-sunset', source: WallpaperSource.prism), isFalse);
    });

    testWidgets('a bundled starter variant saves the prepared file under its variant identity without coins', (
      tester,
    ) async {
      const String original = '/starter-sunset.jpg';
      await pump(
        tester,
        contentId: 'starter-sunset',
        source: WallpaperSource.prism,
        link: original,
        variant: DownloadVariant(key: 'tint-ff8800', prepare: () async => tinted),
      );

      await tapSave(tester);

      expect(spendCalls, isEmpty);
      expect(enqueued, hasLength(1));
      final DownloadRequest request = enqueued.single! as DownloadRequest;
      expect(request.link, tinted);
      expect(request.link, isNot(original));
      expect(request.isLocalFile, isTrue);
      expect(request.filenameWithoutExtension, 'starter-sunset_tint-ff8800');
      expect(ledger(), isEmpty);
    });

    testWidgets('failed variant preparation closes the attempt once without saving', (tester) async {
      await pump(
        tester,
        variant: DownloadVariant(key: 'failed', prepare: () async => throw StateError('prepare failed')),
      );
      await tapSave(tester);
      final DownloadAttemptEvent attempt = fakeAnalytics.events.whereType<DownloadAttemptEvent>().single;
      expect(results(), hasLength(1));
      expect(results().single.result, 'failed');
      expect(results().single.operationId, attempt.operationId);
      expect(enqueued, isEmpty);
      expect(spendCalls, isEmpty);
    });

    testWidgets('spends without a sheet, names the ledger row and leaves no download entry behind', (tester) async {
      await pump(tester, title: 'Sunset over the bay');
      await tapSave(tester);

      expect(find.text('Not enough coins'), findsNothing);
      expect(enqueued, hasLength(1));
      expect(spendCalls.single['label'], 'Sunset over the bay');
      expect(ledger(), isEmpty);
      expect(results().single.result, 'success');
      expect(fakeAnalytics.events.whereType<DownloadAttemptEvent>().single.source, 'detail');
    });

    testWidgets('a finished save counts one download for the wallpaper', (tester) async {
      final stats = _RecordingStats();
      getIt.registerSingleton<RecordWallpaperActionUseCase>(RecordWallpaperActionUseCase(stats));
      addTearDown(() => getIt.unregister<RecordWallpaperActionUseCase>());
      await pump(tester);
      await tapSave(tester);

      expect(stats.actions, <(String, WallpaperAction)>[('wall-1', WallpaperAction.download)]);
    });

    testWidgets('the ledger row falls back to the creator name', (tester) async {
      await pump(tester, creator: 'Ana');
      await tapSave(tester);

      expect(spendCalls.single['label'], 'Wallpaper by Ana');
    });

    testWidgets('changing wallpaper while spend is pending keeps the tap snapshot for its save and follow-ups', (
      tester,
    ) async {
      const String nextLink = 'https://example.com/walls/mountain.jpg';
      final Completer<void> spendReply = Completer<void>();
      final List<String> callbacks = <String>[];
      final _RecordingStats stats = _RecordingStats();
      getIt.registerSingleton<RecordWallpaperActionUseCase>(RecordWallpaperActionUseCase(stats));
      addTearDown(() => getIt.unregister<RecordWallpaperActionUseCase>());
      backend.onCall = (name, parameters) async {
        if (name == 'spendCoins') {
          spendCalls.add(parameters);
          await spendReply.future;
          return _spent;
        }
        return const <String, Object>{
          'success': true,
          'changed': true,
          'previousBalance': 95,
          'currentBalance': 100,
          'delta': 5,
        };
      };

      await pump(
        tester,
        title: 'Sunset over the bay',
        contentId: 'wall-old',
        sourceContext: 'old-detail',
        onDownloaded: () => callbacks.add('old'),
      );
      await tester.tap(find.byType(PrimaryActionPill));
      await tester.pump();
      expect(spendCalls, hasLength(1));
      expect(ledger().single['link'], _link);

      await pump(
        tester,
        link: nextLink,
        premiumContent: true,
        title: 'Mountain lake',
        creator: 'New Creator',
        contentId: 'wall-new',
        sourceContext: 'new-detail',
        onDownloaded: () => callbacks.add('new'),
      );
      spendReply.complete();
      await settle(tester);

      final DownloadRequest request = enqueued.single! as DownloadRequest;
      final DownloadWallpaperEvent downloadEvent = fakeAnalytics.events.whereType<DownloadWallpaperEvent>().single;
      expect(spendCalls.single['action'], CoinSpendAction.wallpaperDownload.name);
      expect(spendCalls.single['label'], 'Sunset over the bay');
      expect(spendCalls.single['reason'], 'content_wall-old');
      expect(ledger(), isEmpty);
      expect(request.link, _link);
      expect(request.filenameWithoutExtension, 'sunset');
      expect(downloadEvent.link, _link);
      expect(downloadEvent.sourceContext, 'old-detail');
      expect(downloadEvent.premiumContent, isFalse);
      expect(stats.actions, <(String, WallpaperAction)>[('wall-old', WallpaperAction.download)]);
      expect(callbacks, <String>['old']);
    });

    testWidgets('a download that fails after the charge is refunded and reported', (tester) async {
      enqueueSucceeds = false;
      backend.onCall = (name, parameters) async {
        if (name == 'spendCoins') return _spent;
        return const <String, Object>{
          'success': true,
          'changed': true,
          'previousBalance': 95,
          'currentBalance': 100,
          'delta': 5,
        };
      };
      await pump(tester);
      await tapSave(tester);

      final result = results().single;
      expect(result.result, 'failed');
      expect(result.reason, 'enqueue_failed');
      expect(result.stage, 'download');
      expect(find.text('Save · ${CoinPolicy.wallpaperDownload}'), findsOneWidget);
      expect(ledger(), isEmpty);
    });
  });

  group('saving without enough coins', () {
    testWidgets('names the missing coins and offers an ad with the ads left today', (tester) async {
      app_state.prismUser.coins = 2;
      CoinsService.instance.balanceNotifier.value = 2;
      backend.onCall = (name, parameters) => Future<dynamic>.error(StateError('no call expected'));
      await pump(tester);
      await tapSave(tester);

      expect(find.text('Not enough coins'), findsOneWidget);
      expect(
        find.textContaining('You need ${CoinPolicy.wallpaperDownload - 2} more coins to save this wallpaper.'),
        findsOneWidget,
      );
      expect(find.text(watchAdOptionLabel(AppLocalizationsEn())), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(enqueued, isEmpty);
    });

    testWidgets('hides the ad option and says why when ad consent was refused', (tester) async {
      AdConsent.instance = AdConsent(
        requestInfoUpdate: () async {},
        showFormIfRequired: () async {},
        canRequestAds: () async => false,
      );
      app_state.prismUser.coins = 2;
      CoinsService.instance.balanceNotifier.value = 2;
      await pump(tester);
      await tapSave(tester);

      expect(find.textContaining('Watch a video'), findsNothing);
      expect(find.textContaining('Ads are off. Change this in Settings > Privacy.'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
    });

    testWidgets('a Pro wallpaper that needs more than one ad says so', (tester) async {
      app_state.prismUser.coins = 0;
      CoinsService.instance.balanceNotifier.value = 0;
      await pump(tester, premiumContent: true);
      await tapSave(tester);

      expect(find.textContaining('You need ${CoinPolicy.premiumWallpaperDownload} more coins'), findsOneWidget);
      expect(find.textContaining('Each ad adds ${CoinsService.instance.adsRewardNow}.'), findsOneWidget);
    });

    testWidgets('leaving the sheet reports a cancelled save', (tester) async {
      app_state.prismUser.coins = 2;
      CoinsService.instance.balanceNotifier.value = 2;
      await pump(tester);
      await tapSave(tester);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);

      expect(results().single.result, 'cancelled');
      expect(results().single.stage, 'gate');
    });
  });

  group('already downloaded', () {
    Future<String> fileOnDisk() async {
      final file = File('${tempDir.path}/sunset.jpg')..writeAsStringSync('x');
      return file.path;
    }

    testWidgets('offers Open and a paid download again, and does not charge', (tester) async {
      downloadsOnDisk = <String>[await fileOnDisk()];
      CoinsService.instance.isLinkDownloaded = (link) => link == _link;
      var opened = 0;
      await pump(tester, onOpen: () => opened++);
      await tester.runAsync(() async {});
      await tapSave(tester);

      expect(find.text('Already in Downloads'), findsOneWidget);
      expect(find.text('Download again (-${CoinPolicy.wallpaperDownload} coins)'), findsOneWidget);
      expect(spendCalls, isEmpty);

      await tester.tap(find.text('Open'));
      await settle(tester);

      expect(opened, 1);
      expect(spendCalls, isEmpty);
      expect(enqueued, isEmpty);
    });

    testWidgets('Download again charges and downloads', (tester) async {
      downloadsOnDisk = <String>[await fileOnDisk()];
      CoinsService.instance.isLinkDownloaded = (link) => link == _link;
      await pump(tester);
      await tapSave(tester);

      await tester.tap(find.text('Download again (-${CoinPolicy.wallpaperDownload} coins)'));
      await settle(tester);

      expect(spendCalls, hasLength(1));
      expect(enqueued, hasLength(1));
    });

    testWidgets('a Pro user sees no price on Download again', (tester) async {
      app_state.prismUser.premium = true;
      downloadsOnDisk = <String>[await fileOnDisk()];
      CoinsService.instance.isLinkDownloaded = (link) => link == _link;
      await pump(tester);
      await tapSave(tester);

      expect(find.text('Download again'), findsOneWidget);
    });

    testWidgets('a standard wallpaper repeat shows free while grace downloads remain', (tester) async {
      await tester.runAsync(() => useGraceDownloads(2));
      downloadsOnDisk = <String>[await fileOnDisk()];
      CoinsService.instance.isLinkDownloaded = (link) => link == _link;
      await pump(tester);
      await tapSave(tester);

      expect(find.text('Download again'), findsOneWidget);
      expect(find.text('Download again (-${CoinPolicy.wallpaperDownload} coins)'), findsNothing);
    });

    testWidgets('an unlocked Drop wall repeat shows free', (tester) async {
      CoinsService.instance.setDropUnlocksForTest(const <String, DropUnlock>{
        'wall-1': DropUnlock(wallId: 'wall-1', weekKey: '2026-W43', url: _link),
      });
      addTearDown(() => CoinsService.instance.dropsUnlockedNotifier.value = const <String, DropUnlock>{});
      downloadsOnDisk = <String>[await fileOnDisk()];
      CoinsService.instance.isLinkDownloaded = (link) => link == _link;
      await pump(tester, source: WallpaperSource.prism);
      await tapSave(tester);

      expect(find.text('Download again'), findsOneWidget);
      expect(find.text('Download again (-${CoinPolicy.wallpaperDownload} coins)'), findsNothing);
    });

    testWidgets('an index entry whose file is gone does not block the save', (tester) async {
      CoinsService.instance.isLinkDownloaded = (link) => link == _link;
      await pump(tester);
      await tapSave(tester);

      expect(find.text('Already in Downloads'), findsNothing);
      expect(enqueued, hasLength(1));
    });
  });

  group('with a variant', () {
    DownloadVariant variant({String key = 'tint-ff8800', Future<String> Function()? prepare}) =>
        DownloadVariant(key: key, prepare: prepare ?? () async => tinted);

    testWidgets('charges the usual price, saves the prepared file into Downloads under the variant name', (
      tester,
    ) async {
      final index = DownloadedWallIndex(getIt<SettingsLocalDataSource>());
      getIt.registerSingleton<DownloadedWallIndex>(index);
      addTearDown(() => getIt.unregister<DownloadedWallIndex>());
      int prepared = 0;
      await pump(
        tester,
        variant: variant(
          prepare: () async {
            prepared++;
            return tinted;
          },
        ),
      );
      await tapSave(tester);

      expect(prepared, 1);
      expect(spendCalls.single['action'], 'wallpaperDownload');
      final DownloadRequest request = enqueued.single! as DownloadRequest;
      expect(request.link, tinted);
      expect(request.isLocalFile, isTrue);
      expect(request.filenameWithoutExtension, 'sunset_tint-ff8800');
      expect(saved, isEmpty);
      expect(results().single.result, 'success');
      final variantFile = File('${tempDir.path}/sunset_tint-ff8800.png')
        ..writeAsBytesSync(File(tinted).readAsBytesSync());
      downloadsOnDisk = [variantFile.path];
      expect(
        index.hasAcquired(link: 'sunset_tint-ff8800.png', id: 'wall-1', source: WallpaperSource.wallhaven),
        isTrue,
      );
      expect((await index.localFileForLink('sunset_tint-ff8800.png'))?.path, variantFile.path);
      expect(await index.localFileForIdentity(id: 'wall-1', source: WallpaperSource.wallhaven), isNull);
    });

    testWidgets('a plain download still sends the URL as a remote file named after it', (tester) async {
      await pump(tester);
      await tapSave(tester);

      final DownloadRequest request = enqueued.single! as DownloadRequest;
      expect(request.link, _link);
      expect(request.isLocalFile, isFalse);
      expect(request.filenameWithoutExtension, 'sunset');
    });

    testWidgets('a stale local original is promoted after the normal coin gate and retained only on save success', (
      tester,
    ) async {
      signInAgain();
      final Directory offlineDirectory = Directory('${tempDir.path}/offline');
      final OfflineAssetStore assets = (await tester.runAsync(
        () async => OfflineAssetStore(directory: offlineDirectory),
      ))!;
      OfflineAssetStore.testOverride = assets;
      addTearDown(() => OfflineAssetStore.testOverride = null);
      final File cached = await fixtureImage(tester, 'cached-stale.png');
      final File retained = (await tester.runAsync(() => assets.retain(_link, file: cached)))!;
      final DownloadedWallIndex index = DownloadedWallIndex(getIt<SettingsLocalDataSource>());
      getIt.registerSingleton<DownloadedWallIndex>(index);
      addTearDown(() => getIt.unregister<DownloadedWallIndex>());

      final Completer<void> completed = Completer<void>();
      await pump(tester, onDownloaded: completed.complete);
      await tapSave(tester);
      await pumpUntil(tester, () => completed.isCompleted);
      await completed.future;
      await tester.pump(const Duration(seconds: 1));

      final DownloadRequest request = enqueued.single! as DownloadRequest;
      expect(spendCalls, hasLength(1));
      expect(request.isLocalFile, isTrue);
      expect(request.link, retained.path);
      expect(await tester.runAsync(() => assets.lookup(_link)), isNotNull);
      expect(index.hasAcquired(link: _link, id: 'wall-1', source: WallpaperSource.wallhaven), isTrue);
    });

    testWidgets('a successful native save is not reported as saved offline when durable retention fails', (
      tester,
    ) async {
      final File cached = await fixtureImage(tester, 'cached-retain-failure.png');
      final _FailingRetainAssetStore assets = _FailingRetainAssetStore(
        cachedFile: cached,
        directory: Directory('${tempDir.path}/offline'),
      );
      OfflineAssetStore.testOverride = assets;
      addTearDown(() => OfflineAssetStore.testOverride = null);
      final DownloadedWallIndex index = DownloadedWallIndex(getIt<SettingsLocalDataSource>());
      getIt.registerSingleton<DownloadedWallIndex>(index);
      addTearDown(() => getIt.unregister<DownloadedWallIndex>());

      await pump(tester);
      await tapSave(tester);

      expect(enqueued, hasLength(1));
      expect(assets.retainAttempted, isTrue);
      expect(find.text('Saved'), findsOneWidget);
      expect(semanticsLabel(tester), 'Saved. Already in Downloads');
      expect(toastMessages.join(' ').toLowerCase(), isNot(contains('offline')));
      expect(index.hasAcquired(link: _link, id: 'wall-1', source: WallpaperSource.wallhaven), isTrue);
      expect(spendCalls, hasLength(1));
    });

    testWidgets('an exact same-owner acquisition restores its retained original without another coin spend', (
      tester,
    ) async {
      signInAgain();
      final OfflineAssetStore assets = (await tester.runAsync(
        () async => OfflineAssetStore(directory: Directory('${tempDir.path}/offline')),
      ))!;
      OfflineAssetStore.testOverride = assets;
      addTearDown(() => OfflineAssetStore.testOverride = null);
      final File cached = await fixtureImage(tester, 'cached-acquired.png');
      final File retained = (await tester.runAsync(() => assets.retain(_link, file: cached)))!;
      final DownloadedWallIndex index = DownloadedWallIndex(getIt<SettingsLocalDataSource>());
      getIt.registerSingleton<DownloadedWallIndex>(index);
      addTearDown(() async {
        await index.clearOwner(app_state.prismUser.id);
        await getIt.unregister<DownloadedWallIndex>();
      });
      await index.remember(
        link: _link,
        id: 'wall-1',
        source: WallpaperSource.wallhaven,
        ownerId: app_state.prismUser.id,
      );

      final Completer<void> completed = Completer<void>();
      await pump(tester, onDownloaded: completed.complete);
      await tapSave(tester);
      await pumpUntil(tester, () => completed.isCompleted);
      await completed.future;
      await tester.pump(const Duration(seconds: 1));

      expect(spendCalls, isEmpty);
      expect(enqueued, hasLength(1));
      final DownloadRequest request = enqueued.single! as DownloadRequest;
      expect(request.isLocalFile, isTrue);
      expect(request.link, retained.path);
    });

    testWidgets('a same-basename URL is charged despite another URL acquired by this owner', (tester) async {
      signInAgain();
      const String otherUrl = 'https://other.example/walls/sunset.jpg';
      final OfflineAssetStore assets = (await tester.runAsync(
        () async => OfflineAssetStore(directory: Directory('${tempDir.path}/offline')),
      ))!;
      OfflineAssetStore.testOverride = assets;
      addTearDown(() => OfflineAssetStore.testOverride = null);
      final File cached = await fixtureImage(tester, 'cached-other.png');
      final File retained = (await tester.runAsync(() => assets.retain(otherUrl, file: cached)))!;
      final DownloadedWallIndex index = DownloadedWallIndex(getIt<SettingsLocalDataSource>());
      getIt.registerSingleton<DownloadedWallIndex>(index);
      addTearDown(() async {
        await index.clearOwner(app_state.prismUser.id);
        await getIt.unregister<DownloadedWallIndex>();
      });
      await index.remember(
        link: _link,
        id: 'wall-1',
        source: WallpaperSource.wallhaven,
        ownerId: app_state.prismUser.id,
      );

      final Completer<void> completed = Completer<void>();
      await pump(tester, link: otherUrl, onDownloaded: completed.complete);
      await tapSave(tester);
      await pumpUntil(tester, () => completed.isCompleted);
      await completed.future;
      await tester.pump(const Duration(seconds: 1));

      expect(spendCalls, hasLength(1));
      expect((enqueued.single! as DownloadRequest).link, retained.path);
    });

    testWidgets('a download finishing after an account switch records acquisition only for the initiating user', (
      tester,
    ) async {
      signInAgain();
      final String ownerA = app_state.prismUser.id;
      final OfflineAssetStore assets = (await tester.runAsync(
        () async => _CacheMissOfflineAssetStore(directory: Directory('${tempDir.path}/offline')),
      ))!;
      OfflineAssetStore.testOverride = assets;
      addTearDown(() => OfflineAssetStore.testOverride = null);
      final DownloadedWallIndex index = DownloadedWallIndex(getIt<SettingsLocalDataSource>());
      getIt.registerSingleton<DownloadedWallIndex>(index);
      addTearDown(() => getIt.unregister<DownloadedWallIndex>());
      final Completer<void> requestStarted = Completer<void>();
      final Completer<void> completed = Completer<void>();
      final Completer<bool> nativeSave = holdSaves();
      onEnqueue = requestStarted.complete;

      await pump(tester, onDownloaded: completed.complete);
      await tester.tap(find.byType(PrimaryActionPill));
      await tester.pump();
      await pumpUntil(tester, () => requestStarted.isCompleted);
      await requestStarted.future;
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'account-b'
        ..loggedIn = true;
      nativeSave.complete(true);
      await pumpUntil(tester, () => completed.isCompleted);
      await completed.future;
      await tester.pump(const Duration(seconds: 2));

      expect(index.hasAcquired(link: _link, id: 'wall-1', source: WallpaperSource.wallhaven), isFalse);
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = ownerA
        ..loggedIn = true;
      expect(index.hasAcquired(link: _link, id: 'wall-1', source: WallpaperSource.wallhaven), isTrue);
    });

    testWidgets('an account switch before the coin gate cancels instead of charging the new account', (tester) async {
      signInAgain();
      final String ownerA = app_state.prismUser.id;
      final DownloadedWallIndex index = DownloadedWallIndex(SettingsLocalDataSource(InMemoryLocalStore()));
      getIt.registerSingleton<DownloadedWallIndex>(index);
      addTearDown(() async {
        await index.clearOwner(ownerA);
        await getIt.unregister<DownloadedWallIndex>();
      });
      await index.remember(link: _link, id: 'wall-1', source: WallpaperSource.wallhaven, ownerId: ownerA);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        listChannel,
        (_) async {
          app_state.prismUser = app_constants.createGuestPrismUser()
            ..id = 'account-b'
            ..loggedIn = true
            ..coins = 100;
          return <Object?>[DownloadItemsResult(success: true, items: const <String>[])];
        },
      );

      await pump(tester);
      await tapSave(tester);

      expect(app_state.prismUser.id, 'account-b');
      expect(spendCalls, isEmpty);
      expect(enqueued, isEmpty);
    });

    testWidgets('an account switch while finding a server-granted original reports the switch, not a failure', (
      tester,
    ) async {
      signInAgain();
      final String ownerA = app_state.prismUser.id;
      final DownloadedWallIndex index = DownloadedWallIndex(SettingsLocalDataSource(InMemoryLocalStore()));
      getIt.registerSingleton<DownloadedWallIndex>(index);
      addTearDown(() async {
        await index.clearOwner(ownerA);
        await getIt.unregister<DownloadedWallIndex>();
      });
      await index.remember(link: _link, id: 'wall-1', source: WallpaperSource.prism, ownerId: ownerA);
      OfflineAssetStore.testOverride = _SwitchingAccountAssetStore(
        directory: Directory('${tempDir.path}/switching'),
        onLookup: () => app_state.prismUser = app_constants.createGuestPrismUser()
          ..id = 'account-b'
          ..loggedIn = true
          ..coins = 100,
      );
      addTearDown(() => OfflineAssetStore.testOverride = null);
      final List<String> calls = <String>[];
      backend.onCall = (name, parameters) async {
        calls.add(name);
        return _spent;
      };

      await pump(tester, source: WallpaperSource.prism);
      await tapSave(tester);

      expect(app_state.prismUser.id, 'account-b');
      expect(calls, isEmpty);
      expect(enqueued, isEmpty);
      final DownloadResultEvent result = results().single;
      expect(result.result, 'cancelled');
      expect(result.reason, 'account_changed');
      expect(toastMessages, contains('Account changed. Please try saving again.'));
    });

    testWidgets('the ledger entry names the variation, not the original link', (tester) async {
      String? ledgerDuringSpend;
      backend.onCall = (name, parameters) async {
        ledgerDuringSpend = getIt<SettingsLocalDataSource>().get<String>(_ledgerKey, defaultValue: '');
        return _spent;
      };
      await pump(tester, variant: variant());
      await tapSave(tester);

      expect(
        (jsonDecode(ledgerDuringSpend!) as List<Object?>).cast<Map<String, dynamic>>().single['link'],
        'sunset_tint-ff8800.png',
      );
    });

    testWidgets('the original in Downloads does not stop a variant save, which is still charged', (tester) async {
      final File original = File('${tempDir.path}/sunset.jpg')..writeAsStringSync('x');
      downloadsOnDisk = <String>[original.path];
      CoinsService.instance.isLinkDownloaded = (identity) => identity == _link;
      await pump(tester, variant: variant());

      expect(find.text('Save · ${CoinPolicy.wallpaperDownload}'), findsOneWidget);
      await tester.runAsync(() async {});
      await tapSave(tester);

      expect(find.text('Already in Downloads'), findsNothing);
      expect(spendCalls, hasLength(1));
      expect((enqueued.single! as DownloadRequest).link, tinted);
    });

    testWidgets('a variant already in Downloads asks first, and only Download again prepares and charges', (
      tester,
    ) async {
      final File onDisk = File('${tempDir.path}/sunset_tint-ff8800.png')..writeAsStringSync('x');
      downloadsOnDisk = <String>[onDisk.path];
      CoinsService.instance.isLinkDownloaded = (identity) => identity == 'sunset_tint-ff8800.png';
      int prepared = 0;
      await pump(
        tester,
        variant: variant(
          prepare: () async {
            prepared++;
            return tinted;
          },
        ),
      );

      expect(find.text('Saved'), findsOneWidget);
      await tester.runAsync(() async {});
      await tapSave(tester);

      expect(find.text('Already in Downloads'), findsOneWidget);
      expect(prepared, 0);
      expect(spendCalls, isEmpty);

      await tester.tap(find.text('Download again (-${CoinPolicy.wallpaperDownload} coins)'));
      await settle(tester);

      expect(prepared, 1);
      expect(spendCalls, hasLength(1));
      expect(enqueued, hasLength(1));
    });

    testWidgets('prepares before the coin sheet and a low balance saves nothing', (tester) async {
      app_state.prismUser.coins = 2;
      CoinsService.instance.balanceNotifier.value = 2;
      int prepared = 0;
      await pump(
        tester,
        variant: variant(
          prepare: () async {
            prepared++;
            return tinted;
          },
        ),
      );
      await tapSave(tester);

      expect(prepared, 1);
      expect(find.text('Not enough coins'), findsOneWidget);
      expect(spendCalls, isEmpty);
      expect(enqueued, isEmpty);
      expect(saved, isEmpty);
    });

    testWidgets('a failed prepare tells the user, charges nothing and can be tried again', (tester) async {
      bool fail = true;
      await pump(
        tester,
        variant: variant(
          prepare: () async {
            if (fail) throw StateError('render failed');
            return tinted;
          },
        ),
      );
      await tapSave(tester);

      expect(toastMessages, contains("Couldn't apply the colour. Try again."));
      expect(spendCalls, isEmpty);
      expect(saved, isEmpty);
      expect(enqueued, isEmpty);
      final DownloadAttemptEvent failedAttempt = fakeAnalytics.events.whereType<DownloadAttemptEvent>().single;
      expect(results(), hasLength(1));
      expect(results().single.operationId, failedAttempt.operationId);
      expect(results().single.result, 'failed');
      expect(results().single.reason, 'preparation_failed');
      expect(results().single.stage, 'prepare');

      fail = false;
      await tapSave(tester);

      expect(spendCalls, hasLength(1));
      expect((enqueued.single! as DownloadRequest).link, tinted);
      final List<DownloadAttemptEvent> attempts = fakeAnalytics.events.whereType<DownloadAttemptEvent>().toList();
      expect(attempts, hasLength(2));
      expect(attempts.last.operationId, isNot(failedAttempt.operationId));
      expect(results(), hasLength(2));
      expect(results().last.operationId, attempts.last.operationId);
      expect(results().last.result, 'success');
    });

    testWidgets('a variant save reads Saved for that variation only', (tester) async {
      await pump(tester, variant: variant());
      await tapSave(tester);

      expect(enqueued, hasLength(1));
      expect(find.text('Saved'), findsOneWidget);

      await pump(tester, variant: variant(key: 'tint-00ff00'));

      expect(find.text('Save · ${CoinPolicy.wallpaperDownload}'), findsOneWidget);
    });

    testWidgets('a colour picked while the first one renders changes neither what is saved nor what is remembered', (
      tester,
    ) async {
      final Completer<String> rendered = Completer<String>();
      final List<String> remembered = <String>[];
      await pump(
        tester,
        variant: variant(prepare: () => rendered.future),
        onDownloaded: () => remembered.add('a'),
      );
      await tester.tap(find.byType(PrimaryActionPill));
      await tester.pump();

      await pump(
        tester,
        variant: variant(key: 'tint-00ff00'),
        onDownloaded: () => remembered.add('b'),
      );
      rendered.complete(tinted);
      await settle(tester);

      expect((enqueued.single! as DownloadRequest).filenameWithoutExtension, 'sunset_tint-ff8800');
      expect(remembered, <String>['a']);
      expect(find.text('Save · ${CoinPolicy.wallpaperDownload}'), findsOneWidget);
    });

    testWidgets('a variant save counts the download for the wallpaper, not for the variation link', (tester) async {
      await pump(tester, variant: variant());
      await tapSave(tester);

      expect(fakeAnalytics.events.whereType<DownloadWallpaperEvent>().single.link, _link);
    });
  });

  group('recovery of a paid variation', () {
    final DownloadVariant tintA = DownloadVariant(key: 'tint-ff8800', prepare: () async => tinted);
    final DownloadVariant tintB = DownloadVariant(key: 'tint-0088ff', prepare: () async => tinted);

    for (final String link in <String>[_link, _encodedLink]) {
      testWidgets('a failed save of tint B is refunded after a restart although tint A was saved ($link)', (
        tester,
      ) async {
        await pump(tester, variant: tintA, link: link);
        await tapSave(tester);
        expect(enqueued, hasLength(1));
        expect(ledger(), isEmpty);

        enqueueSucceeds = false;
        backend.onCall = (name, parameters) async {
          if (name == 'spendCoins') return _spent;
          throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
        };
        await pump(tester, variant: tintB, link: link);
        await tapSave(tester);

        expect(results().last.reason, 'enqueue_failed');
        final Map<String, dynamic> entry = ledger().single;
        expect(entry['link'], tintB.identityOf(link));
        expect(entry['saved'], isFalse);

        final List<Map<String, dynamic>> refunds = await restart(tester);
        await settle(tester);

        expect(refunds.single['action'], 'refund');
        expect(refunds.single['transactionId'], entry['txId']);
        expect(ledger(), isEmpty);
      });
    }

    testWidgets('a paid save of tint A that finished but left its entry is not refunded', (tester) async {
      final CoinMutationResult paid = (await tester.runAsync(
        () => CoinsService.instance.spend(
          CoinSpendAction.wallpaperDownload,
          pendingDownloadLink: tintA.identityOf(_link),
        ),
      ))!;
      await tester.runAsync(() => CoinsService.instance.markPendingDownloadSaved(paid.pendingDownloadTxId));

      final List<Map<String, dynamic>> refunds = await restart(tester);
      await settle(tester);

      expect(refunds, isEmpty);
      expect(ledger(), isEmpty);
    });
  });

  group('download ledger', () {
    testWidgets('marks the entry saved right after the native save, before analytics and follow-ups', (tester) async {
      final List<String> order = <String>[];
      String savedFlags() => ledger().map((Map<String, dynamic> e) => '${e['saved']}').join(',');
      onEnqueue = () => order.add('save:${savedFlags()}');
      AnalyticsRuntime.instance = _OrderedAnalytics((AnalyticsEvent event) {
        if (event is DownloadWallpaperEvent) order.add('analytics:${savedFlags()}');
      });
      await pump(tester, onDownloaded: () => order.add('follow-up:${savedFlags()}'));
      await tapSave(tester);

      expect(order.first, 'save:false');
      expect(order.skip(1), unorderedEquals(<String>['analytics:true', 'follow-up:true']));
      expect(ledger(), isEmpty);
    });

    testWidgets('an unconfirmed refund survives a later prompt that the user dismissed for the same link', (
      tester,
    ) async {
      enqueueSucceeds = false;
      backend.onCall = (name, parameters) async {
        if (name == 'spendCoins') {
          spendCalls.add(parameters);
          return _spent;
        }
        throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
      };
      await pump(tester);
      await tapSave(tester);
      final String txId = 'spend_${app_state.prismUser.id}_${spendCalls.single['requestId']}';

      app_state.prismUser.coins = 2;
      CoinsService.instance.balanceNotifier.value = 2;
      await tapSave(tester);
      expect(find.text('Not enough coins'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(results().last.result, 'cancelled');

      final List<Map<String, dynamic>> refunds = await restart(tester);
      await settle(tester);

      expect(refunds.map((Map<String, dynamic> refund) => refund['transactionId']), <Object?>[txId]);
      expect(ledger(), isEmpty);
    });

    testWidgets('a save the server did not charge leaves the earlier unconfirmed refund to be refunded', (
      tester,
    ) async {
      enqueueSucceeds = false;
      backend.onCall = (name, parameters) async {
        if (name == 'spendCoins') {
          spendCalls.add(parameters);
          return _spent;
        }
        throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
      };
      await pump(tester);
      await tapSave(tester);
      final String failedTxId = 'spend_${app_state.prismUser.id}_${spendCalls.single['requestId']}';

      enqueueSucceeds = true;
      backend.onCall = (name, parameters) async => const <String, Object>{
        'success': true,
        'changed': false,
        'bypassed': true,
        'previousBalance': 100,
        'currentBalance': 100,
        'delta': 0,
      };
      await tapSave(tester);
      expect(enqueued, hasLength(2));

      final List<Map<String, dynamic>> refunds = await restart(tester);
      await settle(tester);

      expect(refunds.map((Map<String, dynamic> refund) => refund['transactionId']), <Object?>[failedTxId]);
      expect(ledger(), isEmpty);
    });

    testWidgets('a retry of the same link that saves leaves the earlier failed attempt to be refunded', (tester) async {
      enqueueSucceeds = false;
      backend.onCall = (name, parameters) async {
        if (name == 'spendCoins') {
          spendCalls.add(parameters);
          return _spent;
        }
        throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
      };
      await pump(tester);
      await tapSave(tester);
      final String failedTxId = 'spend_${app_state.prismUser.id}_${spendCalls.single['requestId']}';

      enqueueSucceeds = true;
      await tapSave(tester);
      expect(enqueued, hasLength(2));
      expect(spendCalls, hasLength(2));

      final List<Map<String, dynamic>> refunds = await restart(tester);
      await settle(tester);

      expect(refunds.map((Map<String, dynamic> refund) => refund['transactionId']), <Object?>[failedTxId]);
      expect(ledger(), isEmpty);
    });
  });

  group('each paid save is settled by its own transaction', () {
    setUp(() => CoinsService.instance.pendingRetryInterval = const Duration(milliseconds: 50));

    testWidgets('a retry that saves while recovery runs does not clear the failed attempt of the same link', (
      tester,
    ) async {
      IosWallpaperGuideSession.shown = false;
      CoinsService.instance.abandonedDownloadAfter = Duration.zero;
      enqueueSucceeds = false;
      backend.onCall = offlineRefunds();
      await pump(tester);
      await tapSave(tester);
      final String failedTxId = txIdOf(0);
      expect(ledger().map((Map<String, dynamic> e) => e['txId']), <Object?>[failedTxId]);

      enqueueSucceeds = true;
      await tapSave(tester);
      expect(find.text('Open Photos'), findsOneWidget);
      await tester.runAsync(CoinsService.instance.refundAbandonedDownload);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(find.text('Open Photos'), findsNothing);

      final List<Map<String, dynamic>> refunds = await restart(tester);
      await settle(tester);

      expect(refundedIds(refunds), <Object?>[failedTxId]);
      expect(ledger(), isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('two buttons on one wallpaper: the one that saved is not refunded, the one that failed is', (
      tester,
    ) async {
      final List<Completer<bool>> saves = <Completer<bool>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        enqueueChannel,
        (message) async {
          enqueued.add((message! as List<Object?>).single);
          final Completer<bool> done = Completer<bool>();
          saves.add(done);
          return <Object?>[OperationResult(success: await done.future)];
        },
      );
      backend.onCall = offlineRefunds();
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(
            body: Column(
              children: <Widget>[
                DownloadButton(
                  key: ValueKey<String>('a'),
                  link: _link,
                  label: 'Save',
                  wallpaperSource: WallpaperSource.wallhaven,
                ),
                DownloadButton(
                  key: ValueKey<String>('b'),
                  link: _link,
                  label: 'Save',
                  wallpaperSource: WallpaperSource.wallhaven,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PrimaryActionPill).at(0));
      await settle(tester);
      await tester.tap(find.byType(PrimaryActionPill).at(1));
      await settle(tester);
      expect(saves, hasLength(2));

      saves[0].complete(true);
      await settle(tester);
      saves[1].complete(false);
      await settle(tester);

      final List<Map<String, dynamic>> refunds = await restart(tester);
      await settle(tester);

      expect(refundedIds(refunds), <Object?>[txIdOf(1)]);
      expect(ledger(), isEmpty);
    });

    testWidgets('leaving the page while the charge is in flight releases the entry when the refund fails', (
      tester,
    ) async {
      final Completer<void> reply = Completer<void>();
      backend.onCall = (name, parameters) async {
        if (name == 'spendCoins') {
          spendCalls.add(parameters);
          await reply.future;
          return _spent;
        }
        throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
      };
      await pump(tester);
      await tester.tap(find.byType(PrimaryActionPill));
      await settle(tester);
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(),
        ),
      );
      reply.complete();
      await settle(tester);

      expect(enqueued, isEmpty);
      expect(ledger().map((Map<String, dynamic> e) => e['txId']), <Object?>[txIdOf(0)]);

      final List<Map<String, dynamic>> refunds = await restart(tester);
      await settle(tester);

      expect(refundedIds(refunds), <Object?>[txIdOf(0)]);
      expect(ledger(), isEmpty);
    });

    testWidgets('a payer who signs out during the save keeps no entry when the save succeeds', (tester) async {
      final Completer<bool> save = holdSaves();
      backend.onCall = offlineRefunds();
      await pump(tester);
      await tester.tap(find.byType(PrimaryActionPill));
      await settle(tester);
      expect(enqueued, hasLength(1));

      signOut();
      save.complete(true);
      await settle(tester);

      expect(ledger(), isEmpty);
      signInAgain();
      final List<Map<String, dynamic>> refunds = await restart(tester);
      expect(refunds, isEmpty);
    });

    testWidgets('a payer who signs out during a failing save is refunded after signing in again', (tester) async {
      final Completer<bool> save = holdSaves();
      backend.onCall = offlineRefunds();
      await pump(tester);
      await tester.tap(find.byType(PrimaryActionPill));
      await settle(tester);
      expect(enqueued, hasLength(1));

      signOut();
      save.complete(false);
      await settle(tester);

      expect(ledger().map((Map<String, dynamic> e) => e['txId']), <Object?>[txIdOf(0)]);
      signInAgain();
      final List<Map<String, dynamic>> refunds = await restart(tester);
      await settle(tester);

      expect(refundedIds(refunds), <Object?>[txIdOf(0)]);
      expect(ledger(), isEmpty);
    });
  });

  group('download that outlasts the grace period', () {
    testWidgets('a save held open by a system dialog is not refunded, and finishes as a normal save', (tester) async {
      final Completer<void> dialog = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        enqueueChannel,
        (message) async {
          enqueued.add((message! as List<Object?>).single);
          await dialog.future;
          return <Object?>[OperationResult(success: true)];
        },
      );
      await pump(tester);
      await tapSave(tester);
      expect(enqueued, hasLength(1));
      expect(ledger(), hasLength(1));

      final List<Map<String, dynamic>> refunds = await restart(tester);
      expect(refunds, isEmpty);
      expect(ledger(), hasLength(1));

      dialog.complete();
      await settle(tester);
      await tester.runAsync(CoinsService.instance.refundAbandonedDownload);

      expect(refunds, isEmpty);
      expect(ledger(), isEmpty);
      expect(results().single.result, 'success');
    });

    testWidgets('a paid save that ends with an unconfirmed refund is refunded as soon as the tap ends', (tester) async {
      CoinsService.instance.abandonedDownloadAfter = Duration.zero;
      enqueueSucceeds = false;
      int refundCalls = 0;
      final List<Map<String, dynamic>> recovered = <Map<String, dynamic>>[];
      backend.onCall = (name, parameters) async {
        if (name == 'spendCoins') {
          spendCalls.add(parameters);
          return _spent;
        }
        if (++refundCalls == 1) throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
        recovered.add(parameters);
        return const <String, Object>{
          'success': true,
          'changed': true,
          'previousBalance': 95,
          'currentBalance': 100,
          'delta': 5,
        };
      };
      await pump(tester);
      await tapSave(tester);

      expect(results().single.result, 'failed');
      expect(recovered.single['transactionId'], 'spend_${app_state.prismUser.id}_${spendCalls.single['requestId']}');
      expect(ledger(), isEmpty);
    });

    testWidgets('a tap that paid nothing leaves a running download of the same link alone', (tester) async {
      await tester.runAsync(
        () => CoinsService.instance.spend(CoinSpendAction.wallpaperDownload, pendingDownloadLink: _link),
      );
      app_state.prismUser.coins = 2;
      CoinsService.instance.balanceNotifier.value = 2;
      await pump(tester);
      await tapSave(tester);
      expect(find.text('Not enough coins'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(results().last.result, 'cancelled');

      final List<Map<String, dynamic>> refunds = await restart(tester);
      await settle(tester);

      expect(refunds, isEmpty);
      expect(ledger(), hasLength(1));
    });
  });

  group('protected Prism originals', () {
    testWidgets('verified acquired native original is reused by canonical identity without remote access', (
      tester,
    ) async {
      backend.originalAssets['wall-1'] = (premium: true, coins: 20);
      backend.originalAuthenticated = false;
      final index = DownloadedWallIndex(getIt<SettingsLocalDataSource>());
      getIt.registerSingleton<DownloadedWallIndex>(index);
      addTearDown(() => getIt.unregister<DownloadedWallIndex>());
      final file = await fixtureImage(tester, 'acquired.jpg');
      downloadsOnDisk = [file.path];
      await index.remember(link: 'https://old.example/acquired.jpg', id: 'wall-1', source: WallpaperSource.prism);
      expect(
        await OriginalAccessService.instance.resolve(
          url: file.path,
          wallpaperId: 'wall-1',
          wallpaperSource: WallpaperSource.prism,
          action: OriginalAccessAction.edit,
        ),
        file.path,
      );
      await pump(tester, source: WallpaperSource.prism, link: '');
      await tapSave(tester);
      expect(enqueued, hasLength(1));
      final request = enqueued.single! as DownloadRequest;
      expect(request.link, file.path);
      expect(request.isLocalFile, isTrue);
      expect(backend.originalCalls, isEmpty);
      expect(backend.originalDebits, 0);
    });

    testWidgets('insufficient server balance offers recovery without acquiring or transforming', (tester) async {
      backend.originalAssets['wall-1'] = (premium: true, coins: 20);
      backend.originalBalance = 2;
      var transformed = false;
      await pump(
        tester,
        source: WallpaperSource.prism,
        variant: DownloadVariant(
          key: 'tint-ff8800',
          prepare: () async {
            transformed = true;
            return tinted;
          },
          prepareAuthorized: (_) async {
            transformed = true;
            return tinted;
          },
        ),
      );
      await tapSave(tester);
      expect(find.text('Not enough coins'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text(watchAdOptionLabel(AppLocalizationsEn())), findsOneWidget);
      expect(transformed, isFalse);
      expect(enqueued, isEmpty);
      expect(backend.originalCalls.where((call) => call['mode'] != 'quote'), isEmpty);
      expect(backend.originalDebits, 0);
    });

    testWidgets('server premium metadata and price override a stale free client snapshot', (tester) async {
      backend.originalAssets['wall-1'] = (premium: true, coins: 20);
      await pump(tester, source: WallpaperSource.prism, premiumContent: false, link: '');
      await tapSave(tester);
      expect(enqueued, isEmpty);
      expect(find.textContaining('20'), findsWidgets);
      expect(backend.originalCalls.every((call) => call['mode'] == 'quote'), isTrue);
      await tester.tap(find.text('Download').last);
      await settle(tester);
      expect(enqueued, hasLength(1));
      expect((enqueued.single! as DownloadRequest).link, 'https://signed.test/wall-1');
      expect((enqueued.single! as DownloadRequest).filenameWithoutExtension, 'wall-1');
      expect(backend.originalDebits, 1);
      expect(backend.originalBalance, 80);
      expect(CoinsService.instance.balanceNotifier.value, 80);
      expect(app_state.prismUser.coins, 80);
      expect(spendCalls, isEmpty);
    });

    for (final entitlement in ['pro', 'pass']) {
      testWidgets('server $entitlement grants premium access without a client-side spend', (tester) async {
        backend.originalAssets['wall-1'] = (premium: true, coins: 20);
        backend.originalPro = entitlement == 'pro';
        backend.originalPass = entitlement == 'pass';
        await pump(tester, source: WallpaperSource.prism, premiumContent: true);
        await tapSave(tester);
        expect(enqueued, hasLength(1));
        expect(backend.originalDebits, 0);
        expect(backend.originalCalls.where((call) => call['mode'] != 'quote'), hasLength(1));
        expect(spendCalls, isEmpty);
      });
    }

    testWidgets('authentication denial never transforms or saves an arbitrary cached Prism original', (tester) async {
      backend.originalAssets['wall-1'] = (premium: true, coins: 20);
      backend.originalAuthenticated = false;
      final cached = await fixtureImage(tester, 'unacquired.jpg');
      offlineFixture.mapSource(_link, cached);
      var transformed = false;
      await pump(
        tester,
        source: WallpaperSource.prism,
        variant: DownloadVariant(
          key: 'tint-ff8800',
          prepare: () async {
            transformed = true;
            return tinted;
          },
          prepareAuthorized: (_) async {
            transformed = true;
            return tinted;
          },
        ),
      );
      await tapSave(tester);
      expect(transformed, isFalse);
      expect(enqueued, isEmpty);
      expect(backend.originalDebits, 0);
      expect(spendCalls, isEmpty);
    });

    testWidgets('account switch after quote never acquires or saves for the next account', (tester) async {
      backend.originalAssets['wall-1'] = (premium: true, coins: 20);
      await pump(tester, source: WallpaperSource.prism);
      await tapSave(tester);
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'other-user'
        ..loggedIn = true;
      await tester.tap(find.text('Download').last);
      await settle(tester);
      expect(backend.originalCalls.where((call) => call['mode'] != 'quote'), isEmpty);
      expect(backend.originalDebits, 0);
      expect(enqueued, isEmpty);
    });

    testWidgets('a failed native save retries its original receipt without a second debit', (tester) async {
      backend.originalAssets['wall-1'] = (premium: true, coins: 20);
      enqueueSucceeds = false;
      await pump(tester, source: WallpaperSource.prism);
      await tapSave(tester);
      await tester.tap(find.text('Download').last);
      await settle(tester);
      expect(backend.originalDebits, 1);
      enqueueSucceeds = true;
      await tapSave(tester);
      expect(enqueued, hasLength(2));
      expect(backend.originalDebits, 1);
      final acquisitions = backend.originalCalls.where((call) => call['mode'] != 'quote').toList();
      expect(CoinsService.instance.balanceNotifier.value, 80);
      expect(app_state.prismUser.coins, 80);
      expect(acquisitions[0]['requestId'], acquisitions[1]['requestId']);
      expect(spendCalls, isEmpty);
    });
  });

  group('guest', () {
    for (final scenario in <({String name, String link, String id, WallpaperSource source})>[
      (name: 'Prism', link: '', id: 'wall-1', source: WallpaperSource.prism),
      (name: 'Wallhaven', link: _link, id: 'wall-1', source: WallpaperSource.wallhaven),
      (name: 'Pexels', link: _link, id: 'wall-1', source: WallpaperSource.pexels),
      (name: 'local file', link: '/local.jpg', id: 'wall-1', source: WallpaperSource.downloaded),
      (name: 'bundled starter', link: '/starter-sunset.jpg', id: 'starter-sunset', source: WallpaperSource.prism),
      (name: 'unlocked Drop', link: _link, id: 'wall-1', source: WallpaperSource.prism),
    ]) {
      testWidgets('cancelled sign-in blocks ${scenario.name} before preparation, spending or save despite local Pro', (
        tester,
      ) async {
        app_state.prismUser = app_constants.createGuestPrismUser()..premium = true;
        if (scenario.name == 'unlocked Drop') {
          CoinsService.instance.setDropUnlocksForTest(const <String, DropUnlock>{
            'wall-1': DropUnlock(wallId: 'wall-1', weekKey: '2026-W43', url: _link),
          });
          addTearDown(() => CoinsService.instance.dropsUnlockedNotifier.value = const <String, DropUnlock>{});
        }
        final originalSignIn = signedInActionSignIn;
        addTearDown(() => signedInActionSignIn = originalSignIn);
        var signIns = 0;
        var preparations = 0;
        signedInActionSignIn = (_) async {
          signIns++;
          return false;
        };
        await pump(
          tester,
          source: scenario.source,
          link: scenario.link,
          contentId: scenario.id,
          variant: DownloadVariant(
            key: 'variant',
            prepare: () async {
              preparations++;
              return tinted;
            },
          ),
        );

        await tapSave(tester);

        expect(signIns, 1);
        expect(preparations, 0);
        expect(backend.originalCalls, isEmpty);
        expect(spendCalls, isEmpty);
        expect(enqueued, isEmpty);
        expect(saved, isEmpty);
        expect(fakeAnalytics.events.whereType<DownloadAttemptEvent>(), isEmpty);
      });
    }

    testWidgets('a protected Prism original offers sign in without calling original access', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      backend.originalAuthenticated = false;
      await pump(tester, source: WallpaperSource.prism, link: '');
      await tapSave(tester);
      expect(find.text('Sign in to Prism'), findsOneWidget);
      expect(backend.originalCalls, isEmpty);
      expect(enqueued, isEmpty);
      Navigator.of(tester.element(find.text('Sign in to Prism'))).pop();
      await settle(tester);
      expect(fakeAnalytics.events.whereType<DownloadAttemptEvent>(), isEmpty);
    });

    testWidgets('a guest with Pro is asked to sign in without calling original access', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser()..premium = true;
      backend.originalAuthenticated = false;
      backend.originalAssets['wall-1'] = (premium: false, coins: 20);
      final signIn = signedInActionSignIn;
      addTearDown(() => signedInActionSignIn = signIn);
      var signIns = 0;
      signedInActionSignIn = (_) async {
        signIns++;
        return false;
      };
      await pump(tester, source: WallpaperSource.prism, link: '');
      await tapSave(tester);

      expect(signIns, 1);
      expect(backend.originalCalls, isEmpty);
      expect(enqueued, isEmpty);
      expect(fakeAnalytics.events.whereType<DownloadAttemptEvent>(), isEmpty);
    });

    testWidgets('a Pro wallpaper requires sign-in before coins, Pro or an ad', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      await pump(tester, premiumContent: true);
      await tapSave(tester);

      expect(find.text('Sign in to Prism'), findsOneWidget);
      expect(find.text('Pro wallpaper'), findsNothing);
      expect(find.text('Get Pro'), findsNothing);
      expect(find.textContaining('Watch a video'), findsNothing);
      expect(enqueued, isEmpty);
      expect(fakeAnalytics.events.whereType<DownloadAttemptEvent>(), isEmpty);
    });
  });
}
