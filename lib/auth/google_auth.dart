import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/google_profile_sync.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/streak_widget_sync.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/favourite_walls/data/favourites_sync_service.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_favourites_store.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_folders_store.dart';
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:Prism/features/wallpaper_history/data/history_wall_stores.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when the user selects a different Google account during re-authentication.
class WrongAccountException implements Exception {
  final String selectedEmail;
  final String expectedEmail;
  const WrongAccountException({required this.selectedEmail, required this.expectedEmail});
  @override
  String toString() => 'WrongAccountException: selected $selectedEmail but expected $expectedEmail';
}

String genericSignInErrorMessage(AppLocalizations l10n) => l10n.coreGenericSignInError;

/// Sign-in ran before [Firebase.initializeApp] finished, or after it failed or was skipped.
class FirebaseUnavailableException implements Exception {
  const FirebaseUnavailableException();

  @override
  String toString() => 'FirebaseUnavailableException';
}

/// The toast text for a Google sign-in error that is not a cancellation.
String googleSignInErrorMessage(Object error, AppLocalizations l10n, {TargetPlatform? platform}) {
  if (error is FirebaseUnavailableException) {
    return (platform ?? defaultTargetPlatform) == TargetPlatform.android
        ? l10n.coreGooglePlayServicesSignInError
        : genericSignInErrorMessage(l10n);
  }
  if (error is GoogleSignInException && error.code == GoogleSignInExceptionCode.unknownError) {
    return l10n.coreGoogleSignInNetworkError;
  }
  if (error is FirebaseAuthException && error.code == 'network-request-failed') {
    return l10n.coreGoogleSignInNetworkError;
  }
  return genericSignInErrorMessage(l10n);
}

typedef _GoogleSignInResult = ({UserCredential credential, String? name, String? photoUrl});

class GoogleAuth {
  GoogleAuth({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseMessaging? messaging,
    Future<void> Function()? clearShortcutsFavourites,
    Future<void> Function()? clearShortcutsFolders,
    Future<bool> Function()? firebaseReady,
  }) : _authOverride = auth,
       googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _messaging = messaging,
       _clearShortcutsFavourites = clearShortcutsFavourites ?? ShortcutsFavouritesStore.clear,
       _clearShortcutsFolders = clearShortcutsFolders ?? ShortcutsFoldersStore.clear,
       _firebaseReady = firebaseReady ?? FirebaseInit.defaultAppReady;

  final FirebaseAuth? _authOverride;
  FirebaseAuth? _resolvedAuth;
  final Future<bool> Function() _firebaseReady;
  final GoogleSignIn googleSignIn;
  final FirebaseMessaging? _messaging;
  final Future<void> Function() _clearShortcutsFavourites;
  final Future<void> Function() _clearShortcutsFolders;
  bool _googleSignInInitialized = false;

  /// Waits for startup to finish creating the default app. Returns null when Firebase will not start.
  Future<FirebaseAuth?> _authOrWait() async {
    final FirebaseAuth? existing = _authOverride ?? _resolvedAuth;
    if (existing != null) return existing;
    if (!await _firebaseReady()) return null;
    final FirebaseAuth resolved = FirebaseAuth.instance;
    _resolvedAuth = resolved;
    return resolved;
  }

