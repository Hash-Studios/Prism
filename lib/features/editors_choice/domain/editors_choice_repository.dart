import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

/// Editors' Choice picks. Only the `setEditorsChoice` callable writes `walls.editorsChoiceAt`.
abstract interface class EditorsChoiceRepository {
  /// Successful pick changes made in this app, so mounted lists can reload.
  Stream<void> watchPickChanges();

  /// Picks the viewer can see, newest pick first.
  Future<List<PrismWallpaper>> fetchPicks({required int limit});

  /// Admin only. Sets or clears the pick on the wall with Firestore document id [wallDocId]. Throws
  /// [EditorsChoiceNotEligible] when the server refuses to pick the wall.
  Future<void> setPick({required String wallDocId, required bool picked});
}

/// The wall is not approved, is premium, exclusive or in a Drop, or its original is not ready yet.
final class EditorsChoiceNotEligible implements Exception {
  const EditorsChoiceNotEligible();
}
