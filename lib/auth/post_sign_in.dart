import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

enum SignInOutcome { signedIn, cancelled }

final Set<Future<void>> _signInBootstraps = <Future<void>>{};

Future<void> waitForSignInBootstraps() async {
  while (_signInBootstraps.isNotEmpty) {
    await Future.wait<void>(_signInBootstraps.toList(growable: false));
  }
}

/// Runs the steps every provider shares once Firebase has accepted the credential:
/// upsert the user document, publish the user to analytics, subscribe to topics,
/// sync the FCM token and start the coins and purchases bootstrap.
Future<void> completeSignIn({
  required User user,
  required String displayName,
  required String email,
  required String photoUrl,
  required String sourceTagPrefix,
  FirebaseMessaging? messaging,
}) async {
  final Map<String, dynamic>? existing = await firestoreClient.getById<Map<String, dynamic>>(
    FirebaseCollections.usersV2,
    user.uid,
    (data, _) => data,
    sourceTag: '$sourceTagPrefix.find_user_doc',
  );
  final String now = DateTime.now().toUtc().toIso8601String();
  if (existing != null) {
    app_state.prismUser = PrismUsersV2.fromMapWithUser(existing, user);
    await firestoreClient.updateDoc(FirebaseCollections.usersV2, app_state.prismUser.id, {
      'id': user.uid,
      'lastLoginAt': now,
      'loggedIn': true,
    }, sourceTag: '$sourceTagPrefix.update_last_login');
  } else {
    app_state.prismUser = PrismUsersV2(
      name: displayName,
      bio: '',
      createdAt: now,
      email: email,
      username: sanitizeUsername(displayName),
      followers: [],
      following: [],
      id: user.uid,
      lastLoginAt: now,
      links: {},
      premium: false,
      loggedIn: true,
      profilePhoto: photoUrl,
      badges: [],
      coins: 0,
      subPrisms: [],
      transactions: [],
      coverPhoto: '',
    );
    await firestoreClient.setDoc(
      FirebaseCollections.usersV2,
      app_state.prismUser.id,
      app_state.prismUser.toJson(),
      sourceTag: '$sourceTagPrefix.create_user',
    );
  }

  await app_state.persistPrismUser();
  await analytics.setUserId(user.uid);
  await analytics.setUserProperty(
    name: AnalyticsUserProperty.subscriptionTier.wireName,
    value: app_state.prismUser.subscriptionTier,
  );
  await analytics.setUserProperty(
    name: AnalyticsUserProperty.isPremium.wireName,
    value: app_state.prismUser.premium ? '1' : '0',
  );
  final FirebaseMessaging resolvedMessaging = messaging ?? FirebaseMessaging.instance;
  final String? userTopic = userTopicFromId(user.uid);
  if (userTopic != null) {
    await subscribeToTopicSafely(resolvedMessaging, userTopic, sourceTag: '$sourceTagPrefix.user_topic');
  }
  final String? followersTopic = followersTopicFromEmail(email);
  if (followersTopic != null) {
    await subscribeToTopicSafely(resolvedMessaging, followersTopic, sourceTag: '$sourceTagPrefix.followers_topic');
  }
  unawaited(FcmTokenService.instance.syncToken(userId: app_state.prismUser.id, messaging: resolvedMessaging));
  FcmTokenService.instance.listenForTokenRefresh(userId: app_state.prismUser.id, messaging: resolvedMessaging);
  Future<void> runBootstrap() async {
    await PurchasesService.instance.checkAndPersistPremium();
    await CoinsService.instance.bootstrapForCurrentUser();
    await CoinsService.instance.refreshBalance();
    await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
    await CoinsService.instance.maybeAwardProDailyBonus();
    await CoinsService.instance.processPendingReferralIfEligible();
  }

  late final Future<void> bootstrap;
  bootstrap = runBootstrap()
      .catchError((Object error, StackTrace stackTrace) {
        logger.w('Sign-in bootstrap failed.', tag: 'Auth', error: error, stackTrace: stackTrace);
      })
      .whenComplete(() => _signInBootstraps.remove(bootstrap));
  _signInBootstraps.add(bootstrap);
  unawaited(bootstrap);
  await syncSentryUserScope(
    loggedIn: app_state.prismUser.loggedIn,
    id: app_state.prismUser.id,
    email: app_state.prismUser.email,
    username: app_state.prismUser.username,
  );
}
