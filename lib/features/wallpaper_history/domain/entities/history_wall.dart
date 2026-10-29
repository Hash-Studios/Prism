import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';

enum HistoryAction { view, set, download }

/// A catalogue wall in a history list: only what a tile shows and what opens the detail screen.
/// It never holds the original or a signed link, so the list is safe to sync.
class HistoryWall {
  const HistoryWall._({
    required this.id,
    required this.source,
    required this.thumbnailUrl,
    required this.action,
    required this.at,
  });

  final String id;
  final WallpaperSource source;
  final String thumbnailUrl;
  final HistoryAction action;
  final DateTime at;

  static const Set<WallpaperSource> catalogSources = <WallpaperSource>{
    WallpaperSource.prism,
    WallpaperSource.wallhaven,
    WallpaperSource.pexels,
  };

  /// The doc id in `usersv2/{uid}/history` and the dedupe key.
  String get key => keyOf(source, id);

  static String keyOf(WallpaperSource source, String id) => '${source.wireValue}_$id';

  /// Null when the wall is not a catalogue wall, or when [thumbnailUrl] is not a plain public https link.
  static HistoryWall? tryCreate({
    required String? id,
    required WallpaperSource? source,
    required String? thumbnailUrl,
    required HistoryAction action,
    required DateTime at,
  }) {
    final String wallId = id?.trim() ?? '';
    final String thumb = thumbnailUrl?.trim() ?? '';
    if (wallId.isEmpty || wallId.length > 128 || wallId.contains('/') || !catalogSources.contains(source)) return null;
    if (!isPublicThumbnail(thumb)) return null;
    return HistoryWall._(id: wallId, source: source!, thumbnailUrl: thumb, action: action, at: at.toUtc());
  }

  /// Signed links expire and may unlock a gated original, so they are never stored.
  static bool isPublicThumbnail(String url) {
    if (url.length > 1024) return false;
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
    const Set<String> signedParameters = <String>{'signature', 'googleaccessid', 'sig'};
    try {
      return !uri.queryParameters.keys.any((key) {
        final String normalized = key.toLowerCase();
        return signedParameters.contains(normalized) ||
            normalized.startsWith('x-amz-') ||
            normalized.startsWith('x-goog-');
      });
    } on FormatException {
      return false;
    }
  }

  HistoryWall copyWith({HistoryAction? action, DateTime? at}) => HistoryWall._(
    id: id,
    source: source,
    thumbnailUrl: thumbnailUrl,
    action: action ?? this.action,
    at: at ?? this.at,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'provider': source.wireValue,
    'thumb': thumbnailUrl,
    'action': action.name,
    'at': at.toIso8601String(),
  };

  /// The Firestore doc. The rules accept exactly these fields.
  Map<String, dynamic> toDoc() => <String, dynamic>{
    'id': id,
    'provider': source.wireValue,
    'thumb': thumbnailUrl,
    'action': action.name,
    'at': at,
  };

  /// Reads a local entry or a Firestore doc. Null for anything malformed.
  static HistoryWall? tryParse(Object? json) {
    if (json is! Map) return null;
    final Object? id = json['id'];
    final Object? thumb = json['thumb'];
    final HistoryAction? action = HistoryAction.values.asNameMap()[json['action']];
    final Object? rawAt = json['at'];
    if (rawAt is int && (rawAt < -8640000000000000 || rawAt > 8640000000000000)) return null;
    DateTime? at;
    try {
      at = parseDateTime(rawAt);
    } on FormatException {
      return null;
    }
    if (id is! String || thumb is! String || action == null || at == null) return null;
    return tryCreate(
      id: id,
      source: WallpaperSourceX.fromWire(json['provider']),
      thumbnailUrl: thumb,
      action: action,
      at: at,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryWall &&
      other.id == id &&
      other.source == source &&
      other.thumbnailUrl == thumbnailUrl &&
      other.action == action &&
      other.at == at;

  @override
  int get hashCode => Object.hash(id, source, thumbnailUrl, action, at);
}

/// One entry per wall, the newest of each, newest first, at most [cap].
List<HistoryWall> mergeHistory(Iterable<HistoryWall> a, Iterable<HistoryWall> b, {required int cap}) {
  final Map<String, HistoryWall> newest = <String, HistoryWall>{};
  for (final HistoryWall item in <HistoryWall>[...a, ...b]) {
    final HistoryWall? seen = newest[item.key];
    if (seen == null || item.at.isAfter(seen.at)) newest[item.key] = item;
  }
  final List<HistoryWall> sorted = newest.values.toList()..sort((x, y) => y.at.compareTo(x.at));
  return sorted.length > cap ? sorted.sublist(0, cap) : sorted;
}
