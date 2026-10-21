import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/account/username_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/favourite_walls/data/favourites_sync_service.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

enum SignInOutcome { signedIn, cancelled }

/// Ownership of one provider operation, including its post-sign-in work and rollback.
/// A newer auth operation invalidates an older one even if it returns to the same account.
class SignInSession {
  SignInSession({String? Function()? authenticatedUid})
    : _authenticatedUid = authenticatedUid,
      _expectedUid = authenticatedUid?.call(),
      _generation = ++_latestGeneration;

  static int _latestGeneration = 0;
  final int _generation;
  final String? Function()? _authenticatedUid;
  String? _expectedUid;
  PrismUsersV2 _owner = app_state.prismUser;
  int _economySession = CoinsService.instance.economySession;

  bool get _ownsLocalSession =>
      _generation == _latestGeneration &&
      identical(app_state.prismUser, _owner) &&
      _economySession == CoinsService.instance.economySession;

  bool get isCurrent => _ownsLocalSession && (_authenticatedUid == null || _authenticatedUid() == _expectedUid);

  void requireCurrent() {
    if (!isCurrent) throw StateError('The sign-in session changed.');
  }

  /// Firebase itself changes the authenticated user while accepting our credential.
  void acceptCredential(User user) {
    if (!_ownsLocalSession || _authenticatedUid?.call() != user.uid) {
      throw StateError('The sign-in session changed.');
    }
    _expectedUid = user.uid;
  }

  void publish(PrismUsersV2 profile) {
    requireCurrent();
    app_state.prismUser = _owner = profile;
  }

  /// Only our own Firebase sign-out may rebind ownership to a guest session.
  bool finishSignOut({required bool firebaseSucceeded, required PrismUsersV2 guest}) {
    if (!_ownsLocalSession) return false;
    final String? expected = firebaseSucceeded ? null : _expectedUid;
    if (_authenticatedUid != null && _authenticatedUid() != expected) return false;
    _expectedUid = expected;
    publish(guest);
    CoinsService.instance.resetSession();
    _economySession = CoinsService.instance.economySession;
    return true;
  }
}

final Set<Future<void>> _signInBootstraps = <Future<void>>{};

Future<void> _startFavouritesSync(String userId) async {
  try {
    await getIt<FavouritesSyncService>().start(userId);
  } catch (error, stackTrace) {
    logger.w('Favourites sync did not start.', tag: 'Auth', error: error, stackTrace: stackTrace);
  }
}

Future<void> waitForSignInBootstraps() async {
  while (_signInBootstraps.isNotEmpty) {
    await Future.wait<void>(_signInBootstraps.toList(growable: false));
  }
}

