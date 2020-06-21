import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:Prism/ui/feed.dart';
import 'package:Prism/screens/login.dart';

class LoginScreen3 extends StatefulWidget {
  @override
  _LoginScreen3State createState() => new _LoginScreen3State();
}

class _LoginScreen3State extends State<LoginScreen3> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  SharedPreferences prefs;
  bool isLoading = false;
  bool isLoggedIn = false;
  GoogleSignInAccount googleUser;
  GoogleSignInAuthentication googleAuth;

  @override
  void initState() {
    super.initState();
    isSignedIn();
  }

  void isSignedIn() async {
    this.setState(() {
      isLoading = true;
    });

    prefs = await SharedPreferences.getInstance();

    isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Feed(currentUserId: prefs.getString('id'))),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }

    this.setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
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
        ));
  }
}
