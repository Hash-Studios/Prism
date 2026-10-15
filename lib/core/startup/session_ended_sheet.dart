import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:flutter/widgets.dart';

/// Tells the user the session ended and offers the usual sign-in sheet. [onSignedIn] runs after a successful sign-in.
Future<void> showSessionEndedSheet(BuildContext context, {required VoidCallback onSignedIn}) async {
  StartupModalSlot.shown.value = true;
  final bool signIn = await showStartupChoiceSheet(
    context,
    message: 'Your session ended. Sign in again.',
    confirmLabel: 'Sign in',
  );
  if (signIn && context.mounted) googleSignInPopUp(context, onSignedIn);
}
