import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the full image cache has its own key and a smaller budget than the thumbnail cache', () {
    expect(PrismFullImageCache.key, 'prism_full');
    expect(PrismFullImageCache.key, isNot(PrismImageCache.key));
    expect(PrismFullImageCache.maxObjects, 60);
    expect(PrismFullImageCache.stalePeriod, const Duration(days: 7));
  });
}
