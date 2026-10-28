import 'package:Prism/core/color/prism_palette.dart';

enum SearchSort { relevance, latest, toplist }

/// What the user narrowed a wallpaper search to. [minResolution] is `<width>x<height>`, for example `1080x1920`.
class SearchFilters {
  const SearchFilters({
    this.portraitOnly = true,
    this.minResolution,
    this.sort = SearchSort.relevance,
    this.color,
    this.depthOnly = false,
    this.spatialOnly = false,
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

  bool get listsWithoutQuery => color != null || depthOnly || spatialOnly;

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
  }) {
    return SearchFilters(
      portraitOnly: portraitOnly ?? this.portraitOnly,
      minResolution: clearMinResolution ? null : minResolution ?? this.minResolution,
      sort: sort ?? this.sort,
      color: clearColor ? null : color ?? this.color,
      depthOnly: depthOnly ?? this.depthOnly,
      spatialOnly: spatialOnly ?? this.spatialOnly,
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
      other.spatialOnly == spatialOnly;

  @override
  int get hashCode => Object.hash(portraitOnly, minResolution, sort, color, depthOnly, spatialOnly);

  static ({int width, int height})? _parse(String? value) {
    final Match? match = RegExp(r'^\s*(\d+)\s*[xX]\s*(\d+)\s*$').firstMatch(value ?? '');
    if (match == null) {
      return null;
    }
    return (width: int.parse(match.group(1)!), height: int.parse(match.group(2)!));
  }
}
