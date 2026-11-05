import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_firestore_client.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

class _DelayedPrefsStore extends InMemorySharedPreferencesStore {
  _DelayedPrefsStore(super.data) : super.withData();

  final Completer<void> started = Completer<void>();
  final Completer<void> gate = Completer<void>();

  @override
  Future<Map<String, Object>> getAll() async {
    started.complete();
    await gate.future;
    return super.getAll();
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUser);

  @override
  User? currentUser;

  @override
  Future<void> signOut() async => currentUser = null;
}

class _User extends Fake implements User {
  @override
  String get uid => 'account-a';

  @override
  String? get email => 'a@example.com';
}

class _GoogleSignIn extends Fake implements GoogleSignIn {
  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}

  @override
  Future<void> signOut() async {}
}

class _Messaging extends Fake implements FirebaseMessaging {
  @override
  Future<String?> getAPNSToken() async => 'apns';

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}

  @override
  Future<void> deleteToken() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _DelayedPrefsStore preferencesStore;

  setUp(() async {
    await getIt.reset();
    preferencesStore = _DelayedPrefsStore(<String, Object>{'flutter.shortcuts.day_night': 'account-a snapshot'});
    SharedPreferencesStorePlatform.instance = preferencesStore;
    SharedPreferences.resetStatic();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    app_state.prismUser = profileUser(id: 'account-a');
    AnalyticsRuntime.instance = FakeAppAnalytics();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt
      ..registerSingleton<FirestoreClient>(FakeFirestoreClient())
      ..registerSingleton<TasteSignalStore>(TasteSignalStore(settings))
      ..registerSingleton<FeedImpressionStore>(FeedImpressionStore(settings))
      ..registerSingleton<WallpaperHistoryStore>(WallpaperHistoryStore(settings))
      ..registerSingleton<RecentlyViewedStore>(RecentlyViewedStore(settings))
      ..registerSingleton<SyncedHistoryStore>(
        SyncedHistoryStore(settings, FakeFirestoreClient(), ownerId: () => 'account-a'),
      );
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    AnalyticsRuntime.reset();
    SharedPreferences.resetStatic();
    await getIt.reset();
  });

  test('a replacement sign-in during preferences load keeps its day/night snapshot', () async {
    final GoogleAuth auth = GoogleAuth(
      auth: _Auth(_User()),
      googleSignIn: _GoogleSignIn(),
      messaging: _Messaging(),
      clearShortcutsFavourites: () async {},
      clearShortcutsFolders: () async {},
    );

    final Future<bool> signOut = auth.signOutGoogle();
    await preferencesStore.started.future;
    app_state.prismUser = profileUser(id: 'account-b');
    await preferencesStore.setValue('String', 'flutter.shortcuts.day_night', 'account-b snapshot');
    final SignInSession replacementOperation = SignInSession();
    preferencesStore.gate.complete();

    expect(await signOut, isFalse);
    expect(replacementOperation.isCurrent, isTrue);
    expect((await SharedPreferences.getInstance()).getString('shortcuts.day_night'), 'account-b snapshot');
  });
}
