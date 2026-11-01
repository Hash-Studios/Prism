import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/account/local_account_data_cleaner.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/session_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

typedef _Step = Future<void> Function();

class DeleteAccountService {
  DeleteAccountService({
    _Step? reauthenticate,
    _Step? deleteOnServer,
    Future<bool> Function()? signOut,
    Future<void> Function(String userId)? clearLocalData,
  }) : _reauthenticate = reauthenticate ?? _reauthenticateWithProvider,
       _deleteOnServer = deleteOnServer ?? _callDeleteAccount,
       _signOut = signOut ?? (() => globalGoogleAuth.signOutGoogle()),
       _clearLocalData = clearLocalData ?? _clearLocalAccountData;

  static DeleteAccountService instance = DeleteAccountService();

  /// The server deletes in batches and can take up to 300 seconds.
  static const Duration serverTimeout = Duration(seconds: 300);

  final _Step _reauthenticate;
  final _Step _deleteOnServer;
  final Future<bool> Function() _signOut;
  final Future<void> Function(String userId) _clearLocalData;

  /// Performs a full account deletion:
  ///   1. Re-authenticates (required before the server will act on this account)
  ///   2. Calls the `deleteAccount` callable, which deletes all user data and the
  ///      Firebase Auth user server-side
  ///   3. Signs out of the Google SDK and clears local persistence
  Future<void> deleteAccount() async {
    final userId = app_state.prismUser.id;
    if (userId.isEmpty) throw StateError('No signed-in user to delete.');

    logger.i('[DeleteAccount] Starting deletion for userId=$userId', tag: 'DeleteAccount');

    // If the user cancels re-authentication this throws and we never reach the server.
    await _reauthenticate();
    await _deleteOnServer();

    // Sign out from Google SDK so silent re-auth doesn't recreate the account.
    await _signOut();
    await _clearLocalData(userId);

    logger.i('[DeleteAccount] Done', tag: 'DeleteAccount');
  }

  static Future<void> _reauthenticateWithProvider() async {
    final Set<String> providerIds = await signedInProviderIds();
    if (providerIds.contains('apple.com')) {
      await globalAppleAuth.reauthenticateCurrentUser();
    } else {
      await globalGoogleAuth.reauthenticateCurrentUser();
    }
  }

  /// Waits for Firebase startup first. A user restored late would otherwise read as no user, and an Apple user would
  /// get the Google reauthentication.
  @visibleForTesting
  static Future<Set<String>> signedInProviderIds({
    Future<bool> Function() firebaseReady = _firebaseReady,
    User? Function() currentUser = _currentFirebaseUser,
  }) async {
    if (!await firebaseReady()) throw const FirebaseUnavailableException();
    return currentUser()?.providerData.map((provider) => provider.providerId).toSet() ?? <String>{};
  }

  static Future<bool> _firebaseReady() async => FirebaseInit.hasDefaultApp || await FirebaseInit.waitUntilReady();

  static User? _currentFirebaseUser() => FirebaseAuth.instance.currentUser;

  static Future<void> _callDeleteAccount() async {
    await appFunctions
        .httpsCallable('deleteAccount', options: HttpsCallableOptions(timeout: serverTimeout))
        .call<dynamic>();
  }

  static Future<void> _clearLocalAccountData(String userId) async {
    await resetOnboardingLocalState(getIt<SettingsLocalDataSource>());
    await getIt<SessionLocalDataSource>().clearCurrentUser();
    await LocalAccountDataCleaner().clearForUser(userId);
  }
}
