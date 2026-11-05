import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live_wallpaper_applied serializes the 3D style using its analytics wire value', () {
    const LiveWallpaperAppliedEvent event = LiveWallpaperAppliedEvent(
      style: LiveWallpaperStyleValue.threeD,
      result: 'confirmInPreview',
      perScreen: false,
      fallback: false,
    );

    expect(event.eventName, 'live_wallpaper_applied');
    expect(event.toWireParameters(), <String, Object?>{
      'style': '3d',
      'result': 'confirmInPreview',
      'per_screen': 0,
      'fallback': 0,
    });
  });

  test('live_wallpaper_applied serializes target, per_screen and fallback when target is set', () {
    const LiveWallpaperAppliedEvent event = LiveWallpaperAppliedEvent(
      style: LiveWallpaperStyleValue.ripple,
      result: 'confirmInPreview',
      target: WallpaperTarget.lock,
      perScreen: true,
      fallback: false,
    );

    expect(event.toWireParameters(), <String, Object?>{
      'style': 'ripple',
      'result': 'confirmInPreview',
      'target': 'lock',
      'per_screen': 1,
      'fallback': 0,
    });
  });

  test('live_wallpaper_applied omits target when it is null and serializes the bool flags', () {
    const LiveWallpaperAppliedEvent event = LiveWallpaperAppliedEvent(
      style: LiveWallpaperStyleValue.ripple,
      result: 'confirmInPreview',
      perScreen: false,
      fallback: true,
    );

    final Map<String, Object?> parameters = event.toWireParameters();
    expect(parameters.containsKey('target'), isFalse);
    expect(parameters, <String, Object?>{
      'style': 'ripple',
      'result': 'confirmInPreview',
      'per_screen': 0,
      'fallback': 1,
    });
  });
}
