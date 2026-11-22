import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/debug/creator_stats_emulator.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';

/// The switches for creator premium walls. See docs/features/creator-premium-walls.md.
abstract final class CreatorWallsFlag {
  static const String remoteConfigKey = 'creator_premium_walls_enabled';
  static const bool defaultEnabled = false;

  @visibleForTesting
  static bool? debugEnabled;

  /// The Remote Config switch. Off by default. An unreadable flag is off.
  static bool get enabled {
    final bool? override = debugEnabled;
    if (override != null) return override;
    // The emulator QA build reads no Remote Config; tool/creator_stats_qa/seed_creator_walls.cjs turns the server on.
    if (CreatorStatsEmulator.enabled) return true;
    try {
      return FirebaseInit.remoteConfigIfInitialized?.getBool(remoteConfigKey) ?? defaultEnabled;
    } catch (error) {
      logger.w('[CreatorWalls] flag unreadable, using the default: $error');
      return defaultEnabled;
    }
  }

  /// True when a creator may put a price on a wall: the app switch and the server switch are both on.
  static bool get sellingEnabled =>
      enabled && (CreatorStatsEmulator.enabled || EconomyConfig.current.flags.creatorWallsEnabled);
}
