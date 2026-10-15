import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/features/live_wallpaper/data/live_texture_preparer.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

void main() {
  late _MockCacheManager cache;

  setUp(() {
    cache = _MockCacheManager();
    PrismFullImageCache.testOverride = cache;
  });

  tearDown(() => PrismFullImageCache.testOverride = null);

  test('downloads the wallpaper through the full-size image cache', () async {
    when(() => cache.getSingleFile(any())).thenThrow(Exception('offline'));

    await expectLater(
      const LiveTexturePreparer().prepare('https://example.com/a.jpg', 0.45),
      throwsA(
        isA<LiveTextureException>().having(
          (error) => error.message,
          'message',
          "Couldn't download the wallpaper. Check your connection and try again.",
        ),
      ),
    );
    verify(() => cache.getSingleFile('https://example.com/a.jpg')).called(1);
  });
}
