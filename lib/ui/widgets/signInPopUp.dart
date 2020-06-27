import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:Prism/globals.dart' as globals;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;

import 'Animation/AnimationProgress.dart';

void googleSignInPopUp(BuildContext context, Function func) {
  Dialog loaderDialog = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .7,
      height: MediaQuery.of(context).size.height * .3,
      child: Center(
        child: AnimationProgress(),
      ),
    ),
  );
  Dialog signinPopUp = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).primaryColor),
        width: MediaQuery.of(context).size.width * .78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 150,
              width: MediaQuery.of(context).size.width * .78,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20)),
                  color: Theme.of(context).hintColor),
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
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 20,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.heart,
                  size: 22,
                  color: Color(0xFFE57697),
                ),
                SizedBox(
                  width: 20,
                ),
                Text(
                  "The ability to favourite wallpapers.",
                  style: Theme.of(context)
                      .textTheme
                      .headline6
                      .copyWith(color: Theme.of(context).accentColor),
                ),
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.download,
                  size: 22,
                  color: Color(0xFFE57697),
                ),
                SizedBox(
                  width: 20,
                ),
                Text(
                  "The ability to download wallpapers.",
                  style: Theme.of(context)
                      .textTheme
                      .headline6
                      .copyWith(color: Theme.of(context).accentColor),
                ),
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.cloud,
                  size: 22,
                  color: Color(0xFFE57697),
                ),
                SizedBox(
                  width: 20,
                ),
                Text(
                  "The ability to cloud sync data.",
                  style: Theme.of(context)
                      .textTheme
                      .headline6
                      .copyWith(color: Theme.of(context).accentColor),
                ),
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
                showDialog(
                    barrierDismissible: false,
                    context: context,
                    builder: (BuildContext context) => loaderDialog);
                globals.gAuth.signInWithGoogle().then((value) {
                  toasts.successLog();
                  main.prefs.setBool("isLoggedin", true);
                  Navigator.pop(context);
                  FirebaseMessaging f = new FirebaseMessaging();
                  f.getToken().then((value) {
                  Firestore.instance.collection('tokens').document(value.toString()).updateData({"devtoken":value.toString()}).then((value) {
                      func();
                    });
                  }).catchError((onError){
                    Navigator.pop(context);
                    toasts.error(onError);
                  });
                }).catchError((e) {
                  print(e);
                  //For Debug Mode
//                  FirebaseMessaging f = new FirebaseMessaging();
//                  f.getToken().then((value) {
//                    print(value);
//                    Firestore.instance.collection('tokens').document(main.prefs.getString('id')).setData({"devtoken":value.toString()}).then((value) {
//                    });
//                  }).catchError((onError){
//                    Navigator.pop(context);
//                    toasts.error(onError);
//                  });
                }).catchError((e) {
                  print(e);
                  Navigator.pop(context);
                  main.prefs.setBool("isLoggedin", false);
                  toasts.error("Something went wrong, please try again!");
                });
              },
              child: Text(
                'SIGN IN WITH GOOGLE',
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(
              height: 15,
            ),
          ],
        ),
      ),
    ),
  );
  showDialog(context: context, builder: (BuildContext context) => signinPopUp);
}
