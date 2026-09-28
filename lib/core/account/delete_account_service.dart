import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteAccountService {
  DeleteAccountService._();

  static final DeleteAccountService instance = DeleteAccountService._();

  SettingsLocalDataSource get _settingsLocal => getIt<SettingsLocalDataSource>();

  /// Performs a full account deletion:
  ///   1. Re-authenticates (required before the server will act on this account)
  ///   2. Calls the `deleteAccount` callable, which deletes all user data and the
  ///      Firebase Auth user server-side
  ///   3. Signs out of the Google SDK and clears local persistence
  Future<void> deleteAccount() async {
    final userId = app_state.prismUser.id;
    final email = app_state.prismUser.email;

    logger.i('[DeleteAccount] Starting deletion for userId=$userId email=$email', tag: 'DeleteAccount');

    if (userId.isEmpty) throw Exception('No signed-in user to delete.');

    // 1. Re-authenticate. If the user cancels this throws and we never reach the server.
    final providerIds =
        FirebaseAuth.instance.currentUser?.providerData.map((provider) => provider.providerId).toSet() ?? {};
    if (providerIds.contains('apple.com')) {
      logger.i('[DeleteAccount] Step 1: Re-authenticating with Apple', tag: 'DeleteAccount');
      await globalAppleAuth.reauthenticateCurrentUser();
    } else {
      logger.i('[DeleteAccount] Step 1: Re-authenticating with Google', tag: 'DeleteAccount');
      await app_state.gAuth.reauthenticateCurrentUser();
    }

    // 2. Server deletes all user data and the Firebase Auth user record.
    logger.i('[DeleteAccount] Step 2: Calling deleteAccount callable', tag: 'DeleteAccount');
    await FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('deleteAccount', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
        .call<dynamic>();

    // 3. Sign out from Google SDK so silent re-auth doesn't recreate the account
    logger.i('[DeleteAccount] Step 3: Signing out from Google SDK', tag: 'DeleteAccount');
    await app_state.gAuth.signOutGoogle();

    // 4. Clear local persistence
    logger.i('[DeleteAccount] Step 4: Clearing local persistence', tag: 'DeleteAccount');
    await _settingsLocal.set(OnboardingV2Keys.onboardedNew, false);
    await _settingsLocal.set(OnboardingV2Keys.selectedInterests, '');
    await _settingsLocal.set(OnboardingV2Keys.followedCreators, '');
    await _settingsLocal.set('session.current_user', '');

    logger.i('[DeleteAccount] Done — account deleted successfully', tag: 'DeleteAccount');
  }
}
