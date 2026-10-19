import 'package:flutter/material.dart';

import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/l10n/l10n.dart';

void showFollowOutcomeToast(BuildContext context, FollowOutcome outcome) {
  final String name = outcome.targetName.trim().isEmpty ? context.l10n.accountThisUser : outcome.targetName.trim();
  if (!outcome.success) {
    toasts.error(
      outcome.follow
          ? context.l10n.accountCouldNotFollowPerson(name)
          : context.l10n.accountCouldNotUnfollowPerson(name),
    );
    return;
  }
  toasts.success(
    outcome.follow ? context.l10n.accountFollowedPerson(name) : context.l10n.accountUnfollowedPerson(name),
    haptic: false,
  );
}
