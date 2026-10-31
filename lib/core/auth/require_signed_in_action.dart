import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:flutter/material.dart';

@visibleForTesting
Future<bool> Function(BuildContext context) signedInActionSignIn = (context) => googleSignInPopUp(context, () {});

Future<bool> requireSignedInAction(BuildContext context) async {
  if (!context.mounted) return false;
  if (app_state.prismUser.loggedIn) return true;
  final bool signedIn = await signedInActionSignIn(context);
  return signedIn && context.mounted && app_state.prismUser.loggedIn;
}
