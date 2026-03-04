import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_creator_vm.j.freezed.dart';

@freezed
abstract class OnboardingCreatorVm with _$OnboardingCreatorVm {
  const factory OnboardingCreatorVm({
    required String userId,
    required String email,
    required String name,
    required String photoUrl,
    required List<String> previewUrls,
    required int rank,
    required bool isSelected,
    required String bio,
    required int followerCount,
  }) = _OnboardingCreatorVm;
}
