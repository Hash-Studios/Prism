import 'dart:async';

import 'package:Prism/features/creator_directory/views/creator_follow_changes.dart';
import 'package:Prism/features/creator_directory/views/similar_creators_offer.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

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
  creatorFollowChanges.record(outcome.targetUserId, outcome.follow);
  if (outcome.follow) {
    unawaited(
      showFollowToastWithSimilarOffer(
        context,
        uid: outcome.targetUserId,
        name: name,
        message: context.l10n.accountFollowedPerson(name),
      ),
    );
    return;
  }
  toasts.success(context.l10n.accountUnfollowedPerson(name), haptic: false);
}
