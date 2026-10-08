import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum QuickTileKind {
  shuffle('shuffle'),
  wotd('wotd'),
  favs('favs');

  const QuickTileKind(this.wireName);

  final String wireName;
}

enum QuickSettingsAddResult { added, alreadyAdded, notAdded, unsupported, error }

/// Asks Android 13 and up to add a Prism tile to Quick Settings.
class QuickSettingsChannel {
  const QuickSettingsChannel();

  static const MethodChannel _channel = MethodChannel('prism/quick_settings');

  /// True on Android 13 (API 33) and up, where the system can add a tile for the user.
  Future<bool> get canRequestAddTile async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final int? sdkInt = await _channel.invokeMethod<int>('sdkInt');
      return sdkInt != null && sdkInt >= 33;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<QuickSettingsAddResult> requestAddTile(QuickTileKind tile) async {
    try {
      final int? code = await _channel.invokeMethod<int>('requestAddTile', tile.wireName);
      return switch (code) {
        0 => QuickSettingsAddResult.notAdded,
        1 => QuickSettingsAddResult.alreadyAdded,
        2 => QuickSettingsAddResult.added,
        -1 => QuickSettingsAddResult.unsupported,
        _ => QuickSettingsAddResult.error,
      };
    } on PlatformException {
      return QuickSettingsAddResult.error;
    } on MissingPluginException {
      return QuickSettingsAddResult.unsupported;
    }
  }

  /// Redraws the Wall of the Day home-screen widget after the cached URL changes.
  Future<void> refreshWotdWidget() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('refreshWotdWidget');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
