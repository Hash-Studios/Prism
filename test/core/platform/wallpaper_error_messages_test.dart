import 'package:Prism/core/platform/wallpaper_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wallpaperErrorMessage', () {
    test('static codes get one plain sentence each', () {
      expect(wallpaperErrorMessage('image-too-large'), 'This image is too large for your device to set.');
      expect(
        wallpaperErrorMessage('wallpaper-not-allowed'),
        'Your device or work profile does not allow wallpaper changes.',
      );
      expect(wallpaperErrorMessage('out-of-memory'), 'Not enough memory. Close other apps and try again.');
      expect(wallpaperErrorMessage('timeout'), 'Timed out. Check your connection and try again.');
    });

    test('unknown, empty and load codes use the generic sentence', () {
      expect(wallpaperErrorMessage(null), "Couldn't set the wallpaper.");
      expect(wallpaperErrorMessage('load_failed'), "Couldn't set the wallpaper.");
      expect(wallpaperErrorMessage('something-new'), "Couldn't set the wallpaper.");
    });

    test('live wallpapers keep their own wording for shared codes and the default', () {
      expect(wallpaperErrorMessage('image-too-large', live: true), 'That file is too large for a live wallpaper.');
      expect(wallpaperErrorMessage('source-too-large', live: true), 'That file is too large for a live wallpaper.');
      expect(wallpaperErrorMessage('invalid-video', live: true), contains('Try another clip'));
      expect(wallpaperErrorMessage('shader-link-failed', live: true), contains('Try another one'));
      expect(wallpaperErrorMessage('x', live: true), "Couldn't set the live wallpaper. Try again.");
      expect(wallpaperErrorMessage('out-of-memory', live: true), contains('Not enough memory'));
    });
  });

  group('canRetryWallpaperError', () {
    test('permanent codes cannot be retried', () {
      for (final String code in <String>['image-too-large', 'wallpaper-not-allowed', 'invalid-image']) {
        expect(canRetryWallpaperError(code), isFalse, reason: code);
      }
    });

    test('transient and unknown codes can be retried', () {
      for (final String? code in <String?>[null, 'timeout', 'load_failed', 'out-of-memory', 'exception', 'boom']) {
        expect(canRetryWallpaperError(code), isTrue, reason: '$code');
      }
    });
  });
}
