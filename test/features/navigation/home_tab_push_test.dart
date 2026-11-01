import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/data/favourites_sync_service.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/moods/biz/moods_cubit.dart';
import 'package:Prism/features/navigation/views/pages/home_tab_page.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/theme_mode/seasonal_themes.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/weekly_challenges/biz/weekly_challenges_cubit.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidFlutterLocalNotificationsPlugin;
import 'package:flutter_test/flutter_test.dart';

import 'package:mocktail/mocktail.dart';

import '../../support/empty_mood_repository.dart';
import '../../support/empty_weekly_challenges_repository.dart';
import '../../support/fake_firestore_client.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

class _CacheManager extends Mock implements BaseCacheManager {}

class _AdsBloc extends MockBloc<AdsEvent, AdsState> implements AdsBloc {}

class _NotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

class _FavouritesBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _WotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

class _FeedBloc extends MockBloc<PersonalizedFeedEvent, PersonalizedFeedState> implements PersonalizedFeedBloc {}

class _TrendingBloc extends MockBloc<TrendingEvent, TrendingState> implements TrendingBloc {}

class _MemoryDurableStore extends DurableJsonStore {
  _MemoryDurableStore() : super('home_spooky_announcement', directory: Directory.systemTemp);

  final Map<String, Map<String, Object?>> _records = <String, Map<String, Object?>>{};

  @override
  Future<Map<String, Object?>?> read(String key) async => _records[key];

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    _records[key] = Map<String, Object?>.from(value);
  }

  @override
  Future<void> delete(String key) async {
    _records.remove(key);
  }
}

class _Connectivity extends Fake implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

class _Sync extends Fake implements FavouritesSyncService {
  final List<String> started = <String>[];
  final StreamController<FavouritesSyncUpdate> updates = StreamController<FavouritesSyncUpdate>.broadcast();

  @override
  StreamSubscription<FavouritesSyncUpdate> listen(void Function(FavouritesSyncUpdate update) onUpdate) =>
      updates.stream.listen(onUpdate);

  @override
  Future<void> start(String userId) async => started.add(userId);
}

