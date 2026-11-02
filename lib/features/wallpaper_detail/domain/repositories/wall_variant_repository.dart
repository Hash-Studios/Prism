import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';

abstract interface class WallVariantRepository {
  /// The colour variants of [wall], with [wall] among them, or null when it has fewer than 2 that this app can show.
  Future<VariantGroup?> load(PrismWallpaper wall);
}
