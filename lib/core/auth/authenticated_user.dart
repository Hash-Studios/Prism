import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:firebase_auth/firebase_auth.dart';

/// A cached Prism profile alone does not authorize access to its private data.
String? get authenticatedUserId {
  final profile = app_state.prismUser;
  if (!profile.loggedIn || profile.id.trim().isEmpty || !FirebaseInit.hasDefaultApp) return null;
  final User? user = FirebaseAuth.instance.currentUser;
  return user != null && !user.isAnonymous && user.uid == profile.id ? user.uid : null;
}

Future<String?> waitForAuthenticatedUserId() async {
  final profile = app_state.prismUser;
  final String userId = profile.id;
  if (!profile.loggedIn || userId.trim().isEmpty) return null;
  if (!await FirebaseInit.defaultAppReady()) return null;
  final User? user = await FirebaseAuth.instance.authStateChanges().first.timeout(
    const Duration(seconds: 3),
    onTimeout: () => null,
  );
  return user?.uid == userId && authenticatedUserId == userId ? userId : null;
}
