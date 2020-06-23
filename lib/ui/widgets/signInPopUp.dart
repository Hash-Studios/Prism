import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:Prism/globals.dart' as globals;
import 'package:Prism/main.dart' as main;

void googleSignInPopUp(BuildContext context, Function func) {
  Dialog signinPopUp = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20), color: Colors.white10),
        width: 300.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 150,
              width: 300,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20)),
                  color: Colors.white12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Image.asset(
                  'assets/images/appIcon.png',
                  fit: BoxFit.scaleDown,
                ),
              ),
            ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                  child: Text(
                    'SIGNING IN UNLOCKS:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(JamIcons.heart_f),
                Text(
                  "The ability to favourite wallpapers.",
                  style: Theme.of(context).textTheme.headline6,
                )
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(JamIcons.download),
                Text(
                  "The ability to download wallpapers.",
                  style: Theme.of(context).textTheme.headline6,
                )
              ],
            ),
            SizedBox(
              height: 25,
            ),
            FlatButton(
              shape: StadiumBorder(),
              color: Color(0xFFE57697),
              onPressed: () {
                Navigator.of(context).pop();
                globals.gAuth.signInWithGoogle().whenComplete(() {
                  main.prefs.setBool("isLoggedin", true);
                  func();
                });
              },
              child: Text(
                'LOGIN',
                style: TextStyle(fontSize: 18.0),
              ),
            ),
            SizedBox(
              height: 10,
            ),
          ],
        ),
      ),
    ),
  );
  showDialog(context: context, builder: (BuildContext context) => signinPopUp);
}
