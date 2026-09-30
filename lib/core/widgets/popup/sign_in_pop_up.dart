import 'dart:io';

import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the sign-in sheet. [func] runs after a successful sign-in.
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

  void runSignIn(Future<SignInOutcome> Function() signIn) {
    navigator.pop();
    loaderVisible = true;
    showPrismSheet<void>(
      context: navigator.context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: PrismSpace.xxl),
            child: GlintState(kind: GlintStateKind.loading, title: 'Signing in'),
          ),
        ),
      ),
    );
    signIn()
        .then((outcome) {
          if (!navigator.mounted) {
            return;
          }
          closeLoaderIfVisible();
          if (outcome == SignInOutcome.cancelled) {
            toasts.error('Sign in cancelled.');
            return;
          }
          toasts.success('Signed in.');
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
          toasts.error('Something went wrong. Try again.');
        });
  }

  showPrismSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => PrismSheetBody(
      mood: GlintMood.happy,
      centered: true,
      title: 'Sign in to Prism',
      message: 'Keep your favourites, uploads and coins on every device.',
      actions: <Widget>[
        if (Platform.isIOS || Platform.isMacOS)
          _AppleButton(onPressed: () => runSignIn(globalAppleAuth.signInWithApple)),
        PrismButton(
          label: 'Continue with Google',
          icon: JamIcons.google,
          variant: PrismButtonVariant.tonal,
          expand: true,
          onPressed: () => runSignIn(globalGoogleAuth.signInWithGoogle),
        ),
        PrismButton(
          label: 'Not now',
          variant: PrismButtonVariant.ghost,
          expand: true,
          onPressed: () => navigator.pop(),
        ),
      ],
    ),
  );
}

/// "Continue with Apple" in Apple's own colours: black on light themes, white on dark themes.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = dark ? Colors.white : Colors.black;
    final Color fg = dark ? Colors.black : Colors.white;
    return PressScale(
      child: FilledButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        icon: const Icon(Icons.apple, size: 22),
        label: const Text('Continue with Apple'),
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          minimumSize: const Size(double.infinity, 52),
          textStyle: PrismTextStyles.button,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
    );
  }
}
