import 'package:Prism/features/live_wallpaper/data/wallpaper_capabilities_tilt.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter_test/flutter_test.dart';

class _TiltSupportingCapabilities extends aw.WallpaperCapabilities {
  const _TiltSupportingCapabilities();

  bool get supportsTilt => true;
}

void main() {
  test('async_wallpaper 3.5 defaults to no tilt support', () {
    const aw.WallpaperCapabilities capabilities = aw.WallpaperCapabilities();
    expect(capabilities.supportsTilt, isFalse);
  });

  test('a statically typed member wins over the imported extension getter', () {
    const _TiltSupportingCapabilities capabilities = _TiltSupportingCapabilities();
    expect(capabilities.supportsTilt, isTrue);
  });
}
