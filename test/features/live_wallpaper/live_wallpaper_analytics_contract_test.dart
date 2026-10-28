import 'package:Prism/core/analytics/events/events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live_wallpaper_applied serializes the 3D style using its analytics wire value', () {
    const LiveWallpaperAppliedEvent event = LiveWallpaperAppliedEvent(
      style: LiveWallpaperStyleValue.threeD,
      result: 'confirmInPreview',
    );

    expect(event.eventName, 'live_wallpaper_applied');
    expect(event.toWireParameters(), <String, Object?>{'style': '3d', 'result': 'confirmInPreview'});
  });
}
