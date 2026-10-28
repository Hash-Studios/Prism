import 'package:async_wallpaper/async_wallpaper.dart' as aw;

/// `async_wallpaper` 3.6.0 adds `WallpaperCapabilities.supportsTilt`. A class member wins over an extension member,
/// so on 3.6.0 the plugin answers and on 3.5.0 this getter answers false. Delete this file once Prism needs ^3.6.0.
extension WallpaperCapabilitiesTilt on aw.WallpaperCapabilities {
  bool get supportsTilt => false;
}
