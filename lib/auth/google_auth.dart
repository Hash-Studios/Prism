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
        await analytics.track(
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
      await analytics.track(
        const AuthLoginResultEvent(
          method: AuthMethodValue.google,
          result: EventResultValue.failure,
          reason: AnalyticsReasonValue.error,
          sourceContext: 'google_auth',
        ),
      );
      logger.e('signInWithGoogle failed', tag: 'GoogleAuth', error: e, stackTrace: st);
      if (firebaseSignedIn) {
        await signOutGoogle();
      }
      rethrow;
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
    FcmTokenService.instance.cancel();
    final PrismUsersV2 existingUser = app_state.prismUser;
    await Future.wait(<Future<void>>[
      _markLoggedOut(existingUser.id),
      _unsubscribeUserTopics(existingUser),
      _clearPersonalization(),
    ]);
    await _ensureGoogleSignInInitialized();
    try {
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
    try {
      await _auth.signOut();
    } catch (e, st) {
      logger.w('FirebaseAuth signOut failed; continuing local sign-out cleanup.', error: e, stackTrace: st);
    }
    await syncSentryUserScope(loggedIn: false, id: "", email: "");
    await app_state.persistPrismUser();
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
    await analytics.setUserId(null);
    await analytics.setUserProperty(name: AnalyticsUserProperty.subscriptionTier.wireName, value: 'free');
    await analytics.setUserProperty(name: AnalyticsUserProperty.isPremium.wireName, value: '0');
    logger.d("User Sign Out");
    return true;
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
  Future<void> _unsubscribeUserTopics(PrismUsersV2 user) async {
    if (user.id.isEmpty) {
      return;
    }
    try {
      final FirebaseMessaging messaging = _messaging ?? FirebaseMessaging.instance;
      final String? userTopic = userTopicFromId(user.id);
      final String? followersTopic = followersTopicFromEmail(user.email);
      await Future.wait(<Future<void>>[
        if (userTopic != null) unsubscribeFromTopicSafely(messaging, userTopic, sourceTag: 'auth.signout.user_topic'),
        if (followersTopic != null)
          unsubscribeFromTopicSafely(messaging, followersTopic, sourceTag: 'auth.signout.followers_topic'),
        setCreatorPostsTopics(messaging, user.following, subscribed: false, sourceTag: 'auth.signout.posts_topics'),
      ]);
    } catch (e, st) {
      logger.w('Topic unsubscribe on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
    }
  }

  /// Taste signals and feed impressions belong to the user, not the device.
  Future<void> _clearPersonalization() async {
    try {
      await getIt<TasteSignalStore>().clear(allowReseed: true);
      await getIt<FeedImpressionStore>().clear();
    } catch (e, st) {
      logger.w('Personalization clear on sign-out failed.', tag: 'GoogleAuth', error: e, stackTrace: st);
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
      if (signedInWithFirebase) {
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
