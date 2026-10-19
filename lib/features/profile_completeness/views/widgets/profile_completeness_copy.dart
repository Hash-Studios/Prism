import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/l10n/l10n.dart';

String profileCompletenessStepLabel(AppLocalizations l10n, ProfileCompletenessStep step) => switch (step) {
  ProfileCompletenessStep.photo => l10n.accountAddProfilePhoto,
  ProfileCompletenessStep.username => l10n.accountSetUsername,
  ProfileCompletenessStep.bio => l10n.accountWriteBio,
  ProfileCompletenessStep.socialLink => l10n.accountAddSocialLink,
};
