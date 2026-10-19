import 'package:Prism/core/platform/wallpaper_error_messages.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await loadAppLocalizations(const Locale('en'));
  });

  group('wallpaperErrorMessage', () {
    test('static codes get one plain sentence each', () {
      expect(wallpaperErrorMessage('image-too-large', l10n), 'This image is too large for your device to set.');
      expect(
        wallpaperErrorMessage('wallpaper-not-allowed', l10n),
        'Your device or work profile does not allow wallpaper changes.',
      );
      expect(wallpaperErrorMessage('out-of-memory', l10n), 'Not enough memory. Close other apps and try again.');
      expect(wallpaperErrorMessage('timeout', l10n), 'Timed out. Check your connection and try again.');
    });

    test('unknown, empty and load codes use the generic sentence', () {
      expect(wallpaperErrorMessage(null, l10n), "Couldn't set the wallpaper.");
      expect(wallpaperErrorMessage('load_failed', l10n), "Couldn't set the wallpaper.");
      expect(wallpaperErrorMessage('something-new', l10n), "Couldn't set the wallpaper.");
    });

    test('live wallpapers keep their own wording for shared codes and the default', () {
      expect(
        wallpaperErrorMessage('image-too-large', l10n, live: true),
        'That file is too large for a live wallpaper.',
      );
      expect(
        wallpaperErrorMessage('source-too-large', l10n, live: true),
        'That file is too large for a live wallpaper.',
      );
      expect(wallpaperErrorMessage('invalid-video', l10n, live: true), contains('Try another clip'));
      expect(wallpaperErrorMessage('shader-link-failed', l10n, live: true), contains('Try another one'));
      expect(wallpaperErrorMessage('x', l10n, live: true), "Couldn't set the live wallpaper. Try again.");
      expect(wallpaperErrorMessage('out-of-memory', l10n, live: true), contains('Not enough memory'));
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
