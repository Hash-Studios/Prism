import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

/// One wall in 2 to 5 colours. Each colour is a full approved wall by the same creator, in the order the server set.
final class VariantGroup {
  const VariantGroup({required this.id, required this.walls});

  static const int maxWalls = 5;

  final String id;
  final List<PrismWallpaper> walls;

  int get length => walls.length;
  bool get isFull => walls.length >= maxWalls;

  /// Position of the wall with Firestore document id [docId], or -1.
  int indexOfDoc(String? docId) => docId == null ? -1 : walls.indexWhere((w) => w.firestoreDocumentId == docId);

  bool containsId(String id) => walls.any((w) => w.id == id);

  /// The same set with [wall] in place of the member that has its document id.
  VariantGroup replace(PrismWallpaper wall) => VariantGroup(
    id: id,
    walls: [
      for (final w in walls)
        if (w.firestoreDocumentId == wall.firestoreDocumentId) wall else w,
    ],
  );
}
