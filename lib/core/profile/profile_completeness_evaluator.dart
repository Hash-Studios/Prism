import 'package:Prism/auth/user_model.dart';

enum ProfileCompletenessStep { photo, username, bio, socialLink }

class ProfileCompletenessStatus {
  const ProfileCompletenessStatus({required this.missingSteps});

  final List<ProfileCompletenessStep> missingSteps;

  int get totalSteps => ProfileCompletenessStep.values.length;
  int get completedSteps => totalSteps - missingSteps.length;
  double get progress => completedSteps / totalSteps;
  int get percent => completedSteps * 100 ~/ totalSteps;

  bool get isComplete => missingSteps.isEmpty;
}

class ProfileCompletenessEvaluator {
  const ProfileCompletenessEvaluator._();

  static ProfileCompletenessStatus evaluate(PrismUsersV2 user, {required String defaultProfilePhotoUrl}) {
    final bool hasPhoto = _hasCompletedPhoto(user, defaultProfilePhotoUrl: defaultProfilePhotoUrl);
    final bool hasUsername = user.username.trim().isNotEmpty;
    final bool hasBio = user.bio.trim().isNotEmpty;
    final bool hasSocialLink = _hasAnySocialLink(user.links);

    final List<ProfileCompletenessStep> missingSteps = <ProfileCompletenessStep>[
      if (!hasPhoto) ProfileCompletenessStep.photo,
      if (!hasUsername) ProfileCompletenessStep.username,
      if (!hasBio) ProfileCompletenessStep.bio,
      if (!hasSocialLink) ProfileCompletenessStep.socialLink,
    ];

    return ProfileCompletenessStatus(missingSteps: missingSteps);
  }

  static bool _hasCompletedPhoto(PrismUsersV2 user, {required String defaultProfilePhotoUrl}) {
    final String currentPhoto = user.profilePhoto.trim();
    if (currentPhoto.isEmpty) {
      return false;
    }
    return currentPhoto != defaultProfilePhotoUrl.trim();
  }

  static bool _hasAnySocialLink(Map<String, String> links) {
    if (links.isEmpty) {
      return false;
    }
    return links.values.any((value) => value.trim().isNotEmpty);
  }
}

extension ProfileCompletenessStepX on ProfileCompletenessStep {
  String get label {
    switch (this) {
      case ProfileCompletenessStep.photo:
        return 'Add profile photo';
      case ProfileCompletenessStep.username:
        return 'Set username';
      case ProfileCompletenessStep.bio:
        return 'Write bio';
      case ProfileCompletenessStep.socialLink:
        return 'Add one social link';
    }
  }
}
