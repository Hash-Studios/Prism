import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:flutter_test/flutter_test.dart';

PrismWallpaper _kindWall(String id, {bool live = false, bool desktop = false, bool pair = false}) =>
    PrismWallDocDto.fromJson(<String, dynamic>{
      'id': id,
      'wallpaper_url': 'https://prism/$id.jpg',
      'wallpaper_provider': 'prism',
      'review': true,
      if (live) 'kind': 'live',
      if (live) 'live': <String, dynamic>{'video': 'https://prism/$id.mp4', 'verified': true},
      if (desktop)
        'desktopVariant': <String, dynamic>{
          'v': 'abcdef0123456789',
          'width': 2560,
          'height': 1600,
          'wideHeight': 1600,
          'thumb': 'https://prism/d-$id.jpg',
        },
      if (pair) 'variantGroupId': 'g1',
      if (pair) 'variantIndex': 0,
    }).toDomain(docId: id);

void main() {
  test('defaults are portrait only, no minimum and relevance sort', () {
    const filters = SearchFilters();

    expect(filters.portraitOnly, isTrue);
    expect(filters.minResolution, isNull);
    expect(filters.sort, SearchSort.relevance);
    expect(filters.wallhavenSorting, isNull);
  });

  test('sort maps to the Wallhaven sorting value', () {
    expect(const SearchFilters(sort: SearchSort.latest).wallhavenSorting, 'date_added');
    expect(const SearchFilters(sort: SearchSort.toplist).wallhavenSorting, 'toplist');
  });

  test('acceptsResolution checks orientation and minimum, and lets unknown sizes through', () {
    const filters = SearchFilters(minResolution: '1080x1920');

    expect(filters.acceptsResolution('1440x2560'), isTrue);
    expect(filters.acceptsResolution('720x1280'), isFalse);
    expect(filters.acceptsResolution('3840x2160'), isFalse, reason: 'landscape');
    expect(filters.acceptsResolution(null), isTrue);
    expect(filters.acceptsResolution('big'), isTrue);
    expect(const SearchFilters(portraitOnly: false).acceptsResolution('3840x2160'), isTrue);
  });

  test('copyWith can clear the minimum resolution, and equal filters compare equal', () {
    final filters = const SearchFilters().copyWith(minResolution: '2160x3840', sort: SearchSort.latest);

    expect(filters.minResolution, '2160x3840');
    expect(filters.copyWith(clearMinResolution: true).minResolution, isNull);
    expect(const SearchFilters(), const SearchFilters());
    expect(const SearchFilters().hashCode, const SearchFilters().hashCode);
    expect(filters, isNot(const SearchFilters()));
  });

  test('the colour is off by default, can be set and cleared, and takes part in equality', () {
    final PrismPaletteColor blue = paletteColorById('blue')!;
    final withBlue = const SearchFilters().copyWith(color: blue);

    expect(const SearchFilters().color, isNull);
    expect(withBlue.color, blue);
    expect(withBlue, isNot(const SearchFilters()));
    expect(withBlue, SearchFilters(color: blue));
    expect(withBlue.hashCode, SearchFilters(color: blue).hashCode);
    expect(withBlue.copyWith(sort: SearchSort.latest).color, blue);
    expect(withBlue.copyWith(clearColor: true), const SearchFilters());
    expect(withBlue.copyWith(color: paletteColorById('red')).color!.id, 'red');
  });

  test('the depth filter is off by default, can be set and cleared, and takes part in equality', () {
    final withDepth = const SearchFilters().copyWith(depthOnly: true);

    expect(const SearchFilters().depthOnly, isFalse);
    expect(withDepth.depthOnly, isTrue);
    expect(withDepth, isNot(const SearchFilters()));
    expect(withDepth, const SearchFilters(depthOnly: true));
    expect(withDepth.hashCode, const SearchFilters(depthOnly: true).hashCode);
    expect(withDepth.copyWith(sort: SearchSort.latest).depthOnly, isTrue);
    expect(withDepth.copyWith(depthOnly: false), const SearchFilters());
  });

  test('a colour or the depth filter lists walls without a text query', () {
    expect(const SearchFilters().listsWithoutQuery, isFalse);
    expect(const SearchFilters(sort: SearchSort.latest, minResolution: '1080x1920').listsWithoutQuery, isFalse);
    expect(const SearchFilters(depthOnly: true).listsWithoutQuery, isTrue);
    expect(SearchFilters(color: paletteColorById('blue')).listsWithoutQuery, isTrue);
  });

  test('the spatial filter is off by default, can be set and cleared, and takes part in equality', () {
    final withSpatial = const SearchFilters().copyWith(spatialOnly: true);

    expect(const SearchFilters().spatialOnly, isFalse);
    expect(withSpatial.spatialOnly, isTrue);
    expect(withSpatial, isNot(const SearchFilters()));
    expect(withSpatial, const SearchFilters(spatialOnly: true));
    expect(withSpatial.hashCode, const SearchFilters(spatialOnly: true).hashCode);
    expect(withSpatial, isNot(const SearchFilters(depthOnly: true)));
    expect(withSpatial.copyWith(sort: SearchSort.latest).spatialOnly, isTrue);
    expect(withSpatial.copyWith(spatialOnly: false), const SearchFilters());
  });

  test('the spatial filter lists walls without a text query', () {
    expect(const SearchFilters(spatialOnly: true).listsWithoutQuery, isTrue);
  });

  test('defaults have no source, no kinds, are not Prism only and name no active filter', () {
    const filters = SearchFilters();

    expect(filters.source, SearchSource.all);
    expect(filters.kinds, isEmpty);
    expect(filters.prismOnly, isFalse);
    expect(filters.activeNames, isEmpty);
  });

  test('a kind, the depth filter, the spatial filter or the Prism source makes the search Prism only', () {
    expect(const SearchFilters(kinds: <PrismWallKind>{PrismWallKind.live}).prismOnly, isTrue);
    expect(const SearchFilters(depthOnly: true).prismOnly, isTrue);
    expect(const SearchFilters(spatialOnly: true).prismOnly, isTrue);
    expect(const SearchFilters(source: SearchSource.prism).prismOnly, isTrue);
  });

  test('a kind lists walls without a query, the Prism source alone does not', () {
    expect(const SearchFilters(kinds: <PrismWallKind>{PrismWallKind.desktop}).listsWithoutQuery, isTrue);
    expect(const SearchFilters(source: SearchSource.prism).listsWithoutQuery, isFalse);
  });

  test('activeNames lists the filters that differ from the defaults, by name, in a fixed order', () {
    final SearchFilters filters = SearchFilters(
      portraitOnly: false,
      minResolution: '1080x1920',
      sort: SearchSort.latest,
      color: paletteColorById('blue'),
      source: SearchSource.prism,
      kinds: <PrismWallKind>{PrismWallKind.lightDark, PrismWallKind.live},
    );

    expect(filters.activeNames, <String>[
      'any_orientation',
      'min_resolution',
      'sort',
      'color',
      'prism_only',
      'kind_live',
      'kind_light-dark',
    ]);
  });

  test('equality ignores the order of kinds, and so does the hash code', () {
    final SearchFilters live = SearchFilters(kinds: <PrismWallKind>{PrismWallKind.live, PrismWallKind.desktop});
    final SearchFilters desktop = SearchFilters(kinds: <PrismWallKind>{PrismWallKind.desktop, PrismWallKind.live});

    expect(live, desktop);
    expect(live.hashCode, desktop.hashCode);
  });

  test('acceptsKinds needs a wall to match every kind in the set', () {
    final PrismWallpaper liveWall = _kindWall('live', live: true);
    final PrismWallpaper livePair = _kindWall('live-pair', live: true, pair: true);
    final PrismWallpaper desktopWall = _kindWall('desktop', desktop: true);
    final PrismWallpaper still = _kindWall('still');

    expect(const SearchFilters().acceptsKinds(still), isTrue, reason: 'no kinds accepts any wall');
    expect(const SearchFilters(kinds: <PrismWallKind>{PrismWallKind.live}).acceptsKinds(liveWall), isTrue);
    expect(const SearchFilters(kinds: <PrismWallKind>{PrismWallKind.live}).acceptsKinds(still), isFalse);
    expect(const SearchFilters(kinds: <PrismWallKind>{PrismWallKind.desktop}).acceptsKinds(desktopWall), isTrue);
    expect(const SearchFilters(kinds: <PrismWallKind>{PrismWallKind.desktop}).acceptsKinds(liveWall), isFalse);
    expect(
      const SearchFilters(kinds: <PrismWallKind>{PrismWallKind.live, PrismWallKind.lightDark}).acceptsKinds(livePair),
      isTrue,
    );
    expect(
      const SearchFilters(kinds: <PrismWallKind>{PrismWallKind.live, PrismWallKind.lightDark}).acceptsKinds(liveWall),
      isFalse,
    );
  });
}
