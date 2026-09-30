import 'dart:io';
import 'dart:math';

import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/widgets/accent_color.dart';
import 'package:Prism/core/widgets/popup/popup_header.dart';
import 'package:Prism/logger/logger.dart';
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
      child: const Center(child: CircularProgressIndicator()),
    ),
  );

  void runSignIn(Future<SignInOutcome> Function() signIn) {
    navigator.pop();
    loaderVisible = true;
    showDialog(barrierDismissible: false, context: navigator.context, builder: (BuildContext context) => loaderDialog);
    signIn()
        .then((outcome) {
          if (!navigator.mounted) {
            return;
          }
          closeLoaderIfVisible();
          if (outcome == SignInOutcome.cancelled) {
            app_state.prismUser.loggedIn = false;
            app_state.persistPrismUser();
            toasts.codeSend('Sign in cancelled.');
            return;
          }
          toasts.codeSend('Login Successful!');
          app_state.prismUser.loggedIn = true;
          app_state.persistPrismUser();
          func();
        })
        .catchError((Object e) {
          if (!navigator.mounted) {
            return;
          }
          logger.d(e.toString());
          closeLoaderIfVisible();
          app_state.prismUser.loggedIn = false;
          app_state.persistPrismUser();
          toasts.error('Something went wrong, please try again!');
        });
  }

  // Capped so the dialog does not stretch across a tablet.
  final double dialogWidth = min(MediaQuery.sizeOf(context).width * .78, 480);
  final List<(IconData, String)> benefits = <(IconData, String)>[
    (JamIcons.heart, 'The ability to favourite wallpapers.'),
    (JamIcons.upload, 'The ability to upload wallpapers.'),
    if (!Platform.isIOS) (JamIcons.instant_picture, 'The ability to upload setups.'),
    if (!Platform.isIOS) (JamIcons.coin, 'The ability to view premium content.'),
    (JamIcons.cloud, 'The ability to cloud sync data.'),
  ];
  final AlertDialog signinPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).primaryColor),
        width: dialogWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PopupHeader(
              width: dialogWidth,
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
            for (int i = 0; i < benefits.length; i++) ...[
              SizedBox(height: i == 0 ? 20 : 10),
              _BenefitRow(icon: benefits[i].$1, text: benefits[i].$2, width: dialogWidth),
            ],
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
          runSignIn(globalGoogleAuth.signInWithGoogle);
        },
        child: const Text('GOOGLE', style: TextStyle(fontSize: 16.0, color: Colors.white)),
      ),
      if (Platform.isIOS || Platform.isMacOS)
        MaterialButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          color: Colors.white,
          onPressed: () {
            runSignIn(globalAppleAuth.signInWithApple);
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apple, color: Colors.black, size: 18),
              SizedBox(width: 6),
              Text('Sign in with Apple', style: TextStyle(fontSize: 16.0, color: Colors.black)),
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

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text, required this.width});

  final IconData icon;
  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 20),
        Icon(icon, size: 22, color: accentColor(context)),
        const SizedBox(width: 20),
        SizedBox(
          width: width - 70,
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
          ),
        ),
      ],
    );
  }
}
