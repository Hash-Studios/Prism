import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:Prism/ui/feed.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key key, this.title}) : super(key: key);
  final String title;
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  SharedPreferences prefs;

  bool isLoading = false;
  bool isLoggedIn = false;
  FirebaseUser currentUser;
  GoogleSignInAccount googleUser;
  GoogleSignInAuthentication googleAuth;

  @override
  void initState() {
    super.initState();
  }

  Future<Null> handleSignIn() async {
    prefs = await SharedPreferences.getInstance();

    this.setState(() {
      isLoading = true;
    });

    try {
      googleUser = await googleSignIn.signIn();
      googleAuth = await googleUser.authentication;
    } catch (e) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => LoginScreen()));
    }
    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    FirebaseUser firebaseUser =
        (await firebaseAuth.signInWithCredential(credential)).user;
    if (firebaseUser != null) {
      final QuerySnapshot result = await Firestore.instance
          .collection('users')
          .where('id', isEqualTo: firebaseUser.uid)
          .getDocuments();
      final List<DocumentSnapshot> documents = result.documents;
      if (documents.length == 0) {
        Firestore.instance
            .collection('users')
            .document(firebaseUser.uid)
            .setData({
          'name': firebaseUser.displayName,
          'email': firebaseUser.email,
          'id': firebaseUser.uid,
        });
        currentUser = firebaseUser;
        await prefs.setString('id', currentUser.uid);
        await prefs.setString('name', currentUser.displayName);
        await prefs.setString('email', currentUser.email);
        await prefs.setString('logged', isLoggedIn.toString());
      } else {
        await prefs.setString('id', documents[0]['id']);
        await prefs.setString('name', documents[0]['name']);
        await prefs.setString('email', documents[0]['email']);
        await prefs.setString('logged', isLoggedIn.toString());
      }
      Fluttertoast.showToast(msg: "Sign in success");
      this.setState(() {
        isLoading = false;
      });
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => Feed(currentUserId: firebaseUser.uid)));
    } else {
      Fluttertoast.showToast(msg: "Sign in fail");
      this.setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          Container(
            child: Center(
              child: Container(
                child: Image.asset(
                  "assets/images/icon.png",
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ),
          new Container(
            margin: EdgeInsets.only(left: 60.0, right: 60),
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(height: 200, width: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new FlatButton(
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        color: Colors.white,
                        onPressed: () => handleSignIn(),
                        child: Image(
                            width: 220,
                            image: AssetImage(
                                "assets/images/btn_google_signin.png"))),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            child: isLoading
                ? Container(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                    color: Colors.white.withOpacity(0.8),
                  )
                : Container(),
          ),
        ],
      ),
    );
  }
}
