import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/views/creator_follow_changes.dart';
import 'package:Prism/features/creator_directory/views/widgets/visible_directory_creator.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Follow and Following for a directory creator. It reads and writes the nearest [PublicProfileBloc], so the button
/// changes at once and goes back if the server refuses. [followed] is the state when the list loaded.
class CreatorFollowButton extends StatelessWidget {
  const CreatorFollowButton({super.key, required this.creator, required this.followed, required this.source});

  final CreatorDirectoryEntry creator;
  final bool followed;

  /// Where the card is, for analytics: home, search, see_all or similar.
  final String source;

  @override
  Widget build(BuildContext context) {
    final bool following = context.select<PublicProfileBloc, bool>(
      (bloc) => bloc.state.followOverrides[creator.uid] ?? followed,
    );
    return ListenableBuilder(
      listenable: creatorFollowChanges,
      builder: (context, _) => _button(context, creatorFollowChanges.following(creator.uid) ?? following),
    );
  }

  Widget _button(BuildContext context, bool following) {
    final String name = creator.displayName;
    return Semantics(
      button: true,
      label: following ? context.l10n.accountUnfollowPerson(name) : context.l10n.accountFollowPerson(name),
      excludeSemantics: true,
      child: PrismButton(
        label: following ? context.l10n.accountFollowing : context.l10n.accountFollow,
        variant: following ? PrismButtonVariant.ghost : PrismButtonVariant.tonal,
        size: PrismButtonSize.compact,
        onPressed: () async {
          if (await requireSignedInAction(context) && context.mounted) _toggle(context, follow: !following);
        },
      ),
    );
  }

  void _toggle(BuildContext context, {required bool follow}) {
    PrismHaptics.selection();
    if (follow) {
      analytics.track(
        source == 'similar'
            ? SimilarCreatorFollowedEvent(creatorId: creator.uid)
            : CreatorCardFollowedEvent(source: source, creatorId: creator.uid),
      );
    }
    context.read<PublicProfileBloc>().add(
      PublicProfileEvent.followChangeRequested(
        follow: follow,
        currentUserId: app_state.prismUser.id,
        currentUserEmail: app_state.prismUser.email,
        targetUserId: creator.uid,
        targetUserEmail: '',
        targetName: creator.displayName,
      ),
    );
  }
}

/// The avatar, name and follower count. A tap opens the profile.
class CreatorIdentity extends StatelessWidget {
  const CreatorIdentity({super.key, required this.creator, this.avatarSize = 40});

  final CreatorDirectoryEntry creator;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final String name = creator.displayName;
    return Semantics(
      button: true,
      label: context.l10n.creatorsOpenProfile(name),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrismRadius.sm),
        onTap: () => context.router.push(ProfileRoute(profileIdentifier: creator.uid)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: <Widget>[
              PrismAvatar(url: creator.photoUrl, name: name, size: avatarSize),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
                    Text(
                      context.l10n.accountFollowersCount(creator.followerCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.caption(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A creator's top walls in a row. A tap opens the wall and swipes through the others.
class CreatorWallStrip extends StatelessWidget {
  const CreatorWallStrip({super.key, required this.creator, required this.source, this.count = 4});

  final DirectoryCreator creator;
  final String source;
  final int count;

  @override
  Widget build(BuildContext context) {
    final List<FeedItemEntity> items = <FeedItemEntity>[
      for (final wall in creator.walls.take(count)) FeedItemEntity.prism(id: wall.id, wallpaper: wall),
    ];
    final String name = creator.entry.displayName;
    return Row(
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: PrismFeedLayout.gridSpacing),
          Expanded(
            child: AspectRatio(
              aspectRatio: PrismFeedLayout.gridTileAspectRatio,
              child: i < items.length
                  ? Semantics(
                      label: context.l10n.creatorsWallBy(name),
                      child: WallpaperTile(
                        item: items[i],
                        index: i,
                        crossAxisCount: 4,
                        sourceContext: 'creators_${source}_card',
                        feed: items,
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(PrismRadius.sm),
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A creator in the Creators row or the See all list: four top walls, then who it is and a Follow button.
class CreatorDirectoryCard extends StatelessWidget {
  const CreatorDirectoryCard({super.key, required this.creator, required this.followed, required this.source});

  final DirectoryCreator creator;
  final bool followed;
  final String source;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return VisibleDirectoryCreator(
      uid: creator.uid,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PrismSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CreatorWallStrip(creator: creator, source: source),
              const SizedBox(height: PrismSpace.sm),
              Row(
                children: <Widget>[
                  Expanded(child: CreatorIdentity(creator: creator.entry)),
                  const SizedBox(width: PrismSpace.xs),
                  CreatorFollowButton(creator: creator.entry, followed: followed, source: source),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
