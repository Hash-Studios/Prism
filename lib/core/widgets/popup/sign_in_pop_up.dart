import 'dart:io';

import 'package:Prism/auth/apple_auth.dart';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

void googleSignInPopUp(BuildContext context, VoidCallback func) {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  bool loaderVisible = false;
  final AppleAuth appleAuth = AppleAuth();

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
      child: const Center(child: CircularProgressIndicator()),
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
                color: Theme.of(context).hintColor,
              ),
              child: Icon(JamIcons.log_in, size: 54, color: Theme.of(context).colorScheme.secondary),
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
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(width: 20),
                Icon(
                  JamIcons.heart,
                  size: 22,
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to favourite wallpapers.",
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 20),
                Icon(
                  JamIcons.upload,
                  size: 22,
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to upload wallpapers.",
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 20),
                Icon(
                  JamIcons.instant_picture,
                  size: 22,
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to upload setups.",
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 20),
                Icon(
                  JamIcons.coin,
                  size: 22,
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to view premium content.",
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 20),
                Icon(
                  JamIcons.cloud,
                  size: 22,
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to cloud sync data.",
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
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
        child: Text('CLOSE', style: TextStyle(fontSize: 16.0, color: Theme.of(context).colorScheme.secondary)),
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
          app_state.gAuth
              .signInWithGoogle()
              .then((value) {
                if (!navigator.mounted) {
                  return;
                }
                closeLoaderIfVisible();
                if (value == GoogleAuth.signInCancelledResult) {
                  app_state.prismUser.loggedIn = false;
                  app_state.persistPrismUser();
                  toasts.codeSend("Sign in cancelled.");
                  return;
                }
                toasts.codeSend("Login Successful!");
                app_state.prismUser.loggedIn = true;
                app_state.persistPrismUser();
                func();
              })
              .catchError((e) {
                if (!navigator.mounted) {
                  return;
                }
                logger.d(e.toString());
                closeLoaderIfVisible();
                app_state.prismUser.loggedIn = false;
                app_state.persistPrismUser();
                toasts.error("Something went wrong, please try again!");
              });
        },
        child: const Text('GOOGLE', style: TextStyle(fontSize: 16.0, color: Colors.white)),
      ),
      if (Platform.isIOS || Platform.isMacOS)
        MaterialButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          color: Colors.black,
          onPressed: () {
            navigator.pop();
            loaderVisible = true;
            showDialog(
              barrierDismissible: false,
              context: navigator.context,
              builder: (BuildContext context) => loaderDialog,
            );
            appleAuth
                .signInWithApple()
                .then((value) {
                  if (!navigator.mounted) {
                    return;
                  }
                  closeLoaderIfVisible();
                  if (value == AppleAuth.signInCancelledResult) {
                    app_state.prismUser.loggedIn = false;
                    app_state.persistPrismUser();
                    toasts.codeSend("Sign in cancelled.");
                    return;
                  }
                  toasts.codeSend("Login Successful!");
                  app_state.prismUser.loggedIn = true;
                  app_state.persistPrismUser();
                  func();
                })
                .catchError((e) {
                  if (!navigator.mounted) {
                    return;
                  }
                  logger.d(e.toString());
                  closeLoaderIfVisible();
                  app_state.prismUser.loggedIn = false;
                  app_state.persistPrismUser();
                  toasts.error("Something went wrong, please try again!");
                });
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apple, color: Colors.white, size: 18),
              SizedBox(width: 4),
              Text('APPLE', style: TextStyle(fontSize: 16.0, color: Colors.white)),
            ],
          ),
        ),
    ],
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
    backgroundColor: Theme.of(context).primaryColor,
    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
  );
  showModal(context: context, builder: (BuildContext context) => signinPopUp);
}
