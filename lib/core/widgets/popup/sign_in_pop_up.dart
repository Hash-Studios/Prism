import 'dart:async';
import 'dart:io';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// Opens the sign-in sheet. [func] runs after a successful sign-in. Completes with true after [func] ran, and with
/// false when the user leaves the sheet or sign-in does not finish.
Future<bool> googleSignInPopUp(BuildContext context, VoidCallback func) {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  final AppLocalizations l10n = context.l10n;
  final Completer<bool> signedIn = Completer<bool>();
  bool loaderVisible = false;
  bool started = false;

  void finish(bool value) {
    if (!signedIn.isCompleted) signedIn.complete(value);
  }

  void closeLoaderIfVisible() {
    if (!loaderVisible || !navigator.mounted) {
      return;
    }
    navigator.pop();
    loaderVisible = false;
  }

  void runSignIn(Future<SignInOutcome> Function() signIn, {String Function(Object)? errorMessage}) {
    started = true;
    navigator.pop();
    loaderVisible = true;
    showPrismSheet<void>(
      navigator.context,
      useRootNavigator: true,
      detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
      barrierDismissible: false,
      swipeDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: PrismSheetBody(
          showHandle: false,
          showCloseButton: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxl),
            child: GlintState(kind: GlintStateKind.loading, title: l10n.coreSigningIn),
          ),
        ),
      ),
    );
    signIn()
        .then((outcome) {
          if (!navigator.mounted) {
            finish(false);
            return;
          }
          closeLoaderIfVisible();
          if (outcome == SignInOutcome.cancelled) {
            finish(false);
            return;
          }
          PrismHaptics.success();
          app_state.prismUser.loggedIn = true;
          app_state.persistPrismUser();
          func();
          finish(true);
        })
        .catchError((Object e) {
          finish(false);
          if (!navigator.mounted) {
            return;
          }
          logger.d(e.toString());
          closeLoaderIfVisible();
          toasts.error(errorMessage?.call(e) ?? l10n.coreSomethingWentWrong);
        });
  }

  showPrismSheet<void>(
    context,
    useRootNavigator: true,
    builder: (_) => PrismSheetBody(
      mood: GlintMood.happy,
      centered: true,
      title: l10n.coreSignInPopupTitle,
      message: l10n.coreSignInPopupBody,
      actions: <Widget>[
        if (Platform.isIOS || Platform.isMacOS)
          _AppleButton(l10n: l10n, onPressed: () => runSignIn(globalAppleAuth.signInWithApple)),
        PrismButton(
          label: l10n.coreContinueWithGoogle,
          icon: JamIcons.google,
          variant: PrismButtonVariant.tonal,
          expand: true,
          onPressed: () => runSignIn(
            globalGoogleAuth.signInWithGoogle,
            errorMessage: (error) => googleSignInErrorMessage(error, l10n),
          ),
        ),
        PrismButton(
          label: l10n.coreCancelSignIn,
          variant: PrismButtonVariant.ghost,
          expand: true,
          onPressed: () => navigator.pop(),
        ),
      ],
    ),
  ).then((_) {
    if (!started) finish(false);
  });
  return signedIn.future;
}

/// "Continue with Apple" in Apple's own colours: black on light themes, white on dark themes.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.l10n, required this.onPressed});

  final AppLocalizations l10n;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = dark ? Colors.white : Colors.black;
    final Color fg = dark ? Colors.black : Colors.white;
    return PressScale(
      child: FilledButton.icon(
        onPressed: () {
          PrismHaptics.selection();
          onPressed();
        },
        icon: const Icon(Icons.apple, size: 22),
        label: Text(l10n.coreContinueWithApple),
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
