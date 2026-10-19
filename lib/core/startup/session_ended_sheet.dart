import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// Tells the user the session ended and offers the usual sign-in sheet. [onSignedIn] runs after a successful sign-in.
Future<void> showSessionEndedSheet(BuildContext context, {required VoidCallback onSignedIn}) async {
  StartupModalSlot.shown.value = true;
  final bool signIn = await showStartupChoiceSheet(
    context,
    message: context.l10n.wallpaperSessionEnded,
    confirmLabel: context.l10n.wallpaperSignIn,
    dismissLabel: context.l10n.coreNotNow,
  );
  if (signIn && context.mounted) googleSignInPopUp(context, onSignedIn);
}
