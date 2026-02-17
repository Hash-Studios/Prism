import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/logger/logger.dart';
import 'package:hive_io/hive_io.dart';

Future<List> getIcons() async {
  logger.i("Fethcing icons");
  final value = await firestoreClient.getById<Map<String, dynamic>>(
    FirebaseCollections.apps,
    "icons",
    (data, _) => data,
    sourceTag: "apps.getIcons",
  );
  final Map<String, dynamic> iconData = value?["data"] as Map<String, dynamic>? ?? <String, dynamic>{};
  logger.d("Fetched ${iconData.values.toList().length} icons");
  final Box box = Hive.box('appsCache');
  box.put('icons', iconData);
  logger.i("Saved icons to cache");
  return (box.get('icons') as Map).values.toList();
}