const _messaging = MethodChannel('plugins.flutter.io/firebase_messaging');
const _quickActions = MethodChannel('plugins.flutter.io/quick_actions');
const _ios = TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FakeFirestoreClient client;
  late _Sync sync;
  late _FavouritesBloc favourites;
  late _WotdBloc wotd;
  late _AdsBloc ads;
  late _NotificationsBloc notifications;
  late String token;
  late NotificationsLocalDataSource localInbox;
  final subscribed = <String>[];
  final unsubscribed = <String>[];
  final quickActionCalls = <MethodCall>[];

  setUpAll(() async {
    registerFallbackValue(const FavouriteWallsEvent.refreshRequested());
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseInit.setFuture(Future<bool>.value(true));
    // The banner image opens the image cache, which asks for a temp directory.
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });

  setUp(() async {
    await getIt.reset();
    // The banner image would open the real disk cache, which needs a database that tests do not have.
    final cache = _CacheManager();
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((_) => Stream<FileResponse>.error(const SocketException('offline')));
    PrismImageCache.testOverride = cache;
    app_state.prismUser = profileUser(profilePhoto: '');
    token = 'initial-token';
    localInbox = NotificationsLocalDataSource.withStore(_MemoryDurableStore())..setOwner('u1');
    subscribed.clear();
    unsubscribed.clear();
    quickActionCalls.clear();
    client = FakeFirestoreClient();
    final store = InMemoryLocalStore();
    sync = _Sync();
    favourites = _FavouritesBloc();
    wotd = _WotdBloc();
    when(() => wotd.state).thenReturn(WotdState.initial());
    when(() => favourites.state).thenReturn(FavouriteWallsState.initial());
    final settings = SettingsLocalDataSource(store);
    await settings.set('lastSeenVersion', currentAppVersion);
    await settings.set('lastSeenBuildVersion', currentAppVersionCode);
    ads = _AdsBloc();
    notifications = _NotificationsBloc();
    final feed = _FeedBloc();
    when(() => ads.state).thenReturn(AdsState.initial());
    when(() => notifications.state).thenReturn(InAppNotificationsState.initial());
    when(() => feed.state).thenReturn(PersonalizedFeedState.initial().copyWith(status: LoadStatus.failure));
    when(feed.close).thenAnswer((_) async {});
    final trending = _TrendingBloc();
    when(() => trending.state).thenReturn(TrendingState.initial());
    when(trending.close).thenAnswer((_) async {});
    getIt.registerFactory<WeeklyChallengesCubit>(() => WeeklyChallengesCubit(const EmptyWeeklyChallengesRepository()));
    getIt
      ..registerSingleton<FirestoreClient>(client)
      ..registerSingleton<FavouritesSyncService>(sync)
      ..registerSingleton<SettingsLocalDataSource>(settings)
      ..registerSingleton<NotificationsLocalDataSource>(localInbox)
      ..registerSingleton<ConnectivityService>(_Connectivity())
      ..registerSingleton<PersonalizedFeedBloc>(feed)
      ..registerSingleton<TrendingBloc>(trending)
      ..registerSingleton<MoodsCubit>(MoodsCubit(const EmptyMoodRepository()));
    messenger.setMockMethodCallHandler(_quickActions, (call) async {
      quickActionCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(_messaging, (call) async {
      if (call.method == 'Messaging#getToken') return <String, String>{'token': token};
      if (call.method == 'Messaging#getAPNSToken') return <String, String>{'token': 'apns'};
      if (call.method == 'Messaging#subscribeToTopic') subscribed.add((call.arguments as Map)['topic'] as String);
      if (call.method == 'Messaging#unsubscribeFromTopic') unsubscribed.add((call.arguments as Map)['topic'] as String);
      return <String, Object?>{};
    });
  });

  tearDown(() async {
    PrismImageCache.testOverride = null;
    await FcmTokenService.instance.cancelAndWait();
    app_state.prismUser = createGuestPrismUser();
    messenger.setMockMethodCallHandler(_quickActions, null);
    messenger.setMockMethodCallHandler(_messaging, null);
    messenger.setMockMethodCallHandler(const MethodChannel('dexterous.com/flutter/local_notifications'), null);
    seasonClock = DateTime.now;
    await getIt.reset();
  });

  Widget homeApp({Locale locale = const Locale('en'), Brightness brightness = Brightness.light}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    themeAnimationDuration: Duration.zero,
    theme: ThemeData(brightness: brightness),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AdsBloc>.value(value: ads),
        BlocProvider<InAppNotificationsBloc>.value(value: notifications),
        BlocProvider<FavouriteWallsBloc>.value(value: favourites),
        BlocProvider<WotdBloc>.value(value: wotd),
      ],
      child: const HomeTabPage(),
    ),
  );

  Future<void> mount(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(homeApp(locale: locale));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
  }

  Future<void> refresh(WidgetTester tester) async {
    token = 'refreshed-token';
    await messenger.handlePlatformMessage(
      _messaging.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('Messaging#onTokenRefresh', token)),
      (_) {},
    );
    await tester.pump();
  }

  testWidgets('a returning signed-in user stores the startup token and re-syncs on refresh', (tester) async {
    await mount(tester);
    expect(client.writes.single.data, <String, dynamic>{
      'fcmToken': 'initial-token',
      'notificationLocalizationVersion': 2,
      'notificationLocalizationToken': 'initial-token',
      'fcmTokenBindingVersion': 1,
      'fcmTokenBindingToken': 'initial-token',
      'postAlerts': true,
      'postAlertsToken': 'initial-token',
      'folderAlerts': true,
      'folderAlertsToken': 'initial-token',
    });
    expect(subscribed, contains('user_loc_v1'));
    expect(subscribed, isNot(contains('u_u1_loc_v1')));
    expect(unsubscribed, containsAll(<String>['u_u1', 'u_u1_loc_v1']));
    subscribed.clear();
    unsubscribed.clear();

    await refresh(tester);

    expect(client.writes.last.data, <String, dynamic>{
      'fcmToken': 'refreshed-token',
      'notificationLocalizationVersion': 2,
      'notificationLocalizationToken': 'refreshed-token',
      'fcmTokenBindingVersion': 1,
      'fcmTokenBindingToken': 'refreshed-token',
      'postAlerts': true,
      'postAlertsToken': 'refreshed-token',
      'folderAlerts': true,
      'folderAlertsToken': 'refreshed-token',
    });
    expect(subscribed, contains('user_loc_v1'));
    expect(subscribed, isNot(contains('u_u1_loc_v1')));
    expect(unsubscribed, containsAll(<String>['u_u1', 'u_u1_loc_v1']));
    await tester.pumpWidget(const SizedBox());
  }, variant: _ios);

  testWidgets('disposing Home cancels its topic-refresh subscription', (tester) async {
    await mount(tester);
    await tester.pumpWidget(const SizedBox());
    subscribed.clear();

    await refresh(tester);

    expect(subscribed, isEmpty);
  }, variant: _ios);

  testWidgets('iOS shortcuts carry no Android drawable names', (tester) async {
    await mount(tester);

    final items = quickActionCalls.singleWhere((c) => c.method == 'setShortcutItems').arguments! as List<Object?>;
    expect(items.map((i) => (i! as Map)['type']), <String>[
      'Personalized_Feed',
      'Collections',
      'Downloads',
      'Wall_of_the_Day',
    ]);
    expect(items.map((i) => (i! as Map)['icon']), everyElement(isNull));
    await tester.pumpWidget(const SizedBox());
  }, variant: _ios);

  testWidgets('failed shortcut update retries at the same locale and dedupes after success', (tester) async {
    final Locale nonEnglishLocale = AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode != 'en',
    );
    final AppLocalizations nonEnglish = await loadAppLocalizations(nonEnglishLocale);
    var fail = true;
    messenger.setMockMethodCallHandler(_quickActions, (call) async {
      quickActionCalls.add(call);
      if (call.method == 'setShortcutItems' && fail) {
        fail = false;
        throw PlatformException(code: 'unavailable');
      }
      return null;
    });

    await mount(tester, locale: nonEnglishLocale);
    expect(quickActionCalls.where((call) => call.method == 'setShortcutItems'), hasLength(1));

    await tester.pumpWidget(homeApp(locale: nonEnglishLocale, brightness: Brightness.dark));
    await tester.pump();

    final updates = quickActionCalls.where((call) => call.method == 'setShortcutItems').toList();
    expect(updates, hasLength(2));
    expect((updates.last.arguments! as List<Object?>).map((item) => (item! as Map)['localizedTitle']), <String>[
      nonEnglish.wallpaperFeedTabForYou,
      nonEnglish.wallpaperNavCollections,
      nonEnglish.wallpaperDownloadsTitle,
      nonEnglish.wallpaperShortcutsSourceWotd,
    ]);

    await tester.pumpWidget(homeApp(locale: nonEnglishLocale));
    await tester.pump();
    expect(quickActionCalls.where((call) => call.method == 'setShortcutItems'), hasLength(2));
    await tester.pumpWidget(const SizedBox());
  }, variant: _ios);

  testWidgets('disposing while a shortcut update is pending is safe', (tester) async {
    final update = Completer<void>();
    messenger.setMockMethodCallHandler(_quickActions, (call) async {
      quickActionCalls.add(call);
      if (call.method == 'setShortcutItems') await update.future;
      return null;
    });

    await mount(tester);
    expect(quickActionCalls.where((call) => call.method == 'setShortcutItems'), hasLength(1));

    await tester.pumpWidget(const SizedBox());
    update.complete();
    await tester.pump();
    await tester.pump();

    expect(quickActionCalls.where((call) => call.method == 'setShortcutItems'), hasLength(1));
  }, variant: _ios);

  testWidgets('locale changes reconcile the installed shortcuts after a delayed update', (tester) async {
    final Locale nonEnglishLocale = AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode != 'en',
    );
    final AppLocalizations nonEnglish = await loadAppLocalizations(nonEnglishLocale);
    final nonEnglishUpdate = Completer<void>();
    final nonEnglishUpdateStarted = Completer<void>();
    List<String>? installedTitles;
    messenger.setMockMethodCallHandler(_quickActions, (call) async {
      quickActionCalls.add(call);
      if (call.method == 'setShortcutItems') {
        final titles = (call.arguments! as List<Object?>)
            .map((item) => (item! as Map)['localizedTitle'] as String)
            .toList();
        if (titles.first == nonEnglish.wallpaperFeedTabForYou) {
          if (!nonEnglishUpdateStarted.isCompleted) nonEnglishUpdateStarted.complete();
          await nonEnglishUpdate.future;
        }
        installedTitles = titles;
      }
      return null;
    });

    await mount(tester);
    await tester.pumpWidget(homeApp(locale: nonEnglishLocale));
    await tester.pump();
    await nonEnglishUpdateStarted.future;
    await tester.pumpWidget(homeApp());
    await tester.pump();
    nonEnglishUpdate.complete();
    await tester.pump();
    await tester.pump();

    final updates = quickActionCalls.where((call) => call.method == 'setShortcutItems').toList();
    expect(updates, hasLength(3));
    expect(installedTitles, <String>['For you', 'Collections', 'Downloads', 'Wall of the Day']);
    await tester.pumpWidget(const SizedBox());
  }, variant: _ios);

  testWidgets('Android shortcuts keep their drawables', (tester) async {
    await mount(tester);

    final items = quickActionCalls.singleWhere((c) => c.method == 'setShortcutItems').arguments! as List<Object?>;
    expect(items.map((i) => (i! as Map)['icon']), <String>[
      '@drawable/ic_feed',
      '@drawable/ic_collections',
      '@drawable/ic_downloads',
      '@drawable/ic_tile_wotd',
    ]);
    await tester.pumpWidget(const SizedBox());
    // On a macOS host Platform.isMacOS is true, so topic calls wait for an APNs token with retry timers.
    await tester.pump(const Duration(seconds: 3));
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android}));

  test('the For You and Collections shortcuts map to their tabs, others to none', () {
    expect(quickActionTabIndex('Personalized_Feed'), 0);
    expect(quickActionTabIndex('Collections'), 3);
    expect(quickActionTabIndex('Downloads'), isNull);
    expect(quickActionTabIndex('nope'), isNull);
  });

  testWidgets('an app update announces Diwali through the owned inbox and local notification', (tester) async {
    const MethodChannel localNotifications = MethodChannel('dexterous.com/flutter/local_notifications');
    final List<MethodCall> notificationCalls = <MethodCall>[];
    final Completer<void> shown = Completer<void>();
    messenger.setMockMethodCallHandler(localNotifications, (call) async {
      notificationCalls.add(call);
      if (call.method == 'show' && !shown.isCompleted) shown.complete();
      return null;
    });
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    seasonClock = () => DateTime(2026, 10, 25, 12);
    await getIt<SettingsLocalDataSource>().set('lastSeenVersion', 'previous-version');

    await mount(tester);
    await tester.runAsync(() => shown.future.timeout(const Duration(seconds: 5)));

    final List<InAppNotificationEntity> items = (await tester.runAsync(localInbox.readAll))!;
    expect(localInbox.ownerId, 'u1');
    expect(items.map((item) => item.id), <String>[diwaliSeason.announcementId]);
    expect(items.single.createdAt, DateTime(2026, 10, 25, 12).toUtc());
    final MethodCall show = notificationCalls.singleWhere((call) => call.method == 'show');
    final Map<Object?, Object?> arguments = show.arguments as Map<Object?, Object?>;
    expect(jsonDecode(arguments['payload']! as String), <String, String>{'route': '/theme'});
    final Map<Object?, Object?> platformSpecifics = arguments['platformSpecifics']! as Map<Object?, Object?>;
    expect(platformSpecifics['channelId'], 'recommendations');

    await tester.pumpWidget(const SizedBox());
    await mount(tester);

    expect(notificationCalls.where((call) => call.method == 'show'), hasLength(1));
    expect(await tester.runAsync(localInbox.readAll), hasLength(1));
    await tester.pump(const Duration(seconds: 3));
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android}));

  testWidgets('a signed-in user starts the favourites sync and a sync update reaches the favourites bloc', (
    tester,
  ) async {
    await mount(tester);

    expect(sync.started, <String>['u1']);

    sync.updates.add(const FavouritesSyncUpdate(userId: 'u1', items: []));
    await tester.pump();

    final FavouriteWallsEvent event = verify(() => favourites.add(captureAny())).captured.single as FavouriteWallsEvent;
    expect(event, const FavouriteWallsEvent.synced(userId: 'u1', items: []));
    await tester.pumpWidget(const SizedBox());
  }, variant: _ios);

  testWidgets('a guest does not start the favourites sync', (tester) async {
    app_state.prismUser = profileUser(loggedIn: false, profilePhoto: '');

    await mount(tester);

    expect(sync.started, isEmpty);
    await tester.pumpWidget(const SizedBox());
  }, variant: _ios);

  test('the Wall of the Day shortcut opens that wall, with the thumbnail as the placeholder', () {
    final WallpaperDetailRoute route = wallOfTheDayRoute(
      const WallOfTheDayEntity(
        wallId: 'w1',
        url: 'https://example.com/full.jpg',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        photographer: 'Ana',
      ),
    );

    final WallpaperDetailRouteArgs args = route.args!;
    expect(args.wallId, 'w1');
    expect(args.source, WallpaperSource.prism);
    expect(args.thumbnailUrl, 'https://example.com/thumb.jpg');
  });

  test('the Wall of the Day shortcut never puts a Prism original in the route, and never an unknown source', () {
    final WallpaperDetailRoute route = wallOfTheDayRoute(
      const WallOfTheDayEntity(
        wallId: 'w2',
        url: 'https://example.com/full.jpg',
        thumbnailUrl: '',
        photographer: '',
        source: WallpaperSource.unknown,
      ),
    );

    final WallpaperDetailRouteArgs args = route.args!;
    expect(args.source, WallpaperSource.prism);
    expect(args.thumbnailUrl, isEmpty);
  });

  test('the Wall of the Day shortcut falls back to a public Wallhaven original', () {
    final WallpaperDetailRoute route = wallOfTheDayRoute(
      const WallOfTheDayEntity(
        wallId: 'w3',
        url: 'https://w.wallhaven.cc/full/ab/wallhaven-ab.jpg',
        thumbnailUrl: '',
        photographer: '',
        source: WallpaperSource.wallhaven,
      ),
    );

    expect(route.args!.thumbnailUrl, 'https://w.wallhaven.cc/full/ab/wallhaven-ab.jpg');
  });

  test('the Wall of the Day shortcut opens no tab', () {
    expect(quickActionTabIndex('Wall_of_the_Day'), isNull);
  });
}
