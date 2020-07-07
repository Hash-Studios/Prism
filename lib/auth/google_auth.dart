import 'package:Prism/analytics/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn();

  String name;
  String email;
  String imageUrl;
  String errorMsg = "";
  SharedPreferences prefs;
  bool isLoggedIn = false;
  bool isLoading = false;

  Future<String> signInWithGoogle() async {
    // try {
    isLoading = true;
    prefs = await SharedPreferences.getInstance();
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
        await prefs.setString('id', user.uid);
        await prefs.setString('name', user.displayName);
        await prefs.setString('email', user.email);
        await prefs.setString('logged', "true");
        await prefs.setBool('premium', false);
      } else {
        await prefs.setString('id', documents[0]['id']);
        await prefs.setString('name', documents[0]['name']);
        await prefs.setString('email', documents[0]['email']);
        await prefs.setString('logged', "true");
        await prefs.setBool('premium', documents[0]['premium'] ?? false);
      }
      isLoading = false;
    }
    SharedPreferences.getInstance().then((value) {
      value.setString('googlename', user.displayName);
      value.setString('googleemail', user.email);
      value.setString('googleimage', user.photoUrl);
    });
    assert(!user.isAnonymous);
    assert(await user.getIdToken() != null);
    final FirebaseUser currentUser = await _auth.currentUser();
    assert(user.uid == currentUser.uid);
    analytics.logLogin();
    return 'signInWithGoogle succeeded: $user';
  }

  void signOutGoogle() async {
    await googleSignIn.signOut();
    SharedPreferences.getInstance().then((value) {
      value.setString('googlename', "");
      value.setString('googleemail', "");
      value.setString('googleimage', "");
      value.setString('id', "");
      value.setString('name', "");
      value.setString('email', "");
      value.setString('logged', "false");
      value.setBool('premium', false);
    });
    print("User Sign Out");
  }

  Future<bool> isSignedIn() async {
    googleSignIn.isSignedIn().then((value) {
      print(value);
      return value;
    });
  }
}
