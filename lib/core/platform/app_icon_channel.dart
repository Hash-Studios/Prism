import 'package:Prism/core/platform/pigeon/prism_app_icon_api.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Switches the launcher icon. Shop ids map to the native icon names: iOS alternate icons, Android activity aliases.
class AppIconChannel {
  const AppIconChannel._();

  static const Map<String, String> nativeNames = <String, String>{
    'icon_noir': 'AppIconNoir',
    'icon_glass': 'AppIconGlass',
    'icon_sunset': 'AppIconSunset',
    'icon_mono': 'AppIconMono',
  };

  @visibleForTesting
  static PrismAppIconHostApi api = PrismAppIconHostApi();

  /// Sets the icon for a shop id, or the default icon for null. False for an unknown id or when the system refuses.
  static Future<bool> setIcon(String? id) async {
    final String? native = id == null ? null : nativeNames[id];
    if (id != null && native == null) return false;
    try {
      return await api.setAppIcon(native);
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> supported() async {
    try {
      return await api.supportsAlternateIcons();
    } on PlatformException {
      return false;
    }
  }
}
