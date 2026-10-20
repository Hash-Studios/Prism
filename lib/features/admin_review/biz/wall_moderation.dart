import 'package:Prism/core/firestore/firestore_document.dart';

/// A signal from the server check on a pending wall, in the order an admin should read them: most serious first.
enum ModerationFlag {
  unsafe('unsafe'),
  duplicate('duplicate'),
  webMatch('web_match'),
  logo('logo'),
  text('text');

  const ModerationFlag(this.wire);

  final String wire;

  static final Map<String, ModerationFlag> _byWire = <String, ModerationFlag>{
    for (final ModerationFlag flag in values) flag.wire: flag,
  };

  /// Null for a name this app does not know, so a newer server can add flags.
  static ModerationFlag? parse(Object? wire) => _byWire[wire];
}

/// A Prism wall that looks the same as the pending one. [similarity] runs from 0 to 1. [thumb] may be empty.
class ModerationDuplicate {
  const ModerationDuplicate({required this.wallId, required this.similarity, required this.thumb});

  final String wallId;
  final double similarity;
  final String thumb;

  int get percent => (similarity.clamp(0.0, 1.0) * 100).round();
}

/// A web page that shows the same image.
class ModerationWebMatch {
  const ModerationWebMatch({required this.url, required this.host});

  final String url;
  final String host;
}

/// What the server check found in a pending wall: hints for the admin, not a verdict.
class WallModeration {
  const WallModeration({
    required this.flags,
    this.duplicate,
    this.web = const <ModerationWebMatch>[],
    this.words = const <String>[],
    this.logos = const <String>[],
    this.unsafe = const <String>[],
  });

  /// Known flags only, most serious first.
  final List<ModerationFlag> flags;
  final ModerationDuplicate? duplicate;
  final List<ModerationWebMatch> web;
  final List<String> words;
  final List<String> logos;
  final List<String> unsafe;
}

/// `walls.moderation`, written by the server. Null when the wall was not checked yet.
WallModeration? wallModeration(FirestoreDocument wall) {
  final Object? raw = wall.payload['moderation'];
  if (raw is! Map) return null;
  final Object? duplicate = raw['duplicate'];
  return WallModeration(
    flags: _flags(raw['flags']),
    duplicate: duplicate is Map ? _duplicate(duplicate) : null,
    web: _webMatches(raw['web']),
    words: _strings(raw['words']),
    logos: _strings(raw['logos']),
    unsafe: _strings(raw['unsafe']),
  );
}

List<ModerationFlag> _flags(Object? raw) {
  if (raw is! List) return const <ModerationFlag>[];
  final Set<ModerationFlag> known = <ModerationFlag>{for (final Object? wire in raw) ?ModerationFlag.parse(wire)};
  return ModerationFlag.values.where(known.contains).toList(growable: false);
}

ModerationDuplicate? _duplicate(Map<Object?, Object?> raw) {
  final Object? wallId = raw['wallId'];
  final Object? similarity = raw['similarity'];
  if (wallId is! String || wallId.isEmpty || similarity is! num) return null;
  final Object? thumb = raw['thumb'];
  return ModerationDuplicate(wallId: wallId, similarity: similarity.toDouble(), thumb: thumb is String ? thumb : '');
}

List<ModerationWebMatch> _webMatches(Object? raw) {
  if (raw is! List) return const <ModerationWebMatch>[];
  final List<ModerationWebMatch> matches = <ModerationWebMatch>[];
  for (final Object? entry in raw) {
    if (entry is! Map) continue;
    final Object? url = entry['url'];
    final Object? host = entry['host'];
    // The admin taps these, so only web pages count.
    if (url is! String || host is! String || host.isEmpty) continue;
    final String? scheme = Uri.tryParse(url)?.scheme;
    if (scheme != 'http' && scheme != 'https') continue;
    matches.add(ModerationWebMatch(url: url, host: host));
  }
  return matches;
}

List<String> _strings(Object? raw) {
  if (raw is! List) return const <String>[];
  return <String>[
    for (final Object? item in raw)
      if (item is String && item.isNotEmpty) item,
  ];
}
