// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/navigation/views/pages/home_tab_page.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
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

class _FeedBloc extends MockBloc<PersonalizedFeedEvent, PersonalizedFeedState> implements PersonalizedFeedBloc {}

class _Connectivity extends Fake implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;
}

const _messaging = MethodChannel('plugins.flutter.io/firebase_messaging');
const _quickActions = MethodChannel('plugins.flutter.io/quick_actions');
const _ios = TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FakeFirestoreClient client;
  late _AdsBloc ads;
  late _NotificationsBloc notifications;
  late String token;
  final subscribed = <String>[];
  final unsubscribed = <String>[];

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() async {
    await getIt.reset();
    app_state.prismUser = profileUser(profilePhoto: '');
    token = 'initial-token';
    subscribed.clear();
    unsubscribed.clear();
    client = FakeFirestoreClient();
    final store = InMemoryLocalStore();
    final favorites = FavoritesLocalDataSource(store);
    await favorites.setSeeded('u1', true);
    final settings = SettingsLocalDataSource(store);
    await settings.set('lastSeenVersion', currentAppVersion);
    ads = _AdsBloc();
    notifications = _NotificationsBloc();
    final feed = _FeedBloc();
    when(() => ads.state).thenReturn(AdsState.initial());
    when(() => notifications.state).thenReturn(InAppNotificationsState.initial());
    when(() => feed.state).thenReturn(PersonalizedFeedState.initial().copyWith(status: LoadStatus.failure));
    getIt
      ..registerSingleton<FirestoreClient>(client)
      ..registerSingleton<FavoritesLocalDataSource>(favorites)
      ..registerSingleton<SettingsLocalDataSource>(settings)
      ..registerSingleton<ConnectivityService>(_Connectivity())
      ..registerSingleton<PersonalizedFeedBloc>(feed);
    messenger.setMockMethodCallHandler(_quickActions, (_) async => null);
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
          ],
          child: const HomeTabPage(),
        ),
      ),
    );
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
}
