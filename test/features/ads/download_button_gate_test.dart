import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/downloaded_link_lookup.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
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
  late List<SaveMediaRequest> saved;
  late List<Object?> toastMessages;
  late bool enqueueSucceeds;
  late List<String> downloadsOnDisk;
  late Directory tempDir;

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

  setUp(() async {
    await backend.install();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    fakeAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = fakeAnalytics;
    spendCalls = <Map<String, dynamic>>[];
    enqueued = <Object?>[];
    saved = <SaveMediaRequest>[];
    toastMessages = <Object?>[];
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
    await getIt<SettingsLocalDataSource>().delete(_markerKey);
    await getIt<SettingsLocalDataSource>().delete('notificationPermissionPromptedV2');
  });

  Future<void> pump(
    WidgetTester tester, {
    bool premiumContent = false,
    String? title,
    String? creator,
    VoidCallback? onOpen,
    DownloadVariant? variant,
    VoidCallback? onDownloaded,
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
            variant: variant,
            onDownloaded: onDownloaded,
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

  group('with a variant', () {
    const String tinted = '/data/user/0/com.hash.prism/cache/prism_tint/1_0.png';

    DownloadVariant variant({String key = 'tint-ff8800', Future<String> Function()? prepare}) =>
        DownloadVariant(key: key, prepare: prepare ?? () async => tinted);

    testWidgets('charges the usual price, saves the prepared file into Downloads under the variant name', (
      tester,
    ) async {
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
    });

    testWidgets('a plain download still sends the URL as a remote file named after it', (tester) async {
      await pump(tester);
      await tapSave(tester);

      final DownloadRequest request = enqueued.single! as DownloadRequest;
      expect(request.link, _link);
      expect(request.isLocalFile, isFalse);
      expect(request.filenameWithoutExtension, 'sunset');
    });

    testWidgets('the recovery marker names the variation, not the original link', (tester) async {
      String? markerDuringSpend;
      backend.onCall = (name, parameters) async {
        markerDuringSpend = getIt<SettingsLocalDataSource>().get<String>(_markerKey, defaultValue: '');
        return _spent;
      };
      await pump(tester, variant: variant());
      await tapSave(tester);

      expect((jsonDecode(markerDuringSpend!) as Map<String, dynamic>)['link'], 'sunset_tint-ff8800.png');
    });

    testWidgets('the original in Downloads does not stop a variant save, which is still charged', (tester) async {
      final File original = File('${tempDir.path}/sunset.jpg')..writeAsStringSync('x');
      downloadsOnDisk = <String>[original.path];
      CoinsService.instance.isLinkDownloaded = (identity) => identity == _link;
      await pump(tester, variant: variant());

      expect(find.text('Save · 5'), findsOneWidget);
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

      await tester.tap(find.text('Download again (-5 coins)'));
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
      expect(fakeAnalytics.events.whereType<DownloadAttemptEvent>(), isEmpty);

      fail = false;
      await tapSave(tester);

      expect(spendCalls, hasLength(1));
      expect((enqueued.single! as DownloadRequest).link, tinted);
    });

    testWidgets('a variant save reads Saved for that variation only', (tester) async {
      await pump(tester, variant: variant());
      await tapSave(tester);

      expect(enqueued, hasLength(1));
      expect(find.text('Saved'), findsOneWidget);

      await pump(tester, variant: variant(key: 'tint-00ff00'));

      expect(find.text('Save · 5'), findsOneWidget);
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
      expect(find.text('Save · 5'), findsOneWidget);
    });

    testWidgets('a variant save counts the download for the wallpaper, not for the variation link', (tester) async {
      await pump(tester, variant: variant());
      await tapSave(tester);

      expect(fakeAnalytics.events.whereType<DownloadWallpaperEvent>().single.link, _link);
    });
  });

  group('recovery of a paid variation', () {
    late DownloadedWallIndex index;
    final DownloadVariant tintA = DownloadVariant(key: 'tint-ff8800', prepare: () async => '/cache/prism_tint/a.png');
    final DownloadVariant tintB = DownloadVariant(key: 'tint-0088ff', prepare: () async => '/cache/prism_tint/b.png');

    setUp(() {
      index = DownloadedWallIndex(getIt<SettingsLocalDataSource>());
      getIt.registerSingleton<DownloadedWallIndex>(index);
      CoinsService.instance.isLinkDownloaded = isLinkInDownloadedIndex;
    });

    tearDown(() async {
      await index.clear();
      getIt.unregister<DownloadedWallIndex>();
    });

    Future<void> ageMarker() async {
      final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
      final Map<String, dynamic> marker =
          jsonDecode(settings.get<String>(_markerKey, defaultValue: '')) as Map<String, dynamic>;
      marker['at'] = DateTime.now().subtract(const Duration(minutes: 3)).millisecondsSinceEpoch;
      await settings.set(_markerKey, jsonEncode(marker));
    }

    Future<List<Map<String, dynamic>>> restart() async {
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
      await CoinsService.instance.refundAbandonedDownload();
      return refunds;
    }

    String marker() => getIt<SettingsLocalDataSource>().get<String>(_markerKey, defaultValue: '');

    testWidgets('a failed save of tint B is refunded after a restart although tint A was saved', (tester) async {
      await index.remember(link: tintA.identityOf(_link), id: 'wall-1', source: WallpaperSource.prism);
      enqueueSucceeds = false;
      backend.onCall = (name, parameters) async {
        if (name == 'spendCoins') return _spent;
        throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
      };
      await pump(tester, variant: tintB);
      await tester.runAsync(() async {});
      await tapSave(tester);

      expect(results().single.reason, 'enqueue_failed');
      expect(marker(), isNotEmpty);
      final String transactionId = (jsonDecode(marker()) as Map<String, dynamic>)['txId'] as String;
      await ageMarker();

      final List<Map<String, dynamic>> refunds = await restart();
      await settle(tester);

      expect(refunds.single['action'], 'refund');
      expect(refunds.single['transactionId'], transactionId);
      expect(marker(), isEmpty);
    });

    testWidgets('a paid save of tint A that finished but left its marker is not refunded', (tester) async {
      await CoinsService.instance.spend(
        CoinSpendAction.wallpaperDownload,
        pendingDownloadLink: tintA.identityOf(_link),
      );
      await index.remember(link: tintA.identityOf(_link), id: 'wall-1', source: WallpaperSource.prism);
      await ageMarker();

      final List<Map<String, dynamic>> refunds = await restart();
      await settle(tester);

      expect(refunds, isEmpty);
      expect(marker(), isEmpty);
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
