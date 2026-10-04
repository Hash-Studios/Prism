import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thrown when the user selects a different Google account during re-authentication.
class WrongAccountException implements Exception {
  final String selectedEmail;
  final String expectedEmail;
  const WrongAccountException({required this.selectedEmail, required this.expectedEmail});
  @override
  String toString() => 'WrongAccountException: selected $selectedEmail but expected $expectedEmail';
}

class GoogleAuth {
  GoogleAuth({FirebaseAuth? auth, GoogleSignIn? googleSignIn, FirebaseMessaging? messaging})
    : _auth = auth ?? FirebaseAuth.instance,
      googleSignIn = googleSignIn ?? GoogleSignIn.instance,
      _messaging = messaging;

  final FirebaseAuth _auth;
  final GoogleSignIn googleSignIn;
  final FirebaseMessaging? _messaging;
  bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) {
      return;
    }
    await googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  Future<SignInOutcome> signInWithGoogle() async {
    logger.i('signInWithGoogle start', tag: 'GoogleAuth');
    bool firebaseSignedIn = false;
    try {
      await _ensureGoogleSignInInitialized();
      final GoogleSignInAccount googleSignInAccount = await googleSignIn.authenticate();
      final GoogleSignInAuthentication googleSignInAuthentication = googleSignInAccount.authentication;
      final String? idToken = googleSignInAuthentication.idToken;
      if (idToken == null || idToken.trim().isEmpty) {
        throw StateError('Google sign-in returned no ID token.');
      }

      final AuthCredential credential = GoogleAuthProvider.credential(idToken: idToken);

      final UserCredential authResult = await _auth.signInWithCredential(credential);
      firebaseSignedIn = true;
      final User? user = authResult.user;
      if (user == null) {
        throw StateError('Firebase user missing after Google sign-in.');
      }
      final String resolvedDisplayName = _resolvedDisplayName(user);
      final String resolvedEmail = _resolvedEmail(user);
      final String resolvedPhotoUrl = _resolvedPhotoUrl(user);
      if (resolvedEmail.isEmpty) {
        throw StateError('Google sign-in returned user without email.');
      }
      await completeSignIn(
        user: user,
        displayName: resolvedDisplayName,
        email: resolvedEmail,
        photoUrl: resolvedPhotoUrl,
        sourceTagPrefix: 'auth.signin',
        messaging: _messaging,
      );
      await analytics.track(
        const AuthLoginResultEvent(
          method: AuthMethodValue.google,
          result: EventResultValue.success,
          sourceContext: 'google_auth',
        ),
      );
      return SignInOutcome.signedIn;
    } catch (e, st) {
      if (_isSignInCancelled(e)) {
        if (firebaseSignedIn) {
          await _rollbackSignIn();
        }
        await _trackSignInFailure(
          const AuthLoginResultEvent(
            method: AuthMethodValue.google,
            result: EventResultValue.cancelled,
            reason: AnalyticsReasonValue.userCancelled,
            sourceContext: 'google_auth',
          ),
        );
        logger.i('signInWithGoogle canceled by user', tag: 'GoogleAuth');
        return SignInOutcome.cancelled;
      }
      if (firebaseSignedIn) {
        await _rollbackSignIn();
      }
      await _trackSignInFailure(
        const AuthLoginResultEvent(
          method: AuthMethodValue.google,
          result: EventResultValue.failure,
          reason: AnalyticsReasonValue.error,
          sourceContext: 'google_auth',
        ),
      );
      logger.e('signInWithGoogle failed', tag: 'GoogleAuth', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _rollbackSignIn() async {
    try {
      await signOutGoogle();
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
      return error.code == GoogleSignInExceptionCode.canceled || error.code == GoogleSignInExceptionCode.unknownError;
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
  Future<bool> signOutGoogle() async {
    clearInAppNotificationSyncGateAll();
    await _bounded(FcmTokenService.instance.cancelAndWait, 'stop FCM token writes');
    await _bounded(waitForSignInBootstraps, 'drain sign-in bootstrap');
    final PrismUsersV2 existingUser = app_state.prismUser;
    final User? authenticatedUser = _auth.currentUser;
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
    await Future.wait(<Future<void>>[
      _bounded(() => _markLoggedOut(userId), 'mark logged out'),
      _bounded(
        () => _unsubscribeUserTopics(userId: userId, email: authenticatedUser?.email ?? email, following: following),
        'unsubscribe topics',
      ),
      _clearPersonalization(),
    ]);
    try {
      await _ensureGoogleSignInInitialized();
      await googleSignIn.signOut();
    } catch (e, st) {
      logger.w(
        'Google signOut failed; continuing local sign-out cleanup.',
        tag: 'GoogleAuth',
        error: e,
        stackTrace: st,
      );
    }
    app_state.prismUser = createGuestPrismUser();
    // isSignedIn() reads FirebaseAuth.currentUser directly, so it must actually be cleared
    // here too. Used for Apple-signed-in users as well, not just Google.
    bool firebaseSignOutSucceeded = true;
    try {
      await _auth.signOut();
    } catch (e, st) {
      firebaseSignOutSucceeded = false;
      logger.w('FirebaseAuth signOut failed; continuing local sign-out cleanup.', error: e, stackTrace: st);
    }
    try {
      await syncSentryUserScope(loggedIn: false, id: '', email: '');
    } catch (e, st) {
      logger.w('Failed to clear Sentry user scope.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
    try {
      await app_state.persistPrismUser();
    } catch (e, st) {
      logger.w('Failed to persist signed-out user state.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
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
    try {
      await analytics.setUserId(null);
    } catch (e, st) {
      logger.w('Failed to clear analytics user id.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
    try {
      await analytics.setUserProperty(name: AnalyticsUserProperty.subscriptionTier.wireName, value: 'free');
    } catch (e, st) {
      logger.w('Failed to clear analytics subscription tier.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
    try {
      await analytics.setUserProperty(name: AnalyticsUserProperty.isPremium.wireName, value: '0');
    } catch (e, st) {
      logger.w('Failed to clear analytics premium state.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
    logger.d('User Sign Out');
    return firebaseSignOutSucceeded;
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
  Future<void> _unsubscribeUserTopics({
    required String userId,
    required String email,
    required Iterable<String> following,
  }) async {
    if (userId.isEmpty) {
      return;
    }
    try {
      final FirebaseMessaging messaging = _messaging ?? FirebaseMessaging.instance;
      final String? userTopic = userTopicFromId(userId);
      final String? followersTopic = followersTopicFromEmail(email);
      await Future.wait(<Future<void>>[
        if (userTopic != null) unsubscribeFromTopicSafely(messaging, userTopic, sourceTag: 'auth.signout.user_topic'),
        if (followersTopic != null)
          unsubscribeFromTopicSafely(messaging, followersTopic, sourceTag: 'auth.signout.followers_topic'),
        setCreatorPostsTopics(messaging, following, subscribed: false, sourceTag: 'auth.signout.posts_topics'),
      ]);
    } catch (e, st) {
      logger.w('Topic unsubscribe on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
  }

  /// Taste signals and feed impressions belong to the user, not the device.
  Future<void> _clearPersonalization() async {
    if (getIt.isRegistered<TasteSignalStore>()) {
      try {
        await getIt<TasteSignalStore>().clear(allowReseed: true);
      } catch (e, st) {
        logger.w('Taste signal clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
      }
    }
    if (getIt.isRegistered<FeedImpressionStore>()) {
      try {
        await getIt<FeedImpressionStore>().clear();
      } catch (e, st) {
        logger.w('Feed impression clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
      }
    }
  }

  /// Re-authenticates the current Firebase user with a fresh Google credential.
  /// Required before sensitive operations like account deletion.
  /// Throws [WrongAccountException] if the user selects a different Google account.
  Future<void> reauthenticateCurrentUser() async {
    await _ensureGoogleSignInInitialized();
    final GoogleSignInAccount googleSignInAccount = await googleSignIn.authenticate();
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
  }

  Future<bool> isSignedIn() async {
    try {
      if (Env.skipFirebaseInit) {
        return false;
      }
      final User? currentUser = _auth.currentUser;
      final bool signedInWithFirebase =
          currentUser != null && !currentUser.isAnonymous && currentUser.uid.trim().isNotEmpty;
      // A blank stored profile means sign-in never finished: every write would target an empty doc id.
      if (signedInWithFirebase && app_state.prismUser.id.trim().isNotEmpty) {
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

  String _resolvedDisplayName(User user) {
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

  String _resolvedPhotoUrl(User user) {
    final String candidate = (user.photoURL ?? '').trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }
    return app_state.defaultProfilePhotoUrl;
  }
}
