import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';

part 'onboarding_wallpaper_vm.j.freezed.dart';

@freezed
abstract class OnboardingWallpaperVm with _$OnboardingWallpaperVm {
  const factory OnboardingWallpaperVm({
    required String fullUrl,
    required String thumbnailUrl,
    required String sourceCategory,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
  }) = _OnboardingWallpaperVm;
}
