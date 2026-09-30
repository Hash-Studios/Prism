import 'package:Prism/core/wallpaper/setup_wallpaper_value.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_setup_entity.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';

extension SetupEntityWallpaperX on SetupEntity {
  SetupWallpaperValue get wallpaperValue => SetupWallpaperValue.parse(wallpaperUrl);
}

extension PublicProfileSetupEntityWallpaperX on PublicProfileSetupEntity {
  SetupWallpaperValue get wallpaperValue => SetupWallpaperValue.parse(wallpaperUrl);
}