  FirebaseAuth get _auth {
    final FirebaseAuth? resolved = _authOverride ?? _resolvedAuth;
    if (resolved == null) throw const FirebaseUnavailableException();
    return resolved;
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) {
      return;
    }
    await googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  Future<SignInOutcome> signInWithGoogle() async {
    logger.i('signInWithGoogle start', tag: 'GoogleAuth');
    final SignInSession session = SignInSession();
    if (await _authOrWait() == null) {
      const FirebaseUnavailableException error = FirebaseUnavailableException();
      logger.e('signInWithGoogle failed', tag: 'GoogleAuth', error: error);
      throw error;
    }
    session.bindAuthenticatedUid(() => _auth.currentUser?.uid);
    bool firebaseSignedIn = false;
    try {
      await _ensureGoogleSignInInitialized();
      session.requireCurrent();
      final _GoogleSignInResult google = await _signInToFirebase(session);
      firebaseSignedIn = true;
      final User? user = google.credential.user;
      if (user == null) {
        throw StateError('Firebase user missing after Google sign-in.');
      }
      session.acceptCredential(user);
      // Firebase keeps the Google name of account creation; only [_rememberGoogleProfile] changes it.
      final String? lastGoogleName = user.displayName;
      final String resolvedDisplayName = _resolvedDisplayName(google.name, user);
      final String resolvedEmail = _resolvedEmail(user);
      final String? googlePhotoUrl = sizedGooglePhoto(google.photoUrl);
      final String resolvedPhotoUrl = photoOrPlaceholder(googlePhotoUrl);
      if (resolvedEmail.isEmpty) {
        throw StateError('Google sign-in returned user without email.');
      }
      await completeSignIn(
        user: user,
        displayName: resolvedDisplayName,
        email: resolvedEmail,
        photoUrl: resolvedPhotoUrl,
        sourceTagPrefix: 'auth.signin',
        syncProfile: (PrismUsersV2 profile) => googleProfileUpdates(
          profile,
          lastGoogleName: lastGoogleName,
          googleName: resolvedDisplayName,
          googlePhotoUrl: resolvedPhotoUrl,
        ),
        messaging: _messaging,
        session: session,
      );
      session.requireCurrent();
      await _rememberGoogleProfile(user, session: session, name: resolvedDisplayName, photoUrl: googlePhotoUrl);
      session.requireCurrent();
      await analytics.track(
        const AuthLoginResultEvent(
          method: AuthMethodValue.google,
          result: EventResultValue.success,
          sourceContext: 'google_auth',
        ),
      );
      session.requireCurrent();
      return SignInOutcome.signedIn;
    } catch (e, st) {
      if (_isSignInCancelled(e)) {
        if (firebaseSignedIn) {
          await _rollbackSignIn(session);
        }
        if (session.isCurrent) {
          await _trackSignInFailure(
            const AuthLoginResultEvent(
              method: AuthMethodValue.google,
              result: EventResultValue.cancelled,
              reason: AnalyticsReasonValue.userCancelled,
              sourceContext: 'google_auth',
            ),
          );
        }
        logger.i('signInWithGoogle canceled by user', tag: 'GoogleAuth');
        return SignInOutcome.cancelled;
      }
      if (firebaseSignedIn) {
        await _rollbackSignIn(session);
      }
      if (session.isCurrent) {
        await _trackSignInFailure(
          const AuthLoginResultEvent(
            method: AuthMethodValue.google,
            result: EventResultValue.failure,
            reason: AnalyticsReasonValue.error,
            sourceContext: 'google_auth',
          ),
        );
      }
      logger.e('signInWithGoogle failed', tag: 'GoogleAuth', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// The Google account sheet, or Google's web sign-in when Credential Manager on Android cannot show one.
  Future<_GoogleSignInResult> _signInToFirebase(SignInSession session) async {
    final GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (!_needsWebSignIn(error)) rethrow;
      logger.i(
        'Google account sheet unavailable, using web sign-in',
        tag: 'GoogleAuth',
        fields: <String, Object?>{'code': error.code.name, 'description': error.description},
      );
      session.requireCurrent();
      final UserCredential credential = await _auth.signInWithProvider(
        GoogleAuthProvider()..setCustomParameters(<String, String>{'prompt': 'select_account'}),
      );
      final Map<String, dynamic>? profile = credential.additionalUserInfo?.profile;
      return (
        credential: credential,
        name: profile?['name'] as String?,
        photoUrl: profile?['picture'] as String? ?? credential.user?.photoURL,
      );
    }
    session.requireCurrent();
    final String? idToken = account.authentication.idToken;
    if (idToken == null || idToken.trim().isEmpty) {
      throw StateError('Google sign-in returned no ID token.');
    }
    final UserCredential credential = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    return (credential: credential, name: account.displayName, photoUrl: account.photoUrl);
  }

  /// Credential Manager had no Google account to offer (PRISM-J4), or no provider to ask (PRISM-J2).
  static bool _needsWebSignIn(GoogleSignInException error) =>
      defaultTargetPlatform == TargetPlatform.android &&
      (error.code == GoogleSignInExceptionCode.providerConfigurationError ||
          (error.code == GoogleSignInExceptionCode.unknownError &&
              (error.description ?? '').startsWith('No credential available')));

  Future<void> _rollbackSignIn(SignInSession session) async {
    try {
      await signOutGoogle(session: session);
    } catch (rollbackError, rollbackStackTrace) {
      logger.w(
        'Failed to roll back Firebase sign-in.',
        tag: 'GoogleAuth',
        error: rollbackError,
        stackTrace: rollbackStackTrace,
      );
    }
  }

  Future<void> _trackSignInFailure(AuthLoginResultEvent event) async {
    try {
      await analytics.track(event);
    } catch (error, stackTrace) {
      logger.w('Failed to track sign-in result.', tag: 'GoogleAuth', error: error, stackTrace: stackTrace);
    }
  }

  bool _isSignInCancelled(Object error) {
    if (error is GoogleSignInException) {
      return error.code == GoogleSignInExceptionCode.canceled;
    }
    if (error is FirebaseAuthException) {
      return error.code == 'web-context-canceled';
    }
    final String message = error.toString().toLowerCase();
    return message.contains('user canceled') ||
        message.contains('cancelled') ||
        message.contains('no credential') ||
        message.contains('no credentials available');
  }

  /// The one sign-out path (Google, Apple, account deletion, and a sign-in that
  /// failed after Firebase accepted the credential). Server writes and topic
  /// unsubscribes run first, while the Firebase session can still authorize them.
  Future<bool> signOutGoogle({SignInSession? session}) async {
    final SignInSession operation = session ?? SignInSession();
    FirebaseAuth? auth = await _authOrWait();
    if (!operation.isCurrent) return false;
    if (session == null && auth != null) {
      final FirebaseAuth initialAuth = auth;
      operation.bindAuthenticatedUid(() => initialAuth.currentUser?.uid);
    }
    WallpaperService.invalidatePendingHistoryWrites();
    final PrismUsersV2 existingUser = app_state.prismUser;
    final User? authenticatedUser = auth?.currentUser;
    clearInAppNotificationSyncGateAll();
    await _bounded(FcmTokenService.instance.cancelAndWait, 'stop FCM token writes');
    if (!operation.isCurrent) return false;
    await _bounded(FcmTokenService.instance.captureSyncedBinding, 'capture the synced FCM token');
    if (!operation.isCurrent) return false;
    await _bounded(waitForSignInBootstraps, 'drain sign-in bootstrap');
    if (!operation.isCurrent) return false;
    if (getIt.isRegistered<FavouritesSyncService>()) {
      await _bounded(getIt<FavouritesSyncService>().stop, 'stop favourites sync');
      if (!operation.isCurrent) return false;
    }
    final String authenticatedUid = authenticatedUser?.uid.trim() ?? '';
    final String userId = authenticatedUid.isNotEmpty ? authenticatedUid : existingUser.id;
    String email = existingUser.id == userId ? existingUser.email : '';
    List<String> following = existingUser.id == userId ? existingUser.following : const <String>[];
    if (authenticatedUid.isNotEmpty && existingUser.id != userId) {
      try {
        final Map<String, dynamic>? authenticatedProfile = await firestoreClient
            .getById<Map<String, dynamic>>(
              FirebaseCollections.usersV2,
              userId,
              (Map<String, dynamic> data, String _) => data,
              sourceTag: 'auth.signout.find_user_doc',
            )
            .timeout(signOutStepTimeout);
        email = authenticatedProfile?['email']?.toString() ?? '';
        final Object? storedFollowing = authenticatedProfile?['following'];
        following = storedFollowing is List ? storedFollowing.whereType<String>().toList() : following;
      } catch (e, st) {
        logger.w(
          'Failed to load authenticated profile for topic cleanup.',
          tag: 'GoogleAuth',
          error: e,
          stackTrace: st,
        );
      }
    }
    if (!operation.isCurrent) return false;
    await Future.wait(<Future<void>>[
      _bounded(() => _markLoggedOut(userId), 'mark logged out'),
      _bounded(
        () => _unsubscribeUserTopics(
          operation,
          userId: userId,
          email: authenticatedUser?.email ?? email,
          following: following,
        ),
        'unsubscribe topics',
      ),
      _clearPersonalization(operation),
    ]);
    if (!operation.isCurrent) return false;
    await _bounded(
      () => FcmTokenService.instance.invalidateTokenForSignOut(userId: userId, messaging: _messaging),
      'invalidate FCM token',
    );
    if (!operation.isCurrent) return false;
    try {
      await _ensureGoogleSignInInitialized();
      if (!operation.isCurrent) return false;
      await googleSignIn.signOut();
    } catch (e, st) {
      logger.w(
        'Google signOut failed; continuing local sign-out cleanup.',
        tag: 'GoogleAuth',
        error: e,
        stackTrace: st,
      );
    }
    if (!operation.isCurrent) return false;
    // isSignedIn() reads FirebaseAuth.currentUser directly, so it must actually be cleared
    // here too. Used for Apple-signed-in users as well, not just Google.
    bool firebaseSignOutSucceeded = true;
    try {
      if (auth == null && FirebaseInit.hasDefaultApp) {
        final FirebaseAuth lateAuth = _resolvedAuth = FirebaseAuth.instance;
        if (!operation.isCurrent) return false;
        if (session == null) operation.bindAuthenticatedUid(() => lateAuth.currentUser?.uid);
        auth = lateAuth;
      }
      if (auth != null) await auth.signOut();
    } catch (e, st) {
      firebaseSignOutSucceeded = false;
      logger.w('FirebaseAuth signOut failed; continuing local sign-out cleanup.', error: e, stackTrace: st);
    }
    if (!operation.finishSignOut(firebaseSucceeded: firebaseSignOutSucceeded, guest: createGuestPrismUser())) {
      return false;
    }
    try {
      await syncSentryUserScope(loggedIn: false, id: '', email: '');
    } catch (e, st) {
      logger.w('Failed to clear Sentry user scope.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
    if (!operation.isCurrent) return false;
    try {
      await app_state.persistPrismUser();
    } catch (e, st) {
      logger.w('Failed to persist signed-out user state.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
    if (!operation.isCurrent) return false;
    try {
      await PurchasesService.instance.logOut();
    } catch (e, st) {
      logger.w(
        'RevenueCat signOut failed; continuing local sign-out cleanup.',
        tag: 'GoogleAuth',
        error: e,
        stackTrace: st,
      );
    }
    if (!operation.isCurrent) return false;
    try {
      await analytics.setUserId(null);
    } catch (e, st) {
      logger.w('Failed to clear analytics user id.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
    if (!operation.isCurrent) return false;
    try {
      await analytics.setUserProperty(name: AnalyticsUserProperty.subscriptionTier.wireName, value: 'free');
    } catch (e, st) {
      logger.w('Failed to clear analytics subscription tier.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
    if (!operation.isCurrent) return false;
    try {
      await analytics.setUserProperty(name: AnalyticsUserProperty.isPremium.wireName, value: '0');
    } catch (e, st) {
      logger.w('Failed to clear analytics premium state.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
    if (!operation.isCurrent) return false;
    logger.d('User Sign Out');
    if (auth == null && session == null) unawaited(_signOutWhenFirebaseReady(operation));
    return firebaseSignOutSucceeded;
  }

  Future<void> _signOutWhenFirebaseReady(SignInSession operation) async {
    try {
      if (!await FirebaseInit.readyFuture || !operation.isCurrent || !FirebaseInit.hasDefaultApp) return;
      final FirebaseAuth auth = _resolvedAuth ?? FirebaseAuth.instance;
      _resolvedAuth = auth;
      operation.bindAuthenticatedUid(() => auth.currentUser?.uid);
      await auth.signOut();
    } catch (error, stackTrace) {
      logger.w('Deferred Firebase sign-out failed.', tag: 'GoogleAuth', error: error, stackTrace: stackTrace);
    }
  }

  /// Firestore writes made offline only complete when the server acks them, so
  /// every network step before sign-out gets a limit. A step that runs out of
  /// time is skipped; sign-out itself never waits on the network.
  @visibleForTesting
  static Duration signOutStepTimeout = const Duration(seconds: 3);

  Future<void> _bounded(Future<void> Function() step, String what) async {
    try {
      await step().timeout(signOutStepTimeout);
    } catch (e, st) {
      logger.w('Sign-out step "$what" failed or timed out; continuing.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
  }

  Future<void> _markLoggedOut(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    try {
      await firestoreClient.updateDoc(FirebaseCollections.usersV2, userId, {
        'loggedIn': false,
      }, sourceTag: 'auth.signout.mark_logged_out');
    } catch (e, st) {
      logger.w('Failed to mark user logged out (expected if account was deleted)', error: e, stackTrace: st);
    }
  }

  /// A shared or handed-down device must stop getting the previous user's pushes.
  Future<void> _unsubscribeUserTopics(
    SignInSession operation, {
    required String userId,
    required String email,
    required Iterable<String> following,
  }) async {
    if (userId.isEmpty) {
      return;
    }
    try {
      final FirebaseMessaging messaging = _messaging ?? FirebaseMessaging.instance;
      final String? followersTopic = followersTopicFromEmail(email);
      await Future.wait(<Future<void>>[
        if (userTopicFromId(userId) case final String userTopic)
          unsubscribeFromTopicSafely(
            messaging,
            userTopic,
            sourceTag: 'auth.signout.user_topic',
            isCurrent: () => operation.isCurrent,
          ),
        if (followersTopic != null)
          unsubscribeFromTopicSafely(
            messaging,
            followersTopic,
            sourceTag: 'auth.signout.followers_topic',
            isCurrent: () => operation.isCurrent,
          ),
        syncCreatorPostsTopicsForUser(
          messaging,
          userId: userId,
          subscribed: false,
          sourceTag: 'auth.signout.posts_topics',
          isCurrent: () => operation.isCurrent,
        ),
        unsubscribeLegacyCreatorPostsTopics(
          messaging,
          following,
          sourceTag: 'auth.signout.legacy_posts_topics',
          isCurrent: () => operation.isCurrent,
        ),
      ]);
    } catch (e, st) {
      logger.w('Topic unsubscribe on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
  }

  /// Taste signals, feed impressions, applied and viewed history belong to the user, not the device.
  Future<void> _clearPersonalization(SignInSession operation) async {
    if (!operation.isCurrent) return;
    if (getIt.isRegistered<TasteSignalStore>()) {
      try {
        await getIt<TasteSignalStore>().clear(allowReseed: true);
      } catch (e, st) {
        logger.w('Taste signal clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
      }
    }
    if (!operation.isCurrent) return;
    if (getIt.isRegistered<FeedImpressionStore>()) {
      try {
        await getIt<FeedImpressionStore>().clear();
      } catch (e, st) {
        logger.w('Feed impression clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
      }
    }
    if (!operation.isCurrent) return;
    if (getIt.isRegistered<WallpaperHistoryStore>()) {
      try {
        await getIt<WallpaperHistoryStore>().clear();
      } catch (e, st) {
        logger.w('Wallpaper history clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
      }
    }
    if (!operation.isCurrent) return;
    // The account keeps its synced history. Only this device's copies go.
    if (getIt.isRegistered<RecentlyViewedStore>()) {
      try {
        await getIt<RecentlyViewedStore>().clear();
      } catch (e, st) {
        logger.w('Recently viewed clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
      }
    }
    if (!operation.isCurrent) return;
    if (getIt.isRegistered<SyncedHistoryStore>()) {
      try {
        await getIt<SyncedHistoryStore>().clearLocal();
      } catch (e, st) {
        logger.w('Synced history clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
      }
    }
    if (!operation.isCurrent) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _clearShortcutsFavourites();
      } catch (e, st) {
        logger.w('Shortcuts favourites clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
      }
      if (!operation.isCurrent) return;
      try {
        await _clearShortcutsFolders();
      } catch (e, st) {
        logger.w('Shortcuts folders clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
      }
      if (!operation.isCurrent) return;
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        if (!operation.isCurrent) return;
        await prefs.remove('shortcuts.day_night');
      } catch (e, st) {
        logger.w('Day and night snapshot clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
      }
      if (!operation.isCurrent) return;
      await StreakWidgetSync.clear();
    }
  }

  /// Re-authenticates the current Firebase user with a fresh Google credential.
  /// Required before sensitive operations like account deletion.
  /// Throws [WrongAccountException] if the user selects a different Google account.
  Future<void> reauthenticateCurrentUser() async {
    final SignInSession session = SignInSession();
    if (await _authOrWait() == null) throw const FirebaseUnavailableException();
    session.bindAuthenticatedUid(() => _auth.currentUser?.uid);
    await _ensureGoogleSignInInitialized();
    session.requireCurrent();
    final GoogleSignInAccount googleSignInAccount = await googleSignIn.authenticate();
    session.requireCurrent();
    final String? currentEmail = _auth.currentUser?.email;
    if (currentEmail != null && googleSignInAccount.email != currentEmail) {
      throw WrongAccountException(selectedEmail: googleSignInAccount.email, expectedEmail: currentEmail);
    }
    final GoogleSignInAuthentication googleSignInAuthentication = googleSignInAccount.authentication;
    final String? idToken = googleSignInAuthentication.idToken;
    if (idToken == null || idToken.trim().isEmpty) {
      throw StateError('Google re-authentication returned no ID token.');
    }
    final AuthCredential credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.currentUser!.reauthenticateWithCredential(credential);
    session.requireCurrent();
  }

  Future<bool> isSignedIn() async {
    try {
      if (Env.skipFirebaseInit) {
        return false;
      }
      if (await _authOrWait() == null) return false;
      final User? currentUser = _auth.currentUser;
      final bool signedInWithFirebase =
          currentUser != null && !currentUser.isAnonymous && currentUser.uid.trim().isNotEmpty;
      if (signedInWithFirebase && app_state.prismUser.id == currentUser.uid) {
        return true;
      }

      // Avoid triggering credential-manager lightweight auth flow on startup;
      // that flow can interrupt debug sessions and spawn transient activities.
      return false;
    } catch (e, st) {
      logger.e('Failed to check sign-in status', error: e, stackTrace: st);
      return false;
    }
  }

  /// Saves the Google name and photo on the Firebase user. The next sign-in compares the Prism name with this name to
  /// see if the user changed it, and removing a custom photo in Edit Profile brings back this photo.
  Future<void> _rememberGoogleProfile(
    User user, {
    required SignInSession session,
    required String name,
    required String? photoUrl,
  }) async {
    session.requireCurrent();
    try {
      if (name != user.displayName) {
        await user.updateDisplayName(name);
        session.requireCurrent();
      }
      if (!isSamePhoto(photoUrl, user.photoURL)) {
        await user.updatePhotoURL(photoUrl);
      }
    } catch (error, stackTrace) {
      logger.w(
        'Google name and photo not saved on the Firebase user.',
        tag: 'GoogleAuth',
        error: error,
        stackTrace: stackTrace,
      );
    }
    session.requireCurrent();
  }

  String _resolvedDisplayName(String? googleName, User user) {
    final String fromGoogle = (googleName ?? '').trim();
    if (fromGoogle.isNotEmpty) {
      return fromGoogle;
    }
    final String fromDisplayName = (user.displayName ?? '').trim();
    if (fromDisplayName.isNotEmpty) {
      return fromDisplayName;
    }
    final String fromEmail = (user.email ?? '').trim();
    if (fromEmail.contains('@')) {
      return fromEmail.split('@').first;
    }
    return 'Prism User';
  }

  String _resolvedEmail(User user) => (user.email ?? '').trim();
}
