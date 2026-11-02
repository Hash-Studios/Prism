import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/editors_choice/domain/editors_choice_repository.dart';

/// No picks, for tests that pump Home without testing Editors' Choice.
class EmptyEditorsChoiceRepository implements EditorsChoiceRepository {
  const EmptyEditorsChoiceRepository();

  @override
  Future<List<PrismWallpaper>> fetchPicks({required int limit}) async => const <PrismWallpaper>[];

  @override
  Future<void> setPick({required String wallDocId, required bool picked}) async {}
}
