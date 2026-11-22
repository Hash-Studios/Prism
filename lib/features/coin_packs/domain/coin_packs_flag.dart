import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';

/// Remote Config switch for coin packs (docs/features/coin-packs.md). Off hides every buy entry.
class CoinPacksFlag {
  CoinPacksFlag._();

  static const String remoteConfigKey = 'coin_packs_enabled';
  static const bool defaultEnabled = false;

  /// Test seam. Null reads Remote Config.
  static bool? debugOverride;

  static bool get enabled {
    final bool? override = debugOverride;
    if (override != null) return override;
    try {
      return FirebaseInit.remoteConfigIfInitialized?.getBool(remoteConfigKey) ?? defaultEnabled;
    } catch (error) {
      logger.w('[CoinPacks] flag unreadable, using the default: $error');
      return defaultEnabled;
    }
  }

  /// True when the flag is on and a signed-in user is present. Guests never see a buy entry.
  static bool get available => enabled && app_state.prismUser.loggedIn && app_state.prismUser.id.isNotEmpty;
}
