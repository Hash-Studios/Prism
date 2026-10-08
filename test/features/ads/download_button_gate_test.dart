import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';

class _RecordingStats extends Fake implements ViewStatsRepository {
  final List<(String, WallpaperAction)> actions = <(String, WallpaperAction)>[];

  @override
  Future<Result<void>> recordWallpaperAction(String wallId, WallpaperAction action) async {
    actions.add((wallId, action));
    return Result.success(null);
  }
}

const String _link = 'https://example.com/walls/sunset.jpg';
const String _markerKey = 'pendingDownloadMarker';

const Map<String, Object> _spent = <String, Object>{
  'success': true,
  'changed': true,
  'previousBalance': 100,
  'currentBalance': 95,
  'delta': -5,
  'transactionId': 'spend_tx',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = CoinsTestBackend();
  late FakeAppAnalytics fakeAnalytics;
  late List<Map<String, dynamic>> spendCalls;
  late List<Object?> enqueued;
  late bool enqueueSucceeds;
  late List<String> downloadsOnDisk;
  late Directory tempDir;

  const enqueueChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
    PrismMediaHostApi.pigeonChannelCodec,
  );
  const listChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
    PrismMediaHostApi.pigeonChannelCodec,
  );
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() async {
    await backend.install();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    fakeAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = fakeAnalytics;
    spendCalls = <Map<String, dynamic>>[];
    enqueued = <Object?>[];
    enqueueSucceeds = true;
    downloadsOnDisk = <String>[];
    tempDir = Directory.systemTemp.createTempSync('prism_dl_test');
    backend.onCall = (name, parameters) async {
      if (name == 'spendCoins') spendCalls.add(parameters);
      return _spent;
    };
    messenger.setMockDecodedMessageHandler<Object?>(enqueueChannel, (message) async {
      enqueued.add((message! as List<Object?>).single);
      return <Object?>[OperationResult(success: enqueueSucceeds, message: enqueueSucceeds ? null : 'no space')];
    });
    messenger.setMockDecodedMessageHandler<Object?>(
      listChannel,
      (_) async => <Object?>[DownloadItemsResult(success: true, items: downloadsOnDisk)],
    );
    messenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    AdConsent.instance = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () async => true,
    );
    CoinsService.instance.isLinkDownloaded = (_) => false;
    app_state.prismUser.coins = 100;
    CoinsService.instance.balanceNotifier.value = 100;
    await getIt<SettingsLocalDataSource>().set('notificationPermissionPromptedV2', true);
  });

  tearDown(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(enqueueChannel, null);
    messenger.setMockDecodedMessageHandler<Object?>(listChannel, null);
    messenger.setMockMethodCallHandler(toastChannel, null);
    AnalyticsRuntime.reset();
    AdConsent.instance = AdConsent();
    tempDir.deleteSync(recursive: true);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt<SettingsLocalDataSource>().delete(_markerKey);
    await getIt<SettingsLocalDataSource>().delete('notificationPermissionPromptedV2');
  });

  Future<void> pump(
    WidgetTester tester, {
    bool premiumContent = false,
    String? title,
    String? creator,
    VoidCallback? onOpen,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadButton(
            link: _link,
            label: 'Save',
            isPremiumContent: premiumContent,
            contentId: 'wall-1',
            sourceContext: 'detail',
            wallpaperTitle: title,
            creatorName: creator,
            onOpenDownloads: onOpen,
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byType(PrimaryActionPill));
    await settle(tester);
  }

  String semanticsLabel(WidgetTester tester) => tester.getSemantics(find.byType(PrimaryActionPill)).label;

  Iterable<DownloadResultEvent> results() => fakeAnalytics.events.whereType<DownloadResultEvent>();

  group('price on the pill', () {
    testWidgets('a signed-in user sees the coin price', (tester) async {
      await pump(tester);

      expect(find.text('Save · 5'), findsOneWidget);
      expect(semanticsLabel(tester), 'Save. Costs 5 coins');
    });

    testWidgets('a Pro wallpaper shows its higher price', (tester) async {
      await pump(tester, premiumContent: true);

      expect(find.text('Save · 15'), findsOneWidget);
      expect(semanticsLabel(tester), 'Save. Costs 15 coins');
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

    testWidgets('the pill reads Saved after a download finishes', (tester) async {
      await pump(tester);
      await tapSave(tester);

      expect(find.text('Saved'), findsOneWidget);
    });
  });

  group('saving with enough coins', () {
    testWidgets('spends without a sheet, names the ledger row and clears the download marker', (tester) async {
      await pump(tester, title: 'Sunset over the bay');
      await tapSave(tester);

      expect(find.text('Not enough coins'), findsNothing);
      expect(enqueued, hasLength(1));
      expect(spendCalls.single['label'], 'Sunset over the bay');
      expect(getIt<SettingsLocalDataSource>().get<String>(_markerKey, defaultValue: ''), isEmpty);
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
      expect(find.text('Save · 5'), findsOneWidget);
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
      expect(find.textContaining('You need 3 more coins to save this wallpaper.'), findsOneWidget);
      expect(find.text('Watch ad (+10)'), findsOneWidget);
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

      expect(find.textContaining('Watch ad'), findsNothing);
      expect(find.textContaining('Ads are off. Change this in Settings > Privacy.'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
    });

    testWidgets('a Pro wallpaper that needs more than one ad says so', (tester) async {
      app_state.prismUser.coins = 0;
      CoinsService.instance.balanceNotifier.value = 0;
      await pump(tester, premiumContent: true);
      await tapSave(tester);

      expect(find.textContaining('You need 15 more coins'), findsOneWidget);
      expect(find.textContaining('Each ad adds 10.'), findsOneWidget);
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
      expect(find.text('Download again (-5 coins)'), findsOneWidget);
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

      await tester.tap(find.text('Download again (-5 coins)'));
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

    testWidgets('an index entry whose file is gone does not block the save', (tester) async {
      CoinsService.instance.isLinkDownloaded = (link) => link == _link;
      await pump(tester);
      await tapSave(tester);

      expect(find.text('Already in Downloads'), findsNothing);
      expect(enqueued, hasLength(1));
    });
  });

  group('guest', () {
    testWidgets('a Pro wallpaper offers sign in or Pro, never an ad', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      await pump(tester, premiumContent: true);
      await tapSave(tester);

      expect(find.text('Pro wallpaper'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Get Pro'), findsOneWidget);
      expect(find.textContaining('Watch ad'), findsNothing);
      expect(enqueued, isEmpty);
      expect(fakeAnalytics.events.whereType<DownloadAttemptEvent>().single.premium, isTrue);
    });
  });
}
