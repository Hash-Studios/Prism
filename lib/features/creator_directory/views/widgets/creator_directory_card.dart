import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/views/creator_follow_changes.dart';
import 'package:Prism/features/creator_directory/views/widgets/visible_directory_creator.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
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
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
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

/// Who the creator is and a Follow button. At large text sizes the button moves under the name, so the name keeps
/// its width.
class CreatorFollowRow extends StatelessWidget {
  const CreatorFollowRow({
    super.key,
    required this.creator,
    required this.followed,
    required this.source,
    this.avatarSize = 40,
  });

  final CreatorDirectoryEntry creator;
  final bool followed;
  final String source;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final Widget identity = CreatorIdentity(creator: creator, avatarSize: avatarSize);
    final Widget button = CreatorFollowButton(creator: creator, followed: followed, source: source);
    if (MediaQuery.textScalerOf(context).scale(1) > 1.4) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          identity,
          const SizedBox(height: PrismSpace.xs),
          button,
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: identity),
        const SizedBox(width: PrismSpace.xs),
        button,
      ],
    );
  }
}

/// A creator's top walls in a row. A tap opens the wall and swipes through the others.
class CreatorWallStrip extends StatelessWidget {
  const CreatorWallStrip({super.key, required this.creator, this.count = 4});

  final DirectoryCreator creator;
  final int count;

  @override
  Widget build(BuildContext context) {
    final List<FeedItemEntity> items = <FeedItemEntity>[
      for (final wall in creator.walls.take(count)) FeedItemEntity.prism(id: wall.id, wallpaper: wall),
    ];
    final String label = context.l10n.creatorsWallBy(creator.entry.displayName);
    final Object heroScope = Scrollable.maybeOf(context) ?? context;
    final List<WallpaperFeedTile> tiles = <WallpaperFeedTile>[
      for (final (i, item) in items.indexed) (item: item, index: i, heroTag: prismHeroTag(heroScope, i, item.id)),
    ];
    return Row(
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: PrismFeedLayout.gridSpacing),
          Expanded(
            child: AspectRatio(
              aspectRatio: PrismFeedLayout.gridTileAspectRatio,
              child: i < tiles.length
                  ? PrismWallTile(
                      url: tiles[i].item.thumbnailUrl,
                      fallbackUrl: tiles[i].item.fullUrl,
                      heroTag: tiles[i].heroTag,
                      semanticLabel: label,
                      onTap: () {
                        PrismHaptics.tap();
                        context.router.push(
                          WallpaperDetailRoute(
                            entity: tiles[i].item,
                            heroTag: tiles[i].heroTag,
                            feed: WallpaperFeed(grid: context, tiles: tiles),
                          ),
                        );
                      },
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
              CreatorWallStrip(creator: creator),
              const SizedBox(height: PrismSpace.sm),
              CreatorFollowRow(creator: creator.entry, followed: followed, source: source),
            ],
          ),
        ),
      ),
    );
  }
}
