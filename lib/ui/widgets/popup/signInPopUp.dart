import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:animations/animations.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/logger/logger.dart';

void googleSignInPopUp(BuildContext context, Function func) {
  final Dialog loaderDialog = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .7,
      height: MediaQuery.of(context).size.height * .3,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    ),
  );
  final AlertDialog signinPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
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
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10)),
                  color: Theme.of(context).hintColor),
              child: const FlareActor(
                "assets/animations/Signin.flr",
                animation: "signin",
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
            const SizedBox(
              height: 20,
            ),
            Row(
              children: [
                const SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.heart,
                  size: 22,
                  color: Theme.of(context).errorColor == Colors.black
                      ? Colors.white
                      : Theme.of(context).errorColor,
                ),
                const SizedBox(
                  width: 20,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to favourite wallpapers.",
                    style: Theme.of(context)
                        .textTheme
                        .headline6!
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                const SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.upload,
                  size: 22,
                  color: Theme.of(context).errorColor == Colors.black
                      ? Colors.white
                      : Theme.of(context).errorColor,
                ),
                const SizedBox(
                  width: 20,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to upload wallpapers.",
                    style: Theme.of(context)
                        .textTheme
                        .headline6!
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                const SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.instant_picture,
                  size: 22,
                  color: Theme.of(context).errorColor == Colors.black
                      ? Colors.white
                      : Theme.of(context).errorColor,
                ),
                const SizedBox(
                  width: 20,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to upload setups.",
                    style: Theme.of(context)
                        .textTheme
                        .headline6!
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                const SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.coin,
                  size: 22,
                  color: Theme.of(context).errorColor == Colors.black
                      ? Colors.white
                      : Theme.of(context).errorColor,
                ),
                const SizedBox(
                  width: 20,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to view premium content.",
                    style: Theme.of(context)
                        .textTheme
                        .headline6!
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                const SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.cloud,
                  size: 22,
                  color: Theme.of(context).errorColor == Colors.black
                      ? Colors.white
                      : Theme.of(context).errorColor,
                ),
                const SizedBox(
                  width: 20,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to cloud sync data.",
                    style: Theme.of(context)
                        .textTheme
                        .headline6!
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      FlatButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: Theme.of(context).primaryColor,
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: Text(
          'CLOSE',
          style: TextStyle(
            fontSize: 16.0,
            color: Theme.of(context).accentColor,
          ),
        ),
      ),
      FlatButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: Theme.of(context).errorColor,
        onPressed: () {
          Navigator.of(context).pop();
          showDialog(
              barrierDismissible: false,
              context: context,
              builder: (BuildContext context) => loaderDialog);
          globals.gAuth.signInWithGoogle().then((value) {
            toasts.codeSend("Login Successful!");
            globals.prismUser.loggedIn = true;
            main.prefs.put(main.userHiveKey, globals.prismUser);
            Navigator.pop(context);
            func();
          }).catchError((e) {
            logger.d(e.toString());
            Navigator.pop(context);
            globals.prismUser.loggedIn = false;
            main.prefs.put(main.userHiveKey, globals.prismUser);
            toasts.error("Something went wrong, please try again!");
          });
        },
        child: const Text(
          'SIGN IN',
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.white,
          ),
        ),
      ),
    ],
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
    backgroundColor: Theme.of(context).primaryColor,
    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
  );
  showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (BuildContext context) => signinPopUp);
}
