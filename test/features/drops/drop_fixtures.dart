import 'package:Prism/features/drops/domain/entities/drop_entity.dart';

DropWall dropWall(String id, {String by = 'Ana'}) => DropWall(
  id: id,
  title: 'Wall $id',
  thumb: 'https://example.test/$id.jpg',
  resolution: '1080x2400',
  by: by,
  seriesId: 's1',
);

DropEntity dropEntity({
  String weekKey = '2026-W42',
  int priceWall = 30,
  int pricePack = 100,
  Duration startedAgo = const Duration(days: 1),
  Duration endsIn = const Duration(days: 6),
  List<String> wallIds = const <String>['A', 'B', 'C', 'D'],
}) {
  final DateTime now = DateTime.now();
  return DropEntity(
    weekKey: weekKey,
    title: 'Weekly Drop $weekKey',
    startsAt: now.subtract(startedAgo),
    endsAt: now.add(endsIn),
    priceWall: priceWall,
    pricePack: pricePack,
    count: wallIds.length,
    walls: wallIds.map(dropWall).toList(),
  );
}
