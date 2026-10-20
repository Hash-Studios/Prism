import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';

class EmptyCanonicalWallpaperRepository implements PrismWallpaperRepository {
  @override
  Future<Result<PrismWallpaper?>> fetchCanonicalById(String id) async => Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
