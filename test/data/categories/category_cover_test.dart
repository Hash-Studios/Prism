import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_cover.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

void main() {
  final List<String> stockCovers = <String>[
    for (final Object? interest in json.decode(defaultPersonalizedInterestsJson) as List<Object?>)
      (interest! as Map<String, Object?>)['imageUrl']! as String,
    for (final category in categoryDefinitions) category.imageUrl,
  ];

  test('every stock interest and category cover ships in the app', () {
    expect(stockCovers, isNotEmpty);
    for (final String url in stockCovers) {
      final String? asset = bundledCoverAsset(url);
      expect(asset, isNotNull, reason: '$url has no bundled copy');
      expect(File(asset!).existsSync(), isTrue, reason: '$asset is missing');
      expect(coverImageProvider(url), AssetImage(asset));
    }
  });

  test('the covers folder is a declared asset folder', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('    - assets/images/covers/\n'));
  });

  test('an unknown cover still loads from the network', () {
    expect(bundledCoverAsset('https://images.pexels.com/photos/42/pexels-photo-42.jpeg'), isNull);
    expect(bundledCoverAsset('https://example.com/photos/326900/x.jpeg'), isNull);
    expect(bundledCoverAsset(''), isNull);
  });

  testWidgets('a cover that fails to precache is not reported as an error', (tester) async {
    final cache = _MockCacheManager();
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((_) => Stream<FileResponse>.error(const HttpExceptionWithStatus(504, 'Gateway timeout')));
    PrismImageCache.testOverride = cache;
    addTearDown(() => PrismImageCache.testOverride = null);
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );

    final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? original = FlutterError.onError;
    FlutterError.onError = reported.add;
    try {
      await tester.runAsync(() => precacheCover('https://images.pexels.com/photos/42/pexels-photo-42.jpeg', context));
    } finally {
      FlutterError.onError = original;
    }

    expect(reported, isEmpty);
  });
}
