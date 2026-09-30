import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One person in a list: avatar, name, username and a Follow or Following button.
class UserSummaryTile extends StatelessWidget {
  const UserSummaryTile({super.key, required this.user, required this.onTap});

  final UserSummaryEntity user;

  /// Called when the person (not the follow button) is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name = user.name.isNotEmpty ? user.name : user.email;
    final bool isOwnAccount = user.email.toLowerCase() == app_state.prismUser.email.toLowerCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
      child: Row(
        children: <Widget>[
          Expanded(
            child: PressScale(
              scale: 0.98,
              child: Semantics(
                button: true,
                label: user.username.isEmpty ? name : '$name, @${user.username}',
                excludeSemantics: true,
                onTap: onTap,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Row(
                      children: <Widget>[
                        PrismAvatar(url: user.profilePhoto, name: name),
                        const SizedBox(width: PrismSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PrismTextStyles.rowTitle(context),
                              ),
                              if (user.username.isNotEmpty)
                                Text(
                                  '@${user.username}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PrismTextStyles.caption(context).copyWith(fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Hidden for the viewer's own account and when signed out.
          if (!isOwnAccount && app_state.prismUser.loggedIn) ...<Widget>[
            const SizedBox(width: PrismSpace.sm),
            _FollowPill(user: user),
          ],
        ],
      ),
    );
  }
}

/// "Follow" tinted with the accent, "Following" neutral. The fill and label change in [PrismDurations.fast].
class _FollowPill extends StatelessWidget {
  const _FollowPill({required this.user});

  final UserSummaryEntity user;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool following = user.isFollowedByCurrentUser;
    final Color bg = following ? cs.onSurface.withValues(alpha: 0.08) : cs.primary.withValues(alpha: 0.16);
    final Color fg = following ? cs.onSurface : cs.primary;
    return PressScale(
      child: Semantics(
        button: true,
        label: following ? 'Unfollow ${user.name}' : 'Follow ${user.name}',
        excludeSemantics: true,
        onTap: () => _onPressed(context),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onPressed(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Center(
              child: AnimatedContainer(
                duration: context.motion(PrismDurations.fast),
                curve: PrismCurves.enter,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(PrismRadius.pill)),
                child: AnimatedDefaultTextStyle(
                  duration: context.motion(PrismDurations.fast),
                  style: PrismTextStyles.button.copyWith(fontSize: 14, color: fg),
                  child: AnimatedSwitcher(
                    duration: context.motion(PrismDurations.fast),
                    child: Text(following ? 'Following' : 'Follow', key: ValueKey<bool>(following)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onPressed(BuildContext context) {
    HapticFeedback.selectionClick();
    context.read<PublicProfileBloc>().add(
      PublicProfileEvent.followChangeRequested(
        follow: !user.isFollowedByCurrentUser,
        currentUserId: app_state.prismUser.id,
        currentUserEmail: app_state.prismUser.email,
        targetUserId: user.id,
        targetUserEmail: user.email,
      ),
    );
  }
}
