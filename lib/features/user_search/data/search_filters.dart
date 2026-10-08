enum SearchSort { relevance, latest, toplist }

/// What the user narrowed a wallpaper search to. [minResolution] is `<width>x<height>`, for example `1080x1920`.
class SearchFilters {
  const SearchFilters({this.portraitOnly = true, this.minResolution, this.sort = SearchSort.relevance});

  final bool portraitOnly;
  final String? minResolution;
  final SearchSort sort;

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
  }) {
    return SearchFilters(
      portraitOnly: portraitOnly ?? this.portraitOnly,
      minResolution: clearMinResolution ? null : minResolution ?? this.minResolution,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.portraitOnly == portraitOnly &&
      other.minResolution == minResolution &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(portraitOnly, minResolution, sort);

  static ({int width, int height})? _parse(String? value) {
    final Match? match = RegExp(r'^\s*(\d+)\s*[xX]\s*(\d+)\s*$').firstMatch(value ?? '');
    if (match == null) {
      return null;
    }
    return (width: int.parse(match.group(1)!), height: int.parse(match.group(2)!));
  }
}
