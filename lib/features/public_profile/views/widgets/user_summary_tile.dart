import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A reusable list tile that shows a user's avatar, name, username and
/// an inline Follow / Unfollow button.
class UserSummaryTile extends StatelessWidget {
  const UserSummaryTile({super.key, required this.user, required this.onTap});

  final UserSummaryEntity user;

  /// Called when the tile (not the follow button) is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String safeName = user.name.isNotEmpty ? user.name : user.email;
    final String safePhoto = user.profilePhoto.trim();
    final bool isOwnAccount = user.email.toLowerCase() == app_state.prismUser.email.toLowerCase();

    return InkWell(
      onTap: () {
        PrismHaptics.tap();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            _UserAvatar(photoUrl: safePhoto, name: safeName),
            const SizedBox(width: 12),

            // Name + username
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    safeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PrismFonts.proximaNova,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  if (user.username.isNotEmpty)
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: PrismFonts.proximaNova,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
            ),

            // Follow / Unfollow button — hidden for own account or if not logged in
            if (!isOwnAccount && app_state.prismUser.loggedIn) _FollowButton(user: user),
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.photoUrl, required this.name});

  final String photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => _FallbackAvatar(name: name),
          ),
        ),
      );
    }
    return _FallbackAvatar(name: name);
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.25),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: PrismFonts.proximaNova,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.user});

  final UserSummaryEntity user;

  @override
  Widget build(BuildContext context) {
    final bool isFollowing = user.isFollowedByCurrentUser;
    final Color borderColor = isFollowing
        ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35)
        : Theme.of(context).colorScheme.error;
    final Color textColor = isFollowing
        ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.error;

    return PressScale(
      child: AnimatedContainer(
        duration: context.motion(const Duration(milliseconds: 180)),
        curve: Curves.easeOut,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => _onPressed(context),
          child: AnimatedSwitcher(
            duration: context.motion(const Duration(milliseconds: 140)),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              key: ValueKey<bool>(isFollowing),
              style: TextStyle(
                fontFamily: PrismFonts.proximaNova,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onPressed(BuildContext context) {
    PrismHaptics.tap();
    context.read<PublicProfileBloc>().add(
      PublicProfileEvent.followChangeRequested(
        follow: !user.isFollowedByCurrentUser,
        currentUserId: app_state.prismUser.id,
        currentUserEmail: app_state.prismUser.email,
        targetUserId: user.id,
        targetUserEmail: user.email,
        targetName: user.name,
      ),
    );
  }
}
