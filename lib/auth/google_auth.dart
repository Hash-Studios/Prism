import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/features/category_feed/views/pages/home_screen.dart' as home;
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_io/hive_io.dart';

const String USER_OLD_COLLECTION = FirebaseCollections.users;
const String USER_NEW_COLLECTION = FirebaseCollections.usersV2;

class GoogleAuth {
  static const String signInCancelledResult = 'signInWithGoogle canceled';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

  String? name;
  String? email;
  String? imageUrl;
  String errorMsg = "";
  late Box prefs;
  bool isLoggedIn = false;
  bool isLoading = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) {
      return;
    }
    await googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  Future<String> signInWithGoogle() async {
    isLoading = true;
    logger.i('signInWithGoogle start', tag: 'GoogleAuth');
    try {
      prefs = await Hive.openBox('prefs');
      await _ensureGoogleSignInInitialized();
      final GoogleSignInAccount googleSignInAccount = await googleSignIn.authenticate();
      final GoogleSignInAuthentication googleSignInAuthentication = googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(idToken: googleSignInAuthentication.idToken);

      final UserCredential authResult = await _auth.signInWithCredential(credential);
      final User? user = authResult.user;
      assert(user!.email != null);
      assert(user!.displayName != null);
      assert(user!.photoURL != null);
      name = user!.displayName;
      email = user.email;

      final List<Map<String, dynamic>?> usersData = await getUsersData(user);
      // User exists in both. Therefore go ahead with the new collection, and forget the old one.
      logger.d("USERDATA0 ${usersData[0]}");
      logger.d("USERDATA1 ${usersData[1]}");
      if (usersData[0] != null && usersData[1] != null) {
        final doc = usersData[1]!;
        globals.prismUser = PrismUsersV2.fromMapWithUser(doc, user);
        firestoreClient.updateDoc(USER_NEW_COLLECTION, globals.prismUser.id, {
          'lastLoginAt': DateTime.now().toUtc().toIso8601String(),
          'loggedIn': true,
        }, sourceTag: 'auth.signin.update_last_login');
        logger.d("USERDATA CASE1");
      }
      // User exists in old database. Copy/create him in the new db.
      else if (usersData[0] != null && usersData[1] == null) {
        final doc = usersData[0]!;
        globals.prismUser = PrismUsersV2.fromMapWithUser(doc, user);
        firestoreClient.setDoc(
          USER_NEW_COLLECTION,
          globals.prismUser.id,
          globals.prismUser.toJson(),
          sourceTag: 'auth.signin.copy_legacy_user',
        );
        logger.d("USERDATA CASE2");
      }
      // User exists in new database. Simply sign him in.
      else if (usersData[0] == null && usersData[1] != null) {
        final doc = usersData[1]!;
        globals.prismUser = PrismUsersV2.fromMapWithUser(doc, user);
        firestoreClient.updateDoc(USER_NEW_COLLECTION, globals.prismUser.id, {
          'lastLoginAt': DateTime.now().toUtc().toIso8601String(),
          'loggedIn': true,
        }, sourceTag: 'auth.signin.update_last_login_existing');
        logger.d("USERDATA CASE3");
      }
      // User exists in none. Create new data in new db and sign him in.
      else {
        globals.prismUser = PrismUsersV2(
          name: user.displayName!,
          bio: "",
          createdAt: DateTime.now().toUtc().toIso8601String(),
          email: user.email!,
          username: user.displayName!,
          followers: [],
          following: [],
          id: user.uid,
          lastLoginAt: DateTime.now().toUtc().toIso8601String(),
          links: {},
          premium: false,
          subscriptionTier: 'free',
          loggedIn: true,
          profilePhoto: user.photoURL!,
          badges: [],
          coins: 0,
          subPrisms: [],
          transactions: [],
          coverPhoto: "",
        );
        firestoreClient.setDoc(
          USER_NEW_COLLECTION,
          globals.prismUser.id,
          globals.prismUser.toJson(),
          sourceTag: 'auth.signin.create_user',
        );
        logger.d("USERDATA CASE4");
      }

      await prefs.put(main.userHiveKey, globals.prismUser);
      await subscribeToTopicSafely(home.f, user.email!.split("@")[0], sourceTag: 'auth.signin.followers_topic');
      assert(!user.isAnonymous);
      final User? currentUser = _auth.currentUser;
      assert(user.uid == currentUser!.uid);
      analytics.logLogin();
      await PurchasesService.instance.checkAndPersistPremium();
      await CoinsService.instance.bootstrapForCurrentUser();
      await CoinsService.instance.refreshBalance();
      await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
      await CoinsService.instance.maybeAwardProDailyBonus();
      await CoinsService.instance.processPendingReferralIfEligible();
      await syncSentryUserScope(
        loggedIn: globals.prismUser.loggedIn,
        id: globals.prismUser.id,
        email: globals.prismUser.email,
        username: globals.prismUser.username,
      );
      return 'signInWithGoogle succeeded: $user';
    } catch (e, st) {
      if (_isSignInCancelled(e)) {
        logger.i('signInWithGoogle canceled by user', tag: 'GoogleAuth');
        return signInCancelledResult;
      }
      logger.e('signInWithGoogle failed', tag: 'GoogleAuth', error: e, stackTrace: st);
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  bool _isSignInCancelled(Object error) {
    if (error is GoogleSignInException) {
      return error.code == GoogleSignInExceptionCode.canceled;
    }
    final String message = error.toString().toLowerCase();
    return message.contains('user canceled') || message.contains('cancelled');
  }

  Future<bool> signOutGoogle() async {
    final String existingUserId = globals.prismUser.id;
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
    globals.prismUser = PrismUsersV2(
      name: "",
      bio: "",
      createdAt: DateTime.now().toUtc().toIso8601String(),
      email: "",
      username: "",
      followers: [],
      following: [],
      id: "",
      lastLoginAt: DateTime.now().toUtc().toIso8601String(),
      links: {},
      premium: false,
      subscriptionTier: 'free',
      loggedIn: false,
      profilePhoto: globals.defaultProfilePhotoUrl,
      badges: [],
      coins: 0,
      subPrisms: [],
      transactions: [],
      coverPhoto: "",
    );
    await syncSentryUserScope(loggedIn: false, id: "", email: "");
    Hive.openBox('prefs').then((value) {
      value.put(main.userHiveKey, globals.prismUser);
    });
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
      if (existingUserId.isNotEmpty) {
        firestoreClient.updateDoc(USER_NEW_COLLECTION, existingUserId, {
          'loggedIn': false,
        }, sourceTag: 'auth.signout.mark_logged_out');
      }
    } catch (e, st) {
      logger.e('Failed to mark user logged out', error: e, stackTrace: st);
    }
    logger.d("User Sign Out");
    return true;
  }

  Future<bool> isSignedIn() async {
    try {
      final User? currentUser = _auth.currentUser;
      final bool signedInWithFirebase =
          currentUser != null &&
          !currentUser.isAnonymous &&
          (currentUser.email ?? '').trim().isNotEmpty &&
          currentUser.providerData.any((provider) => provider.providerId == GoogleAuthProvider.PROVIDER_ID);
      if (signedInWithFirebase) {
        logger.d('true');
        return true;
      }

      // Avoid triggering credential-manager lightweight auth flow on startup;
      // that flow can interrupt debug sessions and spawn transient activities.
      logger.d('false');
      return false;
    } catch (e, st) {
      logger.e('Failed to check sign-in status', error: e, stackTrace: st);
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserOLD(User? user) async {
    final rows = await firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: USER_OLD_COLLECTION,
        sourceTag: 'auth.get_user_old',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'id', op: FirestoreFilterOp.isEqualTo, value: user!.uid)],
        limit: 1,
      ),
      (data, docId) => <String, dynamic>{...data, '__docId': docId},
    );
    if (rows.isEmpty) {
      return null;
    }
    final String docId = rows.first['__docId']?.toString() ?? '';
    if (docId.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<Map<String, dynamic>?> getUserNEW(User? user) async {
    final rows = await firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: USER_NEW_COLLECTION,
        sourceTag: 'auth.get_user_new',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'id', op: FirestoreFilterOp.isEqualTo, value: user!.uid)],
        limit: 1,
      ),
      (data, docId) => <String, dynamic>{...data, '__docId': docId},
    );
    if (rows.isEmpty) {
      return null;
    }
    final String docId = rows.first['__docId']?.toString() ?? '';
    if (docId.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<List<Map<String, dynamic>?>> getUsersData(User? user) async {
    late final List<Map<String, dynamic>?> output;
    await Future.wait([getUserOLD(user), getUserNEW(user)]).then((value) => output = value);
    return output;
  }
}
