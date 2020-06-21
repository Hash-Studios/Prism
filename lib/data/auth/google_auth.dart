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

  Future<String> signInWithGoogle() async {
    // try {
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
    SharedPreferences.getInstance().then((value) {
      value.setString('googlename', user.displayName);
      value.setString('googleemail', user.email);
      value.setString('googleimage', user.photoUrl);
    });
    assert(!user.isAnonymous);
    assert(await user.getIdToken() != null);
    final FirebaseUser currentUser = await _auth.currentUser();
    assert(user.uid == currentUser.uid);
    return 'signInWithGoogle succeeded: $user';
  }

  void signOutGoogle() async {
    await googleSignIn.signOut();
    SharedPreferences.getInstance().then((value) {
      value.setString('googlename', "");
      value.setString('googleemail', "");
      value.setString('googleimage', "");
    });
    print("User Sign Out");
  }
}