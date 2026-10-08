import 'dart:convert';
import 'dart:io';

import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:path_provider/path_provider.dart';

/// The log tag for the export.
const String favouritesExportSourceTag = 'favourite_walls.export';

Object? _encodeValue(Object? value) => value is DateTime ? value.toUtc().toIso8601String() : value;

/// JSON for the export file. Each item is the same map that Prism saves in the favourite's Firestore doc.
String buildFavouritesExportJson(List<FavouriteWallEntity> walls, {DateTime? now}) {
  return const JsonEncoder.withIndent('  ', _encodeValue).convert(<String, Object?>{
    'app': 'Prism',
    'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'count': walls.length,
    'favourites': walls.map(favouriteWallToDoc).toList(growable: false),
  });
}

String favouritesExportFileName(DateTime now) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'prism-favourites-${now.year}-${two(now.month)}-${two(now.day)}.json';
}

/// Writes the export file to the temp directory and returns it.
Future<File> writeFavouritesExportFile(List<FavouriteWallEntity> walls, {Directory? directory, DateTime? now}) async {
  final DateTime stamp = now ?? DateTime.now();
  final Directory dir = directory ?? await getTemporaryDirectory();
  return File(
    '${dir.path}/${favouritesExportFileName(stamp)}',
  ).writeAsString(buildFavouritesExportJson(walls, now: stamp), flush: true);
}
