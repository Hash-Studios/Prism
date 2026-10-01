import 'package:Prism/core/error/failure.dart';
import 'package:Prism/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_feed_cache_local_data_source.dart';

void main() {
  test('fetchColorFeed rejects a colour that is not six hex digits without a request', () async {
    final repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());

    for (final hex in <String>['', 'ff00', 'gg0000', 'ff00000', '#12345']) {
      final result = await repository.fetchColorFeed(hex: hex, name: 'Red', refresh: true);

      expect(result.failure, isA<ValidationFailure>(), reason: 'hex "$hex"');
    }
  });

  test('fetchColorFeed searches by the colour name and filters by the hex', () async {
    final repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
    final List<Uri> requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      return http.Response('{"page":1,"per_page":80,"total_results":0,"photos":[]}', 200);
    });

    await http.runWithClient(() => repository.fetchColorFeed(hex: '#B71C1C', name: 'Red', refresh: true), () => client);

    expect(requested.single.queryParameters['query'], 'red wallpaper');
    expect(requested.single.queryParameters['color'], '#b71c1c');
  });
}
