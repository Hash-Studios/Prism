import 'package:Prism/core/constants/profile_links.dart';
import 'package:Prism/core/utils/format_utils.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/string_extensions.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Height of the visible cover, below the status bar.
const double _coverHeight = 170;
const double _avatarSize = 84;
const double _avatarRing = 3;

/// The top of a profile: cover, avatar, name, bio, stats, actions and links. Left aligned, on the page surface.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    required this.ownProfile,
    required this.following,
    required this.isPro,
    required this.onEdit,
    required this.onShare,
    required this.onToggleFollow,
    required this.onOpenFollowers,
    required this.onOpenFollowing,
    required this.onOpenPosts,
    required this.onOpenLink,
  });

  final PublicProfileEntity profile;
  final bool ownProfile;

  /// Whether the signed-in viewer follows [profile].
  final bool following;

  /// Shows the Pro tag next to the name.
  final bool isPro;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onToggleFollow;
  final VoidCallback onOpenFollowers;
  final VoidCallback onOpenFollowing;
  final VoidCallback onOpenPosts;
  final void Function(String key, String value) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double coverHeight = _coverHeight + MediaQuery.paddingOf(context).top;
    const double avatarFull = _avatarSize + 2 * _avatarRing;
    final String name = profile.name.trim();
    final List<String> linkKeys = profile.links.keys.where((k) => profile.links[k]!.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            SizedBox(
              height: coverHeight,
              width: double.infinity,
              child: ProfileCover(url: profile.coverPhoto),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const <double>[0.4, 1],
                      colors: <Color>[cs.surface.withValues(alpha: 0), cs.surface],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: PrismSpace.page,
              bottom: -avatarFull / 2,
              child: Container(
                padding: const EdgeInsets.all(_avatarRing),
                decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                child: PrismAvatar(url: profile.profilePhoto, name: name, size: _avatarSize),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: avatarFull / 2 + PrismSpace.xs,
                child: Padding(
                  padding: const EdgeInsets.only(left: avatarFull + PrismSpace.xs),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ownProfile
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Flexible(
                                child: PrismButton(
                                  label: 'Edit profile',
                                  variant: PrismButtonVariant.tonal,
                                  size: PrismButtonSize.compact,
                                  onPressed: onEdit,
                                ),
                              ),
                              const SizedBox(width: PrismSpace.xs),
                              PrismIconButton(
                                icon: Icons.ios_share_rounded,
                                tooltip: 'Share profile',
                                filled: true,
                                onPressed: onShare,
                              ),
                            ],
                          )
                        : _FollowButton(following: following, onPressed: onToggleFollow),
                  ),
                ),
              ),
              const SizedBox(height: PrismSpace.sm),
              Row(
                children: <Widget>[
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        name.isEmpty ? profile.username : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PrismTextStyles.screenTitle(context).copyWith(fontSize: 24),
                      ),
                    ),
                  ),
                  if (isPro) ...<Widget>[
                    const SizedBox(width: PrismSpace.xs),
                    const PrismTag(label: 'Pro', tone: PrismTone.accent, icon: Icons.workspace_premium_rounded),
                  ],
                ],
              ),
              if (profile.username.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  '@${profile.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PrismTextStyles.body(context),
                ),
              ],
              if (profile.bio.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: PrismSpace.sm),
                Text(
                  profile.bio.trim(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: PrismTextStyles.body(
                    context,
                  ).copyWith(height: 1.4, color: cs.onSurface.withValues(alpha: 0.85)),
                ),
              ],
              const SizedBox(height: PrismSpace.md),
              Wrap(
                spacing: PrismSpace.lg,
                runSpacing: PrismSpace.xs,
                children: <Widget>[
                  BlocBuilder<PublicProfileBloc, PublicProfileState>(
                    buildWhen: (a, b) =>
                        a.walls.length != b.walls.length || a.hasMoreWalls != b.hasMoreWalls || a.status != b.status,
                    builder: (context, state) {
                      final bool ready =
                          state.email == profile.email &&
                          state.status != LoadStatus.initial &&
                          (state.status != LoadStatus.loading || state.walls.isNotEmpty);
                      final String value = ready
                          ? '${formatCompactCount(state.walls.length)}${state.hasMoreWalls ? '+' : ''}'
                          : '–';
                      return _Stat(value: value, label: 'Posts', onTap: onOpenPosts);
                    },
                  ),
                  _Stat(
                    value: formatCompactCount(profile.followers.length),
                    label: 'Followers',
                    onTap: onOpenFollowers,
                  ),
                  _Stat(
                    value: formatCompactCount(profile.following.length),
                    label: 'Following',
                    onTap: ownProfile ? onOpenFollowing : null,
                  ),
                ],
              ),
              if (linkKeys.isNotEmpty) ...<Widget>[
                const SizedBox(height: PrismSpace.sm),
                Wrap(
                  spacing: PrismSpace.xs,
                  runSpacing: PrismSpace.xs,
                  children: <Widget>[
                    for (final String key in linkKeys)
                      PrismIconButton(
                        icon: profileLinkIcon(key),
                        tooltip: key.inCaps,
                        filled: true,
                        onPressed: () => onOpenLink(key, profile.links[key]!),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.following, required this.onPressed});

  final bool following;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion(PrismDurations.fast),
      switchInCurve: PrismCurves.enter,
      layoutBuilder: (Widget? current, List<Widget> previous) =>
          Stack(alignment: Alignment.centerRight, children: <Widget>[...previous, ?current]),
      child: PrismButton(
        key: ValueKey<bool>(following),
        label: following ? 'Following' : 'Follow',
        variant: following ? PrismButtonVariant.tonal : PrismButtonVariant.primary,
        size: PrismButtonSize.compact,
        onPressed: onPressed,
      ),
    );
  }
}

/// A number over its label. The whole group is one tap target.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Semantics(
        button: onTap != null,
        label: label,
        value: value,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(value, style: PrismTextStyles.numeral(context, 22)),
                Text(label, style: PrismTextStyles.caption(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
