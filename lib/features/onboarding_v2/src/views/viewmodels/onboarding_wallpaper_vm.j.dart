import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_wallpaper_vm.j.freezed.dart';

@freezed
abstract class OnboardingWallpaperVm with _$OnboardingWallpaperVm {
  const factory OnboardingWallpaperVm({
    required String fullUrl,
    required String thumbnailUrl,
    required String title,
    required String authorName,
    required String sourceCategory,
  }) = _OnboardingWallpaperVm;
}
