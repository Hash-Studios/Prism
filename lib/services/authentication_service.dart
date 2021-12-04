import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:prism/const/firestore_data.dart';
import 'package:prism/model/user_model.dart';
import 'package:prism/services/logger.dart';

class AuthService {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  auth.User? _user;
  PrismUsersV2? _prismUsersV2;

  auth.User? get user => _user;
  PrismUsersV2? get prismUsersV2 => _prismUsersV2;

  Stream<auth.User?> get authStream => _firebaseAuth.userChanges();

  AuthService() {
    authStream.listen((event) {
      if (event != null) {
        if (_user != null) {
          if (event != _user) {
            updatePrismUserFromUser(event);
          }
        }
      }
    });
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleSignInAccount =
          await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount!.authentication;

      final auth.AuthCredential credential = auth.GoogleAuthProvider.credential(
        accessToken: googleSignInAuthentication.accessToken,
        idToken: googleSignInAuthentication.idToken,
      );

      final auth.UserCredential authResult =
          await _firebaseAuth.signInWithCredential(credential);

      _user = authResult.user;
      assert(_user!.email != null);
      assert(_user!.displayName != null);
      assert(_user!.photoURL != null);

      if (_user != null) {
        updatePrismUserFromUser(_user!);
      } else {
        logger.i("Login unsuccessful!");
      }
    } catch (e, s) {
      logger.i("Login unsuccessful due to error!");
      logger.e(e, s, s);
    }
  }

  Future<void> signOutWithGoogle() async {
    if (_user != null && _prismUsersV2 != null) {
      FirebaseFirestore.instance
          .collection(USER_NEW_COLLECTION)
          .doc(_prismUsersV2!.id)
          .update({
        'loggedIn': false,
      });
    }
    await _googleSignIn.signOut();
    _user = null;
    _prismUsersV2 = null;
    logger.i("Logout successful!");
  }

  Future<bool> isSignedIn() async {
    final bool userSignedIn = await _googleSignIn.isSignedIn() &&
        _user != null &&
        _prismUsersV2 != null;
    logger.i("User signed in : $userSignedIn");
    return userSignedIn;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getUsersDataFromCollection(
      auth.User? user, String collection) async {
    final QuerySnapshot<Map<String, dynamic>> result = await FirebaseFirestore
        .instance
        .collection(collection)
        .where('id', isEqualTo: user!.uid)
        .get();
    final List<DocumentSnapshot<Map<String, dynamic>>> documents = result.docs;
    return documents.isNotEmpty ? documents.first : null;
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>?>> getUsersData(
      auth.User? user) async {
    late final List<DocumentSnapshot<Map<String, dynamic>>?> output;
    await Future.wait([
      getUsersDataFromCollection(user, USER_OLD_COLLECTION),
      getUsersDataFromCollection(user, USER_NEW_COLLECTION)
    ]).then((value) => output = value);
    return output;
  }

  Future<void> updatePrismUserFromUser(auth.User event) async {
    final List<DocumentSnapshot<Map<String, dynamic>>?> usersData =
        await getUsersData(event);
    // User exists in both. Therefore go ahead with the new collection, and forget the old one.
    logger.d("USERDATA0 ${usersData[0]}");
    logger.d("USERDATA1 ${usersData[1]}");
    if (usersData[0] != null && usersData[1] != null) {
      final doc = usersData[1]!;
      _prismUsersV2 = PrismUsersV2.fromDocumentSnapshot(doc, event);
      FirebaseFirestore.instance
          .collection(USER_NEW_COLLECTION)
          .doc(_prismUsersV2!.id)
          .update({
        'lastLoginAt': DateTime.now().toUtc().toIso8601String(),
        'loggedIn': true,
      });
      logger.d("USERDATA CASE1");
    }
    // User exists in old database. Copy/create him in the new db.
    else if (usersData[0] != null && usersData[1] == null) {
      final doc = usersData[0]!;
      _prismUsersV2 = PrismUsersV2.fromDocumentSnapshot(doc, event);
      FirebaseFirestore.instance
          .collection(USER_NEW_COLLECTION)
          .doc(_prismUsersV2!.id)
          .set(_prismUsersV2!.toJson());
      logger.d("USERDATA CASE2");
    }
    // User exists in new database. Simply sign him in.
    else if (usersData[0] == null && usersData[1] != null) {
      final doc = usersData[1]!;
      _prismUsersV2 = PrismUsersV2.fromDocumentSnapshot(doc, event);
      FirebaseFirestore.instance
          .collection(USER_NEW_COLLECTION)
          .doc(_prismUsersV2!.id)
          .update({
        'lastLoginAt': DateTime.now().toUtc().toIso8601String(),
        'loggedIn': true,
      });
      logger.d("USERDATA CASE3");
    }
    // User exists in none. Create new data in new db and sign him in.
    else {
      _prismUsersV2 = PrismUsersV2(
        name: event.displayName!,
        bio: "",
        createdAt: DateTime.now().toUtc().toIso8601String(),
        email: event.email!,
        username: event.displayName!,
        followers: [],
        following: [],
        id: event.uid,
        lastLoginAt: DateTime.now().toUtc().toIso8601String(),
        links: {},
        premium: false,
        loggedIn: true,
        profilePhoto: event.photoURL!,
        badges: [],
        coins: 0,
        subPrisms: [],
        transactions: [],
        coverPhoto: "",
      );
      FirebaseFirestore.instance
          .collection(USER_NEW_COLLECTION)
          .doc(_prismUsersV2!.id)
          .set(_prismUsersV2!.toJson());
      logger.d("USERDATA CASE4");
    }
  }
}
