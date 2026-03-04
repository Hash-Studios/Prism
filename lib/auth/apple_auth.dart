import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/category_feed/views/pages/home_screen.dart' as home;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuth {
  static const String signInCancelledResult = 'signInWithApple canceled';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> signInWithApple() async {
    logger.i('signInWithApple start', tag: 'AppleAuth');
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider(
        'apple.com',
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

      final UserCredential authResult = await _auth.signInWithCredential(oauthCredential);
      final User? user = authResult.user;

      if (user == null) {
        throw Exception('Apple sign-in returned null user');
      }

      // Apple only provides the name on the very first sign-in.
      final String displayName = (appleCredential.givenName ?? '').isNotEmpty
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
          : user.displayName ?? user.email?.split('@')[0] ?? 'Prism User';

      if ((appleCredential.givenName ?? '').isNotEmpty && user.displayName == null) {
        await user.updateDisplayName(displayName);
      }

      final String email = appleCredential.email ?? user.email ?? '';
      final String photoURL = user.photoURL ?? app_state.defaultProfilePhotoUrl;

      final List<Map<String, dynamic>?> usersData = await _getUsersData(user);

      if (usersData[0] != null && usersData[1] != null) {
        final doc = usersData[1]!;
        app_state.prismUser = PrismUsersV2.fromMapWithUser(doc, user);
        firestoreClient.updateDoc(FirebaseCollections.usersV2, app_state.prismUser.id, {
          'lastLoginAt': DateTime.now().toUtc().toIso8601String(),
          'loggedIn': true,
        }, sourceTag: 'apple_auth.signin.update_last_login');
      } else if (usersData[0] != null && usersData[1] == null) {
        final doc = usersData[0]!;
        app_state.prismUser = PrismUsersV2.fromMapWithUser(doc, user);
        firestoreClient.setDoc(
          FirebaseCollections.usersV2,
          app_state.prismUser.id,
          app_state.prismUser.toJson(),
          sourceTag: 'apple_auth.signin.copy_legacy_user',
        );
      } else if (usersData[0] == null && usersData[1] != null) {
        final doc = usersData[1]!;
        app_state.prismUser = PrismUsersV2.fromMapWithUser(doc, user);
        firestoreClient.updateDoc(FirebaseCollections.usersV2, app_state.prismUser.id, {
          'lastLoginAt': DateTime.now().toUtc().toIso8601String(),
          'loggedIn': true,
        }, sourceTag: 'apple_auth.signin.update_last_login_existing');
      } else {
        app_state.prismUser = PrismUsersV2(
          name: displayName,
          bio: '',
          createdAt: DateTime.now().toUtc().toIso8601String(),
          email: email,
          username: displayName,
          followers: [],
          following: [],
          id: user.uid,
          lastLoginAt: DateTime.now().toUtc().toIso8601String(),
          links: {},
          premium: false,
          loggedIn: true,
          profilePhoto: photoURL,
          badges: [],
          coins: 0,
          subPrisms: [],
          transactions: [],
          coverPhoto: '',
        );
        firestoreClient.setDoc(
          FirebaseCollections.usersV2,
          app_state.prismUser.id,
          app_state.prismUser.toJson(),
          sourceTag: 'apple_auth.signin.create_user',
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
      final String? followersTopic = followersTopicFromEmail(email);
      if (followersTopic != null) {
        await subscribeToTopicSafely(home.f, followersTopic, sourceTag: 'apple_auth.signin.followers_topic');
      }
      unawaited(FcmTokenService.instance.syncToken(userId: app_state.prismUser.id));
      FcmTokenService.instance.listenForTokenRefresh(userId: app_state.prismUser.id);
      await analytics.track(
        const AuthLoginResultEvent(
          method: AuthMethodValue.apple,
          result: EventResultValue.success,
          sourceContext: 'apple_auth',
        ),
      );
      await PurchasesService.instance.checkAndPersistPremium();
      await CoinsService.instance.bootstrapForCurrentUser();
      await CoinsService.instance.refreshBalance();
      await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
      await CoinsService.instance.maybeAwardProDailyBonus();
      await CoinsService.instance.processPendingReferralIfEligible();
      await syncSentryUserScope(
        loggedIn: app_state.prismUser.loggedIn,
        id: app_state.prismUser.id,
        email: app_state.prismUser.email,
        username: app_state.prismUser.username,
      );
      return 'signInWithApple succeeded: $user';
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        await analytics.track(
          const AuthLoginResultEvent(
            method: AuthMethodValue.apple,
            result: EventResultValue.cancelled,
            reason: AnalyticsReasonValue.userCancelled,
            sourceContext: 'apple_auth',
          ),
        );
        logger.i('signInWithApple canceled by user', tag: 'AppleAuth');
        return signInCancelledResult;
      }
      await analytics.track(
        const AuthLoginResultEvent(
          method: AuthMethodValue.apple,
          result: EventResultValue.failure,
          reason: AnalyticsReasonValue.error,
          sourceContext: 'apple_auth',
        ),
      );
      logger.e('signInWithApple authorization failed', tag: 'AppleAuth', error: e);
      rethrow;
    } catch (e, st) {
      await analytics.track(
        const AuthLoginResultEvent(
          method: AuthMethodValue.apple,
          result: EventResultValue.failure,
          reason: AnalyticsReasonValue.error,
          sourceContext: 'apple_auth',
        ),
      );
      logger.e('signInWithApple failed', tag: 'AppleAuth', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getUserNEW(User user) async {
    final rows = await firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.usersV2,
        sourceTag: 'apple_auth.get_user_new',
        filters: [FirestoreFilter(field: 'id', op: FirestoreFilterOp.isEqualTo, value: user.uid)],
        limit: 1,
      ),
      (data, docId) => <String, dynamic>{...data, '__docId': docId},
    );
    if (rows.isEmpty) return null;
    final docId = rows.first['__docId']?.toString() ?? '';
    if (docId.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>?>> _getUsersData(User user) {
    return Future.wait([_getUserNEW(user)]);
  }
}
