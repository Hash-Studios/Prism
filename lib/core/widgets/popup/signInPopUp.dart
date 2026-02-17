import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

void googleSignInPopUp(BuildContext context, VoidCallback func) {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  bool loaderVisible = false;

  void closeLoaderIfVisible() {
    if (!loaderVisible || !navigator.mounted) {
      return;
    }
    navigator.pop();
    loaderVisible = false;
  }

  final Dialog loaderDialog = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).primaryColor),
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).primaryColor),
        width: MediaQuery.of(context).size.width * .78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 150,
              width: MediaQuery.of(context).size.width * .78,
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                  color: Theme.of(context).hintColor),
              child: Icon(
                JamIcons.log_in,
                size: 54,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                  child: Text(
                    'SIGNING IN UNLOCKS:',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16, color: Theme.of(context).colorScheme.secondary),
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
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).colorScheme.error,
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
                        .titleLarge!
                        .copyWith(color: Theme.of(context).colorScheme.secondary),
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
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).colorScheme.error,
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
                        .titleLarge!
                        .copyWith(color: Theme.of(context).colorScheme.secondary),
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
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).colorScheme.error,
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
                        .titleLarge!
                        .copyWith(color: Theme.of(context).colorScheme.secondary),
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
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).colorScheme.error,
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
                        .titleLarge!
                        .copyWith(color: Theme.of(context).colorScheme.secondary),
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
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).colorScheme.error,
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
                        .titleLarge!
                        .copyWith(color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      MaterialButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: Theme.of(context).primaryColor,
        onPressed: () {
          navigator.pop();
        },
        child: Text(
          'CLOSE',
          style: TextStyle(
            fontSize: 16.0,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
      MaterialButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: Theme.of(context).colorScheme.error,
        onPressed: () {
          navigator.pop();
          loaderVisible = true;
          showDialog(
            barrierDismissible: false,
            context: navigator.context,
            builder: (BuildContext context) => loaderDialog,
          );
          globals.gAuth.signInWithGoogle().then((value) {
            if (!navigator.mounted) {
              return;
            }
            closeLoaderIfVisible();
            if (value == GoogleAuth.signInCancelledResult) {
              globals.prismUser.loggedIn = false;
              main.prefs.put(main.userHiveKey, globals.prismUser);
              toasts.codeSend("Sign in cancelled.");
              return;
            }
            toasts.codeSend("Login Successful!");
            globals.prismUser.loggedIn = true;
            main.prefs.put(main.userHiveKey, globals.prismUser);
            func();
          }).catchError((e) {
            if (!navigator.mounted) {
              return;
            }
            logger.d(e.toString());
            closeLoaderIfVisible();
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
  showModal(context: context, builder: (BuildContext context) => signinPopUp);
}
