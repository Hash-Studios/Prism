import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/persistence/data_sources/app_icons_local_data_source.dart';
import 'package:Prism/data/apps/app_icon.dart';
import 'package:Prism/logger/logger.dart';

const Duration _iconsCacheTtl = Duration(days: 7);

List<AppIcon> _decodeIcons(Object? raw) {
  if (raw is Map) {
    return raw.values.whereType<Map>().map((entry) => AppIcon.fromMap(entry)).toList(growable: false);
  }
  if (raw is List) {
    return raw.whereType<Map>().map((entry) => AppIcon.fromMap(entry)).toList(growable: false);
  }
  return const <AppIcon>[];
}

Future<List<AppIcon>> getIcons() async {
  final AppIconsLocalDataSource local = getIt<AppIconsLocalDataSource>();
  final Map<String, dynamic> cached = await local.readIconsPayload();
  final DateTime? cachedAt = await local.lastUpdatedAtUtc();
  final bool cacheFresh =
      cached.isNotEmpty && cachedAt != null && DateTime.now().toUtc().difference(cachedAt) <= _iconsCacheTtl;

  if (cacheFresh) {
    logger.d('Returning fresh icon cache', fields: <String, Object?>{'count': cached.length});
    return _decodeIcons(cached);
  }

  logger.i("Fethcing icons");
  try {
    final value = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.apps,
      "icons",
      (data, _) => data,
      sourceTag: "apps.getIcons",
    );
    final Map<String, dynamic> iconData = value?["data"] as Map<String, dynamic>? ?? <String, dynamic>{};
    logger.d("Fetched ${iconData.values.toList().length} icons");
    await local.writeIconsPayload(iconData);
    logger.i("Saved icons to cache");
    return _decodeIcons(iconData);
  } catch (error, stackTrace) {
    logger.w('Failed to fetch icon cache from remote', error: error, stackTrace: stackTrace);
    return _decodeIcons(cached);
  }
}
