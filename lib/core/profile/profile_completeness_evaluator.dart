import 'package:Prism/auth/userModel.dart';

enum ProfileCompletenessStep { photo, username, bio, socialLink }

class ProfileCompletenessStatus {
  const ProfileCompletenessStatus({
    required this.completedSteps,
    required this.totalSteps,
    required this.progress,
    required this.percent,
    required this.missingSteps,
  });

  final int completedSteps;
  final int totalSteps;
  final double progress;
  final int percent;
  final List<ProfileCompletenessStep> missingSteps;

  bool get isComplete => completedSteps >= totalSteps;
}

class ProfileCompletenessEvaluator {
  const ProfileCompletenessEvaluator._();

  static const int _totalSteps = 4;

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

    final int completedSteps = _totalSteps - missingSteps.length;
    final double progress = completedSteps / _totalSteps;

    return ProfileCompletenessStatus(
      completedSteps: completedSteps,
      totalSteps: _totalSteps,
      progress: progress,
      percent: completedSteps * 25,
      missingSteps: missingSteps,
    );
  }

  static bool _hasCompletedPhoto(PrismUsersV2 user, {required String defaultProfilePhotoUrl}) {
    final String currentPhoto = user.profilePhoto.trim();
    if (currentPhoto.isEmpty) {
      return false;
    }
    return currentPhoto != defaultProfilePhotoUrl.trim();
  }

  static bool _hasAnySocialLink(Map<dynamic, dynamic> links) {
    if (links.isEmpty) {
      return false;
    }
    return links.values.any((value) => value.toString().trim().isNotEmpty);
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
