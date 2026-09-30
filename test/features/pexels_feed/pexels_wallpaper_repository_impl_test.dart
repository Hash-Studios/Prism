import 'package:Prism/core/error/failure.dart';
import 'package:Prism/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_feed_cache_local_data_source.dart';

void main() {
  test('fetchColorFeed rejects a colour that is not six hex digits without a request', () async {
    final repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());

    for (final hex in <String>['', 'ff00', 'gg0000', 'ff00000', '#12345']) {
      final result = await repository.fetchColorFeed(hex: hex, refresh: true);

      expect(result.failure, isA<ValidationFailure>(), reason: 'hex "$hex"');
    }
  });
}