/// Runs the steps every provider shares once Firebase has accepted the credential:
/// upsert the user document, publish the user to analytics, subscribe to topics,
/// sync the FCM token and start the coins and purchases bootstrap.
///
/// [syncProfile] gets a stored profile and returns the fields to copy into it from the provider.
Future<void> completeSignIn({
  required User user,
  required String displayName,
  required String email,
  required String photoUrl,
  required String sourceTagPrefix,
  Map<String, String> Function(PrismUsersV2 profile)? syncProfile,
  FirebaseMessaging? messaging,
  SignInSession? session,
}) async {
  final SignInSession operation = session ?? SignInSession();
  PrismUsersV2 owner = app_state.prismUser;
  operation.requireCurrent();

  final Map<String, dynamic>? existing = await firestoreClient.getById<Map<String, dynamic>>(
    FirebaseCollections.usersV2,
    user.uid,
    (data, _) => data,
    sourceTag: '$sourceTagPrefix.find_user_doc',
  );
  operation.requireCurrent();
  final String now = DateTime.now().toUtc().toIso8601String();
  if (existing != null) {
    final Map<String, String> synced =
        syncProfile?.call(PrismUsersV2.fromMapWithUser(existing, user)) ?? const <String, String>{};
    owner = PrismUsersV2.fromMapWithUser(<String, dynamic>{...existing, ...synced}, user);
    operation.publish(owner);
    await firestoreClient.updateDoc(FirebaseCollections.usersV2, user.uid, {
      'id': user.uid,
      'lastLoginAt': now,
      'loggedIn': true,
      ...synced,
    }, sourceTag: '$sourceTagPrefix.update_last_login');
  } else {
    owner = PrismUsersV2(
      name: displayName,
      bio: '',
      createdAt: now,
      email: user.email ?? '',
      username: '',
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
    operation.publish(owner);
    await firestoreClient.setDoc(FirebaseCollections.usersV2, user.uid, <String, dynamic>{
      ...owner.toJson(),
      'usernameCandidate': sanitizeUsername(displayName),
    }, sourceTag: '$sourceTagPrefix.create_user');
  }
  operation.requireCurrent();

  // Retry unfinished initial naming on the next sign-in too. A creation trigger may already have won.
  if (owner.username.isEmpty) {
    final PrismUsersV2 profile = owner;
    try {
      final String claimed = await UsernameService.instance.claim(sanitizeUsername(displayName), initial: true);
      operation.requireCurrent();
      profile.username = claimed;
    } catch (_) {
      if (operation.isCurrent) {
        profile.loggedIn = false;
      }
      rethrow;
    }
  }

  await app_state.persistPrismUser();
  operation.requireCurrent();
  try {
    await getIt<OnboardingV2Repository>().syncLocalInterests(userId: user.uid);
  } catch (error, stackTrace) {
    logger.w('Guest interests did not sync.', tag: 'Auth', error: error, stackTrace: stackTrace);
  }
  operation.requireCurrent();
  await analytics.setUserId(user.uid);
  operation.requireCurrent();
  await analytics.setUserProperty(name: AnalyticsUserProperty.subscriptionTier.wireName, value: owner.subscriptionTier);
  operation.requireCurrent();
  await analytics.setUserProperty(name: AnalyticsUserProperty.isPremium.wireName, value: owner.premium ? '1' : '0');
  operation.requireCurrent();
  final FirebaseMessaging resolvedMessaging = messaging ?? FirebaseMessaging.instance;
  final String? userTopic = userTopicFromId(user.uid);
  if (userTopic != null) {
    await subscribeToTopicSafely(
      resolvedMessaging,
      userTopic,
      sourceTag: '$sourceTagPrefix.user_topic',
      isCurrent: () => operation.isCurrent,
    );
    operation.requireCurrent();
  }
  final String? followersTopic = followersTopicFromEmail(email);
  if (followersTopic != null) {
    await subscribeToTopicSafely(
      resolvedMessaging,
      followersTopic,
      sourceTag: '$sourceTagPrefix.followers_topic',
      isCurrent: () => operation.isCurrent,
    );
    operation.requireCurrent();
  }
  unawaited(FcmTokenService.instance.syncToken(userId: user.uid, messaging: resolvedMessaging));
  FcmTokenService.instance.listenForTokenRefresh(userId: user.uid, messaging: resolvedMessaging);
  Future<void> runBootstrap() async {
    operation.requireCurrent();
    final Future<void> favourites = _startFavouritesSync(user.uid);
    await PurchasesService.instance.checkAndPersistPremium();
    operation.requireCurrent();
    await CoinsService.instance.bootstrapForCurrentUser();
    operation.requireCurrent();
    await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
    operation.requireCurrent();
    await CoinsService.instance.processPendingReferralIfEligible();
    await favourites;
  }

  late final Future<void> bootstrap;
  bootstrap = runBootstrap()
      .catchError((Object error, StackTrace stackTrace) {
        logger.w('Sign-in bootstrap failed.', tag: 'Auth', error: error, stackTrace: stackTrace);
      })
      .whenComplete(() => _signInBootstraps.remove(bootstrap));
  _signInBootstraps.add(bootstrap);
  unawaited(bootstrap);
  await syncSentryUserScope(loggedIn: owner.loggedIn, id: user.uid, email: owner.email, username: owner.username);
  operation.requireCurrent();
}
