import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/user_search/data/search_link.dart';

export 'package:Prism/features/user_search/data/search_link.dart';

/// What the user narrowed a wallpaper search to. [minResolution] is `<width>x<height>`, for example `1080x1920`.
class SearchFilters {
  const SearchFilters({
    this.portraitOnly = true,
    this.minResolution,
    this.sort = SearchSort.relevance,
    this.color,
    this.depthOnly = false,
    this.spatialOnly = false,
    this.source = SearchSource.all,
    this.kinds = const <PrismWallKind>{},
  });

  final bool portraitOnly;
  final String? minResolution;
  final SearchSort sort;

  /// One palette colour, or `null` for any colour.
  final PrismPaletteColor? color;

  /// Only Prism walls the iOS Lock Screen Depth Effect works on. Wallhaven and Pexels walls carry no depth data.
  final bool depthOnly;

  /// Only Prism walls whose Spatial Scene tier is `great` or `ok`. Shown on iOS and Android.
  final bool spatialOnly;

  final SearchSource source;

  /// Each kind narrows the results further: a wall must match every kind in the set.
  final Set<PrismWallKind> kinds;

  bool get listsWithoutQuery => color != null || depthOnly || spatialOnly || kinds.isNotEmpty;

  /// Only Prism walls can match, so the search skips Wallhaven and Pexels.
  bool get prismOnly => source == SearchSource.prism || kinds.isNotEmpty || depthOnly || spatialOnly;

  /// [fields] from a search link. Null when the colour id is not a palette colour.
  static SearchFilters? fromLink(SearchLinkFields fields) {
    final PrismPaletteColor? color = paletteColorById(fields.colorId);
    if (fields.colorId != null && color == null) return null;
    return SearchFilters(
      portraitOnly: fields.portraitOnly,
      minResolution: fields.minResolution,
      sort: fields.sort,
      color: color,
      depthOnly: fields.depthOnly,
      spatialOnly: fields.spatialOnly && !fields.depthOnly,
      source: fields.source,
      kinds: fields.kinds,
    );
  }

  /// True when [wall] has every kind in [kinds].
  bool acceptsKinds(PrismWallpaper wall) => kinds.every((kind) => kind.matches(wall));

  /// The filters that differ from the defaults, by name. The filter button shows how many there are.
  List<String> get activeNames => <String>[
    if (!portraitOnly) 'any_orientation',
    if (minResolution != null) 'min_resolution',
    if (sort != SearchSort.relevance) 'sort',
    if (color != null) 'color',
    if (depthOnly) 'depth',
    if (spatialOnly) 'spatial',
    if (source == SearchSource.prism) 'prism_only',
    for (final PrismWallKind kind in PrismWallKind.values)
      if (kinds.contains(kind)) 'kind_${kind.wire}',
  ];

  /// Wallhaven `sorting` value. `null` keeps the API default, which is relevance for a text query.
  String? get wallhavenSorting => switch (sort) {
    SearchSort.relevance => null,
    SearchSort.latest => 'date_added',
    SearchSort.toplist => 'toplist',
  };

  /// Whether a `<width>x<height>` [resolution] passes these filters. An unknown resolution passes.
  bool acceptsResolution(String? resolution) {
    final ({int width, int height})? size = _parse(resolution);
    if (size == null) {
      return true;
    }
    if (portraitOnly && size.height < size.width) {
      return false;
    }
    final ({int width, int height})? minimum = _parse(minResolution);
    return minimum == null || (size.width >= minimum.width && size.height >= minimum.height);
  }

  SearchFilters copyWith({
    bool? portraitOnly,
    String? minResolution,
    bool clearMinResolution = false,
    SearchSort? sort,
    PrismPaletteColor? color,
    bool clearColor = false,
    bool? depthOnly,
    bool? spatialOnly,
    SearchSource? source,
    Set<PrismWallKind>? kinds,
  }) {
    return SearchFilters(
      portraitOnly: portraitOnly ?? this.portraitOnly,
      minResolution: clearMinResolution ? null : minResolution ?? this.minResolution,
      sort: sort ?? this.sort,
      color: clearColor ? null : color ?? this.color,
      depthOnly: depthOnly ?? this.depthOnly,
      spatialOnly: spatialOnly ?? this.spatialOnly,
      source: source ?? this.source,
      kinds: kinds ?? this.kinds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.portraitOnly == portraitOnly &&
      other.minResolution == minResolution &&
      other.sort == sort &&
      other.color == color &&
      other.depthOnly == depthOnly &&
      other.spatialOnly == spatialOnly &&
      other.source == source &&
      other.kinds.length == kinds.length &&
      other.kinds.containsAll(kinds);

  @override
  int get hashCode => Object.hash(
    portraitOnly,
    minResolution,
    sort,
    color,
    depthOnly,
    spatialOnly,
    source,
    Object.hashAllUnordered(kinds),
  );

  static ({int width, int height})? _parse(String? value) {
    final Match? match = RegExp(r'^\s*(\d+)\s*[xX]\s*(\d+)\s*$').firstMatch(value ?? '');
    if (match == null) {
      return null;
    }
    return (width: int.parse(match.group(1)!), height: int.parse(match.group(2)!));
  }
}

extension PrismWallKindMatch on PrismWallKind {
  /// A live wall is a verified MP4. A desktop wall has a desktop version. A light and dark wall is in a colour variant
  /// set, which the day and night pair is made from.
  bool matches(PrismWallpaper wall) => switch (this) {
    PrismWallKind.live => wall.kind == WallKind.live,
    PrismWallKind.desktop => wall.desktop != null,
    PrismWallKind.lightDark => (wall.variantGroupId ?? '').isNotEmpty,
  };
}
