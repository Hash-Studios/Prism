import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

void showFollowOutcomeToast(FollowOutcome outcome) {
  final String name = outcome.targetName.trim().isEmpty ? 'this user' : outcome.targetName.trim();
  if (!outcome.success) {
    toasts.error(outcome.follow ? "Couldn't follow $name. Try again." : "Couldn't unfollow $name. Try again.");
    return;
  }
  toasts.success(outcome.follow ? 'Followed $name!' : 'Unfollowed $name!', haptic: false);
}
