import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/session_local_data_source.dart';
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
    if (userId.isEmpty) throw StateError('No signed-in user to delete.');

    logger.i('[DeleteAccount] Starting deletion for userId=$userId', tag: 'DeleteAccount');

    // If the user cancels re-authentication this throws and we never reach the server.
    final providerIds =
        FirebaseAuth.instance.currentUser?.providerData.map((provider) => provider.providerId).toSet() ?? {};
    if (providerIds.contains('apple.com')) {
      await globalAppleAuth.reauthenticateCurrentUser();
    } else {
      await globalGoogleAuth.reauthenticateCurrentUser();
    }

    await appFunctions
        .httpsCallable('deleteAccount', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
        .call<dynamic>();

    // Sign out from Google SDK so silent re-auth doesn't recreate the account.
    await globalGoogleAuth.signOutGoogle();

    await _settingsLocal.delete(OnboardingV2Keys.onboardedNew);
    await _settingsLocal.delete(OnboardingV2Keys.selectedInterests);
    await _settingsLocal.delete(OnboardingV2Keys.followedCreators);
    await getIt<SessionLocalDataSource>().clearCurrentUser();

    logger.i('[DeleteAccount] Done', tag: 'DeleteAccount');
  }
}
