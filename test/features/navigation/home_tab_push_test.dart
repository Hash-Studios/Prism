// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/network/connectivity_service.dart';
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
import 'package:Prism/features/navigation/views/pages/home_tab_page.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

class _AdsBloc extends MockBloc<AdsEvent, AdsState> implements AdsBloc {}

class _NotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

class _FavouritesBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _WotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

class _FeedBloc extends MockBloc<PersonalizedFeedEvent, PersonalizedFeedState> implements PersonalizedFeedBloc {}

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
    app_state.prismUser = profileUser(profilePhoto: '');
    token = 'initial-token';
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
    ads = _AdsBloc();
    notifications = _NotificationsBloc();
    final feed = _FeedBloc();
    when(() => ads.state).thenReturn(AdsState.initial());
    when(() => notifications.state).thenReturn(InAppNotificationsState.initial());
    when(() => feed.state).thenReturn(PersonalizedFeedState.initial().copyWith(status: LoadStatus.failure));
    when(feed.close).thenAnswer((_) async {});
    getIt
      ..registerSingleton<FirestoreClient>(client)
      ..registerSingleton<FavouritesSyncService>(sync)
      ..registerSingleton<SettingsLocalDataSource>(settings)
      ..registerSingleton<ConnectivityService>(_Connectivity())
      ..registerSingleton<PersonalizedFeedBloc>(feed);
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
    await FcmTokenService.instance.cancelAndWait();
    app_state.prismUser = createGuestPrismUser();
    messenger.setMockMethodCallHandler(_quickActions, null);
    messenger.setMockMethodCallHandler(_messaging, null);
    await getIt.reset();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AdsBloc>.value(value: ads),
            BlocProvider<InAppNotificationsBloc>.value(value: notifications),
            BlocProvider<FavouriteWallsBloc>.value(value: favourites),
            BlocProvider<WotdBloc>.value(value: wotd),
          ],
          child: const HomeTabPage(),
        ),
      ),
    );
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
    expect(client.writes.single.data, <String, dynamic>{'fcmToken': 'initial-token'});
    expect(subscribed, containsAll(<String>['u_u1', 'user']));
    subscribed.clear();

    await refresh(tester);

    expect(client.writes.last.data, <String, dynamic>{'fcmToken': 'refreshed-token'});
    expect(subscribed, containsAll(<String>['u_u1', 'user']));
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
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android}));

  test('the For You and Collections shortcuts map to their tabs, others to none', () {
    expect(quickActionTabIndex('Personalized_Feed'), 0);
    expect(quickActionTabIndex('Collections'), 3);
    expect(quickActionTabIndex('Downloads'), isNull);
    expect(quickActionTabIndex('nope'), isNull);
  });

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
    app_state.prismUser = createGuestPrismUser();

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

  test('the Wall of the Day shortcut falls back to the full url and never to an unknown source', () {
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
    expect(args.thumbnailUrl, 'https://example.com/full.jpg');
  });

  test('the Wall of the Day shortcut opens no tab', () {
    expect(quickActionTabIndex('Wall_of_the_Day'), isNull);
  });
}
