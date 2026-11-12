/// The search link: `/dashboard/search?q=sky&kind=live`. This file is plain Dart, so the deep link catalog can check a
/// link without Flutter.
library;

enum SearchSort { relevance, latest, toplist }

/// Where results come from. [prism] hides Wallhaven and Pexels walls.
enum SearchSource { all, prism }

/// A kind of Prism wall. Wallhaven and Pexels walls have none of these, so any kind filter shows Prism walls only.
/// [wire] is the value in a search link, for example `kind=live,desktop`.
enum PrismWallKind {
  live('live'),
  desktop('desktop'),
  lightDark('light-dark');

  const PrismWallKind(this.wire);

  final String wire;

  static PrismWallKind? fromWire(String value) {
    for (final PrismWallKind kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

/// A search as a link carries it. [colorId] is a palette id. [minResolution] is `<width>x<height>`.
typedef SearchLinkFields = ({
  String query,
  Set<PrismWallKind> kinds,
  SearchSource source,
  String? colorId,
  SearchSort sort,
  String? minResolution,
  bool portraitOnly,
  bool depthOnly,
  bool spatialOnly,
});

/// The query keys of a search link. A link with none of them opens Search as it is.
const Set<String> searchLinkKeys = <String>{
  'q',
  'kind',
  'source',
  'color',
  'sort',
  'res',
  'portrait',
  'depth',
  'spatial',
};

const int _maxQueryLength = 200;
final RegExp _colorId = RegExp(r'^[a-z]{1,24}$');
final RegExp _resolution = RegExp(r'^[1-9]\d{2,4}x[1-9]\d{2,4}$');
final RegExp _control = RegExp(r'[\u0000-\u001F\u007F]');

/// The query parameters for [fields]. Default values are left out, so a plain search is `q=sky`.
Map<String, String> searchLinkParams(SearchLinkFields fields) => <String, String>{
  if (fields.query.trim().isNotEmpty) 'q': fields.query.trim(),
  if (fields.kinds.isNotEmpty)
    'kind': <String>[
      for (final PrismWallKind kind in PrismWallKind.values)
        if (fields.kinds.contains(kind)) kind.wire,
    ].join(','),
  if (fields.source != SearchSource.all) 'source': fields.source.name,
  if (fields.colorId != null) 'color': fields.colorId!,
  if (fields.sort != SearchSort.relevance) 'sort': fields.sort.name,
  if (fields.minResolution != null) 'res': fields.minResolution!,
  if (!fields.portraitOnly) 'portrait': 'false',
  if (fields.depthOnly) 'depth': 'true',
  if (fields.spatialOnly) 'spatial': 'true',
};

/// The link path for [fields], for example `/dashboard/search?q=sky&kind=live`.
String searchLinkPath(SearchLinkFields fields) {
  final Map<String, String> params = searchLinkParams(fields);
  return Uri(path: '/dashboard/search', queryParameters: params.isEmpty ? null : params).toString();
}

/// The fields of a search link, or null when a value is not valid. Keys outside [searchLinkKeys] are not read.
SearchLinkFields? parseSearchLink(Map<String, String> params) {
  final String query = (params['q'] ?? '').trim();
  if (query.length > _maxQueryLength || _control.hasMatch(query)) return null;

  final Set<PrismWallKind> kinds = <PrismWallKind>{};
  final String? kindValue = params['kind'];
  if (kindValue != null) {
    for (final String wire in kindValue.split(',')) {
      final PrismWallKind? kind = PrismWallKind.fromWire(wire.trim());
      if (kind == null) return null;
      kinds.add(kind);
    }
  }

  final SearchSource? source = params.containsKey('source')
      ? SearchSource.values.asNameMap()[params['source']]
      : SearchSource.all;
  final SearchSort? sort = params.containsKey('sort')
      ? SearchSort.values.asNameMap()[params['sort']]
      : SearchSort.relevance;
  final String? colorId = params['color'];
  final String? minResolution = params['res'];
  final bool? portraitOnly = _flag(params['portrait'], fallback: true);
  final bool? depthOnly = _flag(params['depth'], fallback: false);
  final bool? spatialOnly = _flag(params['spatial'], fallback: false);
  if (source == null ||
      sort == null ||
      portraitOnly == null ||
      depthOnly == null ||
      spatialOnly == null ||
      (colorId != null && !_colorId.hasMatch(colorId)) ||
      (minResolution != null && !_resolution.hasMatch(minResolution))) {
    return null;
  }
  return (
    query: query,
    kinds: kinds,
    source: source,
    colorId: colorId,
    sort: sort,
    minResolution: minResolution,
    portraitOnly: portraitOnly,
    depthOnly: depthOnly,
    spatialOnly: spatialOnly,
  );
}

bool? _flag(String? value, {required bool fallback}) => switch (value) {
  null => fallback,
  'true' => true,
  'false' => false,
  _ => null,
};
