// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/data/favourites_sync_service.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/navigation/views/pages/home_tab_page.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:bloc_test/bloc_test.dart';
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
  @override
  StreamSubscription<FavouritesSyncUpdate> listen(void Function(FavouritesSyncUpdate update) onUpdate) =>
      const Stream<FavouritesSyncUpdate>.empty().listen(onUpdate);

  @override
  Future<void> start(String userId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const messaging = MethodChannel('plugins.flutter.io/firebase_messaging');
  final messagingCalls = <String>[];

  setUpAll(() => FirebaseInit.setFuture(Future<bool>.value(false)));

  setUp(() async {
    await getIt.reset();
    messagingCalls.clear();
    app_state.prismUser = profileUser(profilePhoto: '');
    final store = InMemoryLocalStore();
    final settings = SettingsLocalDataSource(store);
    await settings.set('lastSeenVersion', currentAppVersion);
    final feed = _FeedBloc();
    when(() => feed.state).thenReturn(PersonalizedFeedState.initial().copyWith(status: LoadStatus.failure));
    when(feed.close).thenAnswer((_) async {});
    getIt
      ..registerSingleton<FirestoreClient>(FakeFirestoreClient())
      ..registerSingleton<SettingsLocalDataSource>(settings)
      ..registerSingleton<ConnectivityService>(_Connectivity())
      ..registerSingleton<FavouritesSyncService>(_Sync())
      ..registerSingleton<PersonalizedFeedBloc>(feed);
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/quick_actions'), (_) async => null);
    messenger.setMockMethodCallHandler(messaging, (call) async {
      messagingCalls.add(call.method);
      return <String, Object?>{};
    });
  });

  tearDown(() async {
    app_state.prismUser = createGuestPrismUser();
    messenger.setMockMethodCallHandler(messaging, null);
    await getIt.reset();
  });

  testWidgets('Home does not touch Firebase Messaging when Firebase did not initialise', (tester) async {
    final ads = _AdsBloc();
    final notifications = _NotificationsBloc();
    when(() => ads.state).thenReturn(AdsState.initial());
    when(() => notifications.state).thenReturn(InAppNotificationsState.initial());
    final wotd = _WotdBloc();
    when(() => wotd.state).thenReturn(WotdState.initial());
    final favourites = _FavouritesBloc();
    when(() => favourites.state).thenReturn(FavouriteWallsState.initial());

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
    await tester.pump();

    expect(messagingCalls, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS}));
}
