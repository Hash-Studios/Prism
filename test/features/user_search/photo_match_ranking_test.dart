import 'dart:typed_data';

import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/user_search/data/photo_match_ranking.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';
import 'package:flutter_test/flutter_test.dart';

PhotoQuery query({required List<(String, double)> palette, List<String> labels = const <String>[], String? category}) =>
    PhotoQuery(
      preview: Uint8List(0),
      palette: <PaletteShare>[
        for (final (String id, double share) in palette) (color: paletteColorById(id)!, share: share),
      ],
      labels: labels,
      category: category,
      labelsStatus: labels.isEmpty ? PhotoLabelsStatus.guest : PhotoLabelsStatus.found,
    );

PhotoCandidate wall(String id, List<String>? colors, [List<String> terms = const <String>[]]) => (
  wall: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
    colors: colors,
  ),
  terms: terms,
);

PaletteShare share(String id, double value) => (color: paletteColorById(id)!, share: value);

void main() {
  test('paletteCloseness is 1 for the same palette', () {
    expect(paletteCloseness(<PaletteShare>[share('blue', 1.0)], <String>['blue']), 1.0);
  });

  test('paletteCloseness is 0 for no wall colours', () {
    final List<PaletteShare> photo = <PaletteShare>[share('blue', 1.0)];

    expect(paletteCloseness(photo, null), 0.0);
    expect(paletteCloseness(photo, const <String>[]), 0.0);
    expect(paletteCloseness(photo, const <String>['nope']), 0.0);
  });

  test('closer colours score higher', () {
    final List<PaletteShare> photo = <PaletteShare>[share('blue', 1.0)];

    expect(
      paletteCloseness(photo, const <String>['teal']),
      greaterThan(paletteCloseness(photo, const <String>['orange'])),
    );
  });

  test('a wall with extra colours ranks below a pure match', () {
    final List<PaletteShare> photo = <PaletteShare>[share('blue', 1.0)];

    expect(
      paletteCloseness(photo, const <String>['blue']),
      greaterThan(paletteCloseness(photo, const <String>['blue', 'red'])),
    );
  });

  test('dominant order matters', () {
    final List<PaletteShare> photo = <PaletteShare>[share('orange', 0.7), share('blue', 0.3)];

    expect(
      paletteCloseness(photo, const <String>['orange', 'blue']),
      greaterThan(paletteCloseness(photo, const <String>['blue', 'orange'])),
    );
  });

  test('ranking with empty labels uses colour only', () {
    final PhotoQuery q = query(palette: <(String, double)>[('blue', 1.0)]);
    final List<PhotoCandidate> candidates = <PhotoCandidate>[
      wall('a', const <String>['red'], const <String>['blue', 'sky']),
      wall('b', const <String>['blue']),
      wall('c', null),
      wall('d', const <String>['blue']),
    ];

    expect(rankPhotoMatches(q, candidates).map((w) => w.id).toList(), <String>['b', 'd', 'a', 'c']);
  });

  test('labels lift a wall with matching terms', () {
    final PhotoQuery q = query(palette: <(String, double)>[('orange', 1.0)], labels: <String>['Sunset', 'Sky']);
    final List<PhotoCandidate> candidates = <PhotoCandidate>[
      wall('x', const <String>['orange']),
      wall('y', const <String>['orange'], const <String>['sunset', 'sky']),
      wall('z', const <String>['blue'], const <String>['sunset', 'sky']),
    ];

    // y = 0.5 * 1.0 + 0.5 * 1.0 = 1.0. x = 0.5 * 1.0 + 0 = 0.5. z = 0.5 * 0 + 0.5 = 0.5, because orange and
    // blue are about 138 apart in Lab, so their closeness clamps to 0. x and z tie, so input order keeps x first.
    expect(rankPhotoMatches(q, candidates).map((w) => w.id).toList(), <String>['y', 'x', 'z']);
  });

  test('category counts as a term', () {
    final PhotoQuery q = query(
      palette: <(String, double)>[('orange', 1.0)],
      labels: <String>['Afterglow'],
      category: 'Nature',
    );
    final List<PhotoCandidate> candidates = <PhotoCandidate>[
      wall('p', const <String>['orange'], const <String>['afterglow']),
      wall('q', const <String>['orange'], const <String>['afterglow', 'nature']),
    ];

    expect(rankPhotoMatches(q, candidates).map((w) => w.id).toList(), <String>['q', 'p']);
  });

  test('photoQueryTerms singularises and lowercases like the backend', () {
    final PhotoQuery q = query(
      palette: <(String, double)>[('blue', 1.0)],
      labels: <String>['Clouds', 'Red sky at morning'],
      category: 'Nature',
    );

    expect(photoQueryTerms(q), <String>['cloud', 'red', 'sky', 'morning', 'nature']);
  });

  test('limit caps the result', () {
    final PhotoQuery q = query(palette: <(String, double)>[('blue', 1.0)]);
    final List<PhotoCandidate> candidates = <PhotoCandidate>[
      for (int i = 0; i < 20; i++) wall('w$i', const <String>['blue']),
    ];

    final List<PrismWallpaper> result = rankPhotoMatches(q, candidates, limit: 5);

    expect(result, hasLength(5));
    expect(result.map((w) => w.id).toList(), <String>['w0', 'w1', 'w2', 'w3', 'w4']);
  });
}
