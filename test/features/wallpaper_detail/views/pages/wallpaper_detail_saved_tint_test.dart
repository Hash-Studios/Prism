import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/downloaded_link_lookup.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/coins_test_backend.dart';
import '../../../../support/fake_app_analytics.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';
import '../../../../support/wait_for_real_io.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

class _Stats extends Fake implements ViewStatsRepository {
  @override
  Future<Result<void>> recordWallpaperAction(String wallId, WallpaperAction action) async => Result.success(null);
}

const String _fullUrl = 'https://images.example/full.jpg';

FeedItemEntity _wallpaper() => const FeedItemEntity.pexels(
  id: 'pexels-1',
  wallpaper: PexelsWallpaper(
    core: WallpaperCore(
      id: 'pexels-1',
      source: WallpaperSource.pexels,
      fullUrl: _fullUrl,
      thumbnailUrl: 'https://images.example/thumb.jpg',
    ),
  ),
);

const _prismWallpaper = FeedItemEntity.prism(
  id: 'prism-1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: 'prism-1', source: WallpaperSource.prism, fullUrl: _fullUrl, thumbnailUrl: ''),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(WallpaperFilterRoute(filePath: 'unused')));

  final backend = CoinsTestBackend();
  const enqueueChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
    PrismMediaHostApi.pigeonChannelCodec,
  );
  const listChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
    PrismMediaHostApi.pigeonChannelCodec,
  );
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  late Directory directory;
  late OfflineAssetFixture offlineAssets;
  late List<String> spent;
  late List<DownloadRequest> enqueued;
  late List<String> downloadsOnDisk;
  late _MockStackRouter router;
  late bool filterRoutePushed;

  setUp(() async {
    IosWallpaperGuideSession.shown = false;
    await backend.install();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    directory = offlineAssets.directory;
    spent = <String>[];
    enqueued = <DownloadRequest>[];
    downloadsOnDisk = <String>[];
    router = _MockStackRouter();
    filterRoutePushed = false;
    when(() => router.push(any())).thenAnswer((_) async {
      filterRoutePushed = true;
      return null;
    });
    backend.onCall = (name, parameters) async {
      spent.add(name);
      return <String, Object>{
        'success': true,
        'changed': true,
        'previousBalance': 100,
        'currentBalance': 95,
        'delta': -5,
        'transactionId': 'spend_tx',
      };
    };
    messenger.setMockDecodedMessageHandler<Object?>(enqueueChannel, (message) async {
      enqueued.add((message! as List<Object?>).single! as DownloadRequest);
      return <Object?>[OperationResult(success: true)];
    });
    messenger.setMockDecodedMessageHandler<Object?>(
      listChannel,
      (_) async => <Object?>[DownloadItemsResult(success: true, items: downloadsOnDisk)],
    );
    messenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    CoinsService.instance.isLinkDownloaded = isLinkInDownloadedIndex;
    final charged = backend.onCall;
    backend.onCall = (name, parameters) async => <String, Object>{
      'success': true,
      'changed': false,
      'bypassed': true,
      'currentBalance': 100,
      'graceDownloadsLeft': 0,
      'reason': 'grace_download',
    };
    await CoinsService.instance.spend(CoinSpendAction.wallpaperDownload);
    backend.onCall = charged;
    final settings = getIt<SettingsLocalDataSource>();
    await settings.set('notificationPermissionPromptedV2', true);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    getIt.registerSingleton<DownloadedWallIndex>(DownloadedWallIndex(settings));
    getIt.registerSingleton<RecordWallpaperActionUseCase>(RecordWallpaperActionUseCase(_Stats()));
  });

  tearDown(() async {
    IosWallpaperGuideSession.shown = false;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(enqueueChannel, null);
    messenger.setMockDecodedMessageHandler<Object?>(listChannel, null);
    messenger.setMockMethodCallHandler(toastChannel, null);
    AnalyticsRuntime.reset();
    await getIt<SettingsLocalDataSource>().delete('pendingDownloads_v2');
    await getIt<SettingsLocalDataSource>().delete('notificationPermissionPromptedV2');
    await getIt.reset();
    await offlineAssets.dispose();
  });

  File downloadedFile(String name) => File('assets/images/prism.webp').copySync('${directory.path}/$name');

  Future<void> pumpReopened(WidgetTester tester, File file, {WallpaperDetailLoaded? state}) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: state ?? WallpaperDetailLoaded(entity: _wallpaper(), paletteLoading: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(wallId: 'pexels-1', source: WallpaperSource.pexels, localFile: file),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> rememberSavedTint(String identity) => getIt<DownloadedWallIndex>().remember(
    link: identity,
    id: 'pexels-1',
    source: WallpaperSource.pexels,
    original: false,
  );

  group('a tinted file reopened from Downloads', () {
    testWidgets('a Prism derivative stays Saved without authorizing its original', (tester) async {
      final file = downloadedFile('full_tint-ff8800.png');
      downloadsOnDisk = <String>[file.path];
      final index = getIt<DownloadedWallIndex>();
      await index.remember(link: 'full_tint-ff8800.png', id: 'prism-1', source: WallpaperSource.prism, original: false);
      await pumpReopened(
        tester,
        file,
        state: const WallpaperDetailLoaded(entity: _prismWallpaper, paletteLoading: false),
      );
      expect(find.text('Saved'), findsOneWidget);
      final download = tester.widget<DownloadButton>(find.byType(DownloadButton));
      expect(download.wallpaperSource, WallpaperSource.downloaded);
      expect(download.indexSource, WallpaperSource.prism);
      expect(download.savedIdentity, 'full_tint-ff8800.png');
      expect(
        index.acquiredIdentityForLocalFile(filePath: file.path, id: 'other-wall', source: WallpaperSource.prism),
        isNull,
      );
      expect(
        index.acquiredIdentityForLocalFile(filePath: file.path, id: 'prism-1', source: WallpaperSource.pexels),
        isNull,
      );
      final otherOwnerIndex = DownloadedWallIndex(getIt<SettingsLocalDataSource>(), ownerId: () => 'other-owner');
      expect(
        otherOwnerIndex.acquiredIdentityForLocalFile(filePath: file.path, id: 'prism-1', source: WallpaperSource.prism),
        isNull,
      );
      await tester.tap(find.byTooltip('Edit'));
      await waitForRealIo(tester, () => filterRoutePushed, reason: 'the acquired Prism derivative stays editable');
      verify(() => router.push(WallpaperFilterRoute(filePath: file.path))).called(1);
      expect(spent, isEmpty);
      expect(
        await tester.runAsync(() => index.localFileForIdentity(id: 'prism-1', source: WallpaperSource.prism)),
        isNull,
      );
      await tester.runAsync(() async {
        await expectLater(
          OriginalAccessService.instance.resolve(
            url: _fullUrl,
            wallpaperId: 'prism-1',
            wallpaperSource: WallpaperSource.prism,
            action: OriginalAccessAction.download,
          ),
          throwsStateError,
        );
      });
      expect(spent, <String>['resolveOriginalAccess']);
      expect(enqueued, isEmpty);
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('resaving a derivative without a tint filename never promotes it to an original', (tester) async {
      final file = downloadedFile('edited.png');
      downloadsOnDisk = <String>[file.path];
      final index = getIt<DownloadedWallIndex>();
      await index.remember(link: file.path, id: 'prism-1', source: WallpaperSource.prism, original: false);
      await pumpReopened(
        tester,
        file,
        state: const WallpaperDetailLoaded(entity: _prismWallpaper, paletteLoading: false),
      );
      expect(find.text('Saved'), findsOneWidget);
      await tester.tap(find.byType(PrimaryActionPill));
      await waitForRealIo(
        tester,
        () => find.text('Already in Downloads').evaluate().isNotEmpty,
        reason: 'the acquired derivative confirmation to appear',
      );
      final again = find.text('Download again (-${CoinPolicy.wallpaperDownload} coins)');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(again);
      await tester.tap(again);
      await waitForRealIo(tester, () => enqueued.isNotEmpty, reason: 'the derivative to save from its local file');
      expect(enqueued.single.link, file.path);
      expect(enqueued.single.isLocalFile, isTrue);
      await waitForRealIo(
        tester,
        () => find.text('Set it as your wallpaper').evaluate().isNotEmpty,
        reason: 'the successful save bookkeeping to reach the guide',
      );
      expect(index.hasAcquired(link: file.path, id: 'prism-1', source: WallpaperSource.prism), isTrue);
      expect(
        await tester.runAsync(() => index.localFileForIdentity(id: 'prism-1', source: WallpaperSource.prism)),
        isNull,
      );
      expect(spent, <String>['spendCoins']);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await waitForRealIo(
        tester,
        () => !tester.widget<PrimaryActionPill>(find.byType(PrimaryActionPill)).isLoading,
        reason: 'the local resave flow to finish',
      );
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    for (final String name in <String>['full_tint-ff8800.png', 'full_tint-ff8800 (2).png']) {
      testWidgets('the Save pill reads Saved for $name', (tester) async {
        await rememberSavedTint('full_tint-ff8800.png');
        await pumpReopened(tester, downloadedFile(name));

        expect(find.text('Saved'), findsOneWidget);
        expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).variant!.key, 'tint-ff8800');
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }

    testWidgets('Save asks first and charges nothing, and Download again saves the tinted file, not the original', (
      tester,
    ) async {
      final File file = downloadedFile('full_tint-ff8800.png');
      downloadsOnDisk = <String>[file.path];
      await rememberSavedTint('full_tint-ff8800.png');
      await pumpReopened(tester, file);

      await tester.tap(find.byType(PrimaryActionPill));
      await waitForRealIo(
        tester,
        () => find.text('Already in Downloads').evaluate().isNotEmpty,
        reason: 'the already-downloaded confirmation to appear',
      );

      expect(find.text('Already in Downloads'), findsOneWidget);
      expect(spent, isEmpty);
      expect(enqueued, isEmpty);

      final Finder downloadAgain = find.text('Download again (-${CoinPolicy.wallpaperDownload} coins)');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(downloadAgain);
      await tester.tap(downloadAgain);
      await waitForRealIo(
        tester,
        () => spent.contains('spendCoins') && enqueued.isNotEmpty,
        reason: 'the confirmed download to charge and enqueue the tinted file',
      );

      expect(spent, <String>['spendCoins']);
      expect(enqueued, hasLength(1));
      expect(enqueued.single.link, file.path);
      expect(enqueued.single.isLocalFile, isTrue);
      expect(enqueued.single.filenameWithoutExtension, 'full_tint-ff8800');
      await waitForRealIo(
        tester,
        () => find.text('Set it as your wallpaper').evaluate().isNotEmpty,
        reason: 'the iOS wallpaper guide after saving',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await waitForRealIo(
        tester,
        () => !tester.widget<PrimaryActionPill>(find.byType(PrimaryActionPill)).isLoading,
        reason: 'the download action to finish its bookkeeping',
      );
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Edit opens the tinted file itself', (tester) async {
      final File file = downloadedFile('full_tint-ff8800.png');
      await pumpReopened(tester, file);

      await tester.tap(find.byTooltip('Edit'));
      await waitForRealIo(tester, () => filterRoutePushed, reason: 'the saved tinted file edit route to open');

      verify(() => router.push(WallpaperFilterRoute(filePath: file.path))).called(1);
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a colour picked on top is its own variation, not the saved one', (tester) async {
      await rememberSavedTint('full_tint-ff8800.png');
      await pumpReopened(
        tester,
        downloadedFile('full_tint-ff8800.png'),
        state: WallpaperDetailLoaded(
          entity: _wallpaper(),
          paletteLoading: false,
          colors: const <Color>[Color(0xFF00FF00)],
          accent: const Color(0xFF00FF00),
          colorChanged: true,
        ),
      );

      expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).variant!.key, 'tint-00ff00');
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Save · ${CoinPolicy.wallpaperDownload}'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('an untinted file reopened from Downloads', () {
    testWidgets('the original remote acquisition remains Saved when reopened as a local path', (tester) async {
      await getIt<DownloadedWallIndex>().remember(link: _fullUrl, id: 'pexels-1', source: WallpaperSource.pexels);
      final file = downloadedFile('full.jpg');
      await pumpReopened(tester, file);
      final download = tester.widget<DownloadButton>(find.byType(DownloadButton));
      expect(download.link, file.path);
      expect(download.savedIdentity, _fullUrl);
      expect(download.indexSource, WallpaperSource.pexels);
      expect(find.text('Saved'), findsOneWidget);
      downloadsOnDisk = <String>[file.path];
      await tester.tap(find.byType(PrimaryActionPill));
      await waitForRealIo(
        tester,
        () => find.text('Already in Downloads').evaluate().isNotEmpty,
        reason: 'the indexed original local resave confirmation',
      );
      final again = find.text('Download again (-${CoinPolicy.wallpaperDownload} coins)');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(again);
      await tester.tap(again);
      await waitForRealIo(
        tester,
        () => find.text('Set it as your wallpaper').evaluate().isNotEmpty,
        reason: 'the original local resave bookkeeping to finish',
      );
      final original = await tester.runAsync(
        () => getIt<DownloadedWallIndex>().localFileForIdentity(id: 'pexels-1', source: WallpaperSource.pexels),
      );
      expect(original?.path, file.path, reason: 'resaving an existing original cannot downgrade its exact acquisition');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await waitForRealIo(
        tester,
        () => !tester.widget<PrimaryActionPill>(find.byType(PrimaryActionPill)).isLoading,
        reason: 'the original local resave flow to close',
      );
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Set and Download use the file as before, and Edit opens it', (tester) async {
      final File file = downloadedFile('full.jpg');
      await pumpReopened(tester, file);

      expect(tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton)).url, file.path);
      expect(tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton)).prepareSource, isNull);
      expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).variant, isNull);
      expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).indexSource, WallpaperSource.downloaded);
      expect(tester.widget<EditButton>(find.byType(EditButton)).prepareSource, isNotNull);

      await tester.tap(find.byTooltip('Edit'));
      await waitForRealIo(tester, () => filterRoutePushed, reason: 'the untinted file edit route to open');

      verify(() => router.push(WallpaperFilterRoute(filePath: file.path))).called(1);
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
