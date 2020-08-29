import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/payments/upgrade.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class GoogleAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn();

  String name;
  String email;
  String imageUrl;
  String errorMsg = "";
  Box prefs;
  bool isLoggedIn = false;
  bool isLoading = false;

  Future<String> signInWithGoogle() async {
    // try {
    isLoading = true;
    prefs = await Hive.openBox('prefs');
    final GoogleSignInAccount googleSignInAccount = await googleSignIn.signIn();
    final GoogleSignInAuthentication googleSignInAuthentication =
        await googleSignInAccount.authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleSignInAuthentication.accessToken,
      idToken: googleSignInAuthentication.idToken,
    );

    final AuthResult authResult = await _auth.signInWithCredential(credential);
    final FirebaseUser user = authResult.user;
    assert(user.email != null);
    assert(user.displayName != null);
    assert(user.photoUrl != null);
    name = user.displayName;
    email = user.email;
    if (user != null) {
      final QuerySnapshot result = await Firestore.instance
          .collection('users')
          .where('id', isEqualTo: user.uid)
          .getDocuments();
      final List<DocumentSnapshot> documents = result.documents;
      if (documents.length == 0) {
        Firestore.instance.collection('users').document(user.uid).setData({
          'name': user.displayName,
          'email': user.email,
          'id': user.uid,
          'createdAt': DateTime.now().toIso8601String(),
          'premium': false,
        });
        await prefs.put('id', user.uid);
        await prefs.put('name', user.displayName);
        await prefs.put('email', user.email);
        await prefs.put('logged', "true");
        await prefs.put('premium', false);
      } else {
        await prefs.put('id', documents[0]['id']);
        await prefs.put('name', documents[0]['name']);
        await prefs.put('email', documents[0]['email']);
        await prefs.put('logged', "true");
        await prefs.put('premium', documents[0]['premium'] ?? false);
      }
      isLoading = false;
    }
    Hive.openBox('prefs').then((value) {
      value.put('googlename', user.displayName);
      value.put('googleemail', user.email);
      value.put('googleimage', user.photoUrl);
    });
    assert(!user.isAnonymous);
    assert(await user.getIdToken() != null);
    final FirebaseUser currentUser = await _auth.currentUser();
    assert(user.uid == currentUser.uid);
    analytics.logLogin();
    await checkPremium();
    return 'signInWithGoogle succeeded: $user';
  }

  void signOutGoogle() async {
    await googleSignIn.signOut();
    Hive.openBox('prefs').then((value) {
      value.put('googlename', "");
      value.put('googleemail', "");
      value.put('googleimage', "");
      value.put('id', "");
      value.put('name', "");
      value.put('email', "");
      value.put('logged', "false");
      value.put('premium', false);
    });
    await Purchases.reset();
    print("User Sign Out");
  }

  Future<bool> isSignedIn() async {
    googleSignIn.isSignedIn().then((value) {
      print(value);
      return value;
    });
  }
}
