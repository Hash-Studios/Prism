import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/payments/upgrade.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:Prism/ui/pages/home/wallpapers/homeScreen.dart' as home;
import 'package:Prism/global/globals.dart' as globals;

const String USER_OLD_COLLECTION = 'users';
const String USER_NEW_COLLECTION = 'usersv2';

class GoogleAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn();

  String? name;
  String? email;
  String? imageUrl;
  String errorMsg = "";
  late Box prefs;
  bool isLoggedIn = false;
  bool isLoading = false;

  Future<String> signInWithGoogle() async {
    isLoading = true;
    prefs = await Hive.openBox('prefs');
    final GoogleSignInAccount? googleSignInAccount =
        await googleSignIn.signIn();
    final GoogleSignInAuthentication googleSignInAuthentication =
        await googleSignInAccount!.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleSignInAuthentication.accessToken,
      idToken: googleSignInAuthentication.idToken,
    );

    final UserCredential authResult =
        await _auth.signInWithCredential(credential);
    final User? user = authResult.user;
    assert(user!.email != null);
    assert(user!.displayName != null);
    assert(user!.photoURL != null);
    name = user!.displayName;
    email = user.email;

    if (user != null) {
      final List<DocumentSnapshot?> usersData = await getUsersData(user);
      // User exists in both. Therefore go ahead with the new collection, and forget the old one.
      print("USERDATA0 ${usersData[0]}");
      print("USERDATA1 ${usersData[1]}");
      if (usersData[0] != null && usersData[1] != null) {
        final doc = usersData[1]!;
        globals.prismUser = PrismUsers(
          bio: (doc.data()!["bio"] ?? "").toString(),
          createdAt: doc.data()!["createdAt"].toString(),
          email: doc.data()!["email"].toString(),
          username: (doc.data()!["username"] ?? user.displayName).toString(),
          followers: doc.data()!["followers"] as List ?? [],
          following: doc.data()!["following"] as List ?? [],
          id: doc.data()!["id"].toString(),
          lastLogin:
              ((doc.data()!["lastLogin"] as Timestamp?) ?? Timestamp.now())
                  .toDate(),
          links: doc.data()!["links"] as Map ?? {},
          premium: doc.data()!["premium"] as bool,
          loggedIn: true,
          profilePhoto:
              (doc.data()!["profilePhoto"] ?? user.photoURL).toString(),
        );
        FirebaseFirestore.instance
            .collection(USER_NEW_COLLECTION)
            .doc(globals.prismUser.id)
            .update({
          'bio': globals.prismUser.bio,
          'username': globals.prismUser.username,
          'lastLogin': DateTime.now(),
          'links': globals.prismUser.links,
          'profilePhoto': globals.prismUser.profilePhoto,
        });
        print("USERDATA CASE1 ${globals.prismUser.toJson()}");
      }
      // User exists in old database. Copy/create him in the new db.
      else if (usersData[0] != null && usersData[1] == null) {
        final doc = usersData[0]!;
        globals.prismUser = PrismUsers(
          bio: (doc.data()!["bio"] ?? "").toString(),
          createdAt: doc.data()!["createdAt"].toString(),
          email: doc.data()!["email"].toString(),
          username: (doc.data()!["username"] ?? user.displayName).toString(),
          followers: doc.data()!["followers"] as List ?? [],
          following: doc.data()!["following"] as List ?? [],
          id: doc.data()!["id"].toString(),
          lastLogin:
              ((doc.data()!["lastLogin"] as Timestamp?) ?? Timestamp.now())
                  .toDate(),
          links: doc.data()!["links"] as Map ?? {},
          premium: doc.data()!["premium"] as bool,
          loggedIn: true,
          profilePhoto:
              (doc.data()!["profilePhoto"] ?? user.photoURL).toString(),
        );
        FirebaseFirestore.instance
            .collection(USER_NEW_COLLECTION)
            .doc(globals.prismUser.id)
            .set({
          'bio': globals.prismUser.bio,
          'username': globals.prismUser.username,
          'email': globals.prismUser.email,
          'id': globals.prismUser.id,
          'createdAt': globals.prismUser.createdAt,
          'premium': globals.prismUser.premium,
          'lastLogin': DateTime.now(),
          'links': globals.prismUser.links,
          'followers': globals.prismUser.followers,
          'following': globals.prismUser.following,
          'profilePhoto': globals.prismUser.profilePhoto,
        });
        print("USERDATA CASE2 ${globals.prismUser.toJson()}");
      }
      // User exists in new database. Simply sign him in.
      else if (usersData[0] == null && usersData[1] != null) {
        final doc = usersData[1]!;
        globals.prismUser = PrismUsers(
          bio: (doc.data()!["bio"] ?? "").toString(),
          createdAt: doc.data()!["createdAt"].toString(),
          email: doc.data()!["email"].toString(),
          username: (doc.data()!["username"] ?? user.displayName).toString(),
          followers: doc.data()!["followers"] as List ?? [],
          following: doc.data()!["following"] as List ?? [],
          id: doc.data()!["id"].toString(),
          lastLogin:
              ((doc.data()!["lastLogin"] as Timestamp?) ?? Timestamp.now())
                  .toDate(),
          links: doc.data()!["links"] as Map ?? {},
          premium: doc.data()!["premium"] as bool,
          loggedIn: true,
          profilePhoto:
              (doc.data()!["profilePhoto"] ?? user.photoURL).toString(),
        );
        FirebaseFirestore.instance
            .collection(USER_NEW_COLLECTION)
            .doc(globals.prismUser.id)
            .update({
          'bio': globals.prismUser.bio,
          'username': globals.prismUser.username,
          'lastLogin': DateTime.now(),
          'links': globals.prismUser.links,
          'profilePhoto': globals.prismUser.profilePhoto,
        });
        print("USERDATA CASE3 ${globals.prismUser.toJson()}");
      }
      // User exists in none. Create new data in new db and sign him in.
      else {
        globals.prismUser = PrismUsers(
          bio: "",
          createdAt: DateTime.now().toIso8601String(),
          email: user.email!,
          username: user.displayName!,
          followers: [],
          following: [],
          id: user.uid,
          lastLogin: DateTime.now(),
          links: {},
          premium: false,
          loggedIn: true,
          profilePhoto: user.photoURL!,
        );
        FirebaseFirestore.instance
            .collection(USER_NEW_COLLECTION)
            .doc(globals.prismUser.id)
            .set({
          'bio': globals.prismUser.bio,
          'username': globals.prismUser.username,
          'email': globals.prismUser.email,
          'id': globals.prismUser.id,
          'createdAt': globals.prismUser.createdAt,
          'premium': globals.prismUser.premium,
          'lastLogin': DateTime.now(),
          'links': globals.prismUser.links,
          'followers': globals.prismUser.followers,
          'following': globals.prismUser.following,
          'profilePhoto': globals.prismUser.profilePhoto,
        });
        print("USERDATA CASE4 ${globals.prismUser.toJson()}");
      }

      await prefs.put('prismUser', globals.prismUser);
      isLoading = false;
    }
    home.f.subscribeToTopic(user.email!.split("@")[0]);
    assert(!user.isAnonymous);
    assert(await user.getIdToken() != null);
    final User? currentUser = _auth.currentUser;
    assert(user.uid == currentUser!.uid);
    analytics.logLogin();
    await checkPremium();
    return 'signInWithGoogle succeeded: $user';
  }

  Future<bool> signOutGoogle() async {
    await googleSignIn.signOut();
    globals.prismUser = PrismUsers.initial(
      createdAt: DateTime.now().toIso8601String(),
      lastLogin: DateTime.now(),
      links: {},
      followers: [],
      following: [],
    );
    Hive.openBox('prefs').then((value) {
      value.put('prismUser', globals.prismUser);
    });
    await Purchases.reset();
    debugPrint("User Sign Out");
    return true;
  }

  Future<bool> isSignedIn() async {
    await googleSignIn.isSignedIn().then((value) {
      debugPrint(value.toString());
      return value;
    });
    return false;
  }

  Future<DocumentSnapshot?> getUserOLD(User? user) async {
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection(USER_OLD_COLLECTION)
        .where('id', isEqualTo: user!.uid)
        .get();
    final List<DocumentSnapshot> documents = result.docs;
    return documents.isNotEmpty ? documents.first : null;
  }

  Future<DocumentSnapshot?> getUserNEW(User? user) async {
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection(USER_NEW_COLLECTION)
        .where('id', isEqualTo: user!.uid)
        .get();
    final List<DocumentSnapshot> documents = result.docs;
    return documents.isNotEmpty ? documents.first : null;
  }

  Future<List<DocumentSnapshot?>> getUsersData(User? user) async {
    late final List<DocumentSnapshot?> output;
    await Future.wait([getUserOLD(user), getUserNEW(user)])
        .then((value) => output = value);
    return output;
  }
}
