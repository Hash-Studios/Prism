import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_wallpaper_vm.j.freezed.dart';

@freezed
abstract class OnboardingWallpaperVm with _$OnboardingWallpaperVm {
  const factory OnboardingWallpaperVm({
    required String fullUrl,
    required String thumbnailUrl,
    required String sourceCategory,
    AiStylePreset? aiStyle,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
  }) = _OnboardingWallpaperVm;
}
