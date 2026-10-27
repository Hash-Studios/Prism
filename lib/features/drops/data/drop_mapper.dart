import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';

DateTime? _fromMs(Object? raw) {
  final num? ms = raw is num ? raw : null;
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true);
}

/// Null when the doc has no usable time window.
DropEntity? dropFromMap(Map<String, dynamic> data, String weekKey) {
  final DateTime? startsAt = _fromMs(data['startsAt']);
  final DateTime? endsAt = _fromMs(data['endsAt']);
  if (startsAt == null || endsAt == null) return null;
  final Object? rawWalls = data['walls'];
  final List<DropWall> walls = <DropWall>[
    if (rawWalls is List)
      for (final Object? raw in rawWalls)
        if (parseString(toJsonMap(raw)['id']).isNotEmpty) _wallFromMap(toJsonMap(raw)),
  ];
  return DropEntity(
    weekKey: weekKey,
    title: parseString(data['title'], fallback: ''),
    startsAt: startsAt,
    endsAt: endsAt,
    priceWall: parseIntOr(data['priceWall']),
    pricePack: parseIntOr(data['pricePack']),
    count: parseIntOr(data['count'], fallback: walls.length),
    walls: walls,
    collectors: parseIntOr(data['collectors']),
  );
}

/// The planner puts only Prism Studio walls in a Drop. Drops planned before it copied `creatorUid` fall back to Studio.
const String _studioCreatorUid = 'prism-studio';

DropWall _wallFromMap(Map<String, dynamic> m) {
  final String creatorUid = parseString(m['creatorUid']).trim();
  return DropWall(
    id: parseString(m['id']),
    title: parseString(m['title']),
    thumb: parseString(m['thumb']),
    resolution: parseString(m['resolution']),
    by: parseString(m['by']),
    seriesId: parseString(m['seriesId']),
    creatorUid: creatorUid.isEmpty ? _studioCreatorUid : creatorUid,
  );
}
