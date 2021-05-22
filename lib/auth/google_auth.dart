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
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('id', isEqualTo: user.uid)
          .get();
      final List<DocumentSnapshot> documents = result.docs;
      if (documents.isEmpty) {
        globals.prismUser = PrismUsers.withSave(
          username: user.displayName!,
          email: user.email!,
          id: user.uid,
          createdAt: DateTime.now().toIso8601String(),
          premium: false,
          lastLogin: DateTime.now(),
          links: {},
          followers: [],
          following: [],
          profilePhoto: user.photoURL!,
          bio: "",
          loggedIn: true,
        );
      } else {
        globals.prismUser = PrismUsers.fromDocumentSnapshot(documents[0], user);
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
}
