import 'package:Prism/core/wallpaper/setup_wallpaper_value.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';

extension SetupEntityWallpaperX on SetupEntity {
  SetupWallpaperValue get wallpaperValue => SetupWallpaperValue.parse(wallpaperUrl);
}
