// Hash-Studios/Prism#539
import 'dart:convert';

import 'package:Prism/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../../support/fake_feed_cache_local_data_source.dart';

http.Response _curatedPage(List<int> ids) => http.Response(
  jsonEncode(<String, Object>{
    'page': 1,
    'per_page': 24,
    'total_results': 48,
    'photos': <Object>[
      for (final int id in ids)
        <String, Object>{
          'id': id,
          'url': 'https://example.com/$id',
          'src': <String, Object>{'original': 'https://example.com/$id'},
        },
    ],
  }),
  200,
);

void main() {
  test('an empty first page on refresh does not replace the cached curated walls with an empty success', () async {
    final PexelsWallpaperRepositoryImpl repository = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
    bool empty = false;
    final http.Client client = MockClient((http.Request request) async {
      if (empty) return http.Response('{"page":1,"per_page":24,"total_results":0,"photos":[]}', 200);
      return _curatedPage(<int>[1, 2]);
    });

    final results = await http.runWithClient(() async {
      final first = await repository.fetchFeed(categoryName: 'Curated', refresh: true);
      empty = true;
      final second = await repository.fetchFeed(categoryName: 'Curated', refresh: true);
      return (first, second);
    }, () => client);

    expect(results.$1.data, hasLength(2));
    expect(results.$2.data, anyOf(isNull, hasLength(2)));
  });
}
