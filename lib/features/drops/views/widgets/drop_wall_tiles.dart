import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_chrome.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Opens an unlocked wall in the wallpaper detail page. The full url comes from the unlock, not from the Drop doc.
void openDropWall(BuildContext context, DropWall wall, DropUnlock unlock, {String? heroTag}) {
  PrismHaptics.tap();
  final entity = dropWallFeedItem(wall, unlock);
  unawaited(context.router.push(WallpaperDetailRoute(entity: entity, heroTag: heroTag)));
}

PrismFeedItem dropWallFeedItem(DropWall wall, DropUnlock unlock) {
  final PrismWallpaper wallpaper = PrismWallpaper(
    core: WallpaperCore(
      id: wall.id,
      source: WallpaperSource.prism,
      fullUrl: unlock.url,
      thumbnailUrl: wall.thumb,
      resolution: wall.resolution.isEmpty ? null : wall.resolution,
      authorName: wall.by.isEmpty ? null : wall.by,
      authorUid: wall.creatorUid.isEmpty ? null : wall.creatorUid,
    ),
    title: wall.title.isEmpty ? null : wall.title,
    review: true,
    firestoreDocumentId: wall.id,
  );
  return PrismFeedItem(id: wall.id, wallpaper: wallpaper);
}

/// The two-column grid of one Drop. Every wall shows in full. A locked wall has a lock and its price in the corner.
/// When the Drop is over, a locked wall dims, says "Missed" and cannot be tapped.
class DropWallGrid extends StatelessWidget {
  const DropWallGrid({
    super.key,
    required this.drop,
    required this.unlocked,
    required this.canBuy,
    required this.onLockedTap,
    this.busyKey,
  });

  final DropEntity drop;
  final Map<String, DropUnlock> unlocked;
  final bool canBuy;
  final String? busyKey;
  final void Function(DropWall wall) onLockedTap;

  @override
  Widget build(BuildContext context) {
    final int price = drop.wallPrice(isPro: app_state.prismUser.premium);
    return SliverPadding(
      padding: PrismWallGrid.padding,
      sliver: SliverGrid.builder(
        gridDelegate: PrismWallGrid.delegate(
          context,
          columns: largeTileGridColumns(MediaQuery.sizeOf(context).width),
          footerHeight: favouriteFooterHeight,
        ),
        itemCount: drop.walls.length,
        itemBuilder: (context, index) {
          final DropWall wall = drop.walls[index];
          final DropUnlock? unlock = unlocked[wall.id];
          final String heroTag = prismHeroTag(context, index, 'drop-grid-${drop.weekKey}-${wall.id}');
          final tile = DropWallTile(
            key: ValueKey<String>(wall.id),
            wall: wall,
            position: context.l10n.economyDropPosition(index + 1, drop.walls.length),
            price: price,
            busy: busyKey == wall.id,
            quickActionItem: unlock == null ? null : dropWallFeedItem(wall, unlock),
            heroTag: unlock == null ? null : heroTag,
            unlocked: unlock != null,
            missed: unlock == null && !canBuy,
            onTap: unlock != null
                ? () => openDropWall(context, wall, unlock, heroTag: heroTag)
                : canBuy
                ? () => onLockedTap(wall)
                : null,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tile),
              if (unlock != null)
                FavouriteWallpaperFooter(item: dropWallFeedItem(wall, unlock))
              else
                const SizedBox(height: favouriteFooterHeight),
            ],
          );
        },
      ),
    );
  }
}

class DropWallTile extends StatelessWidget {
  const DropWallTile({
    super.key,
    required this.wall,
    required this.position,
    required this.price,
    required this.unlocked,
    required this.missed,
    required this.busy,
    required this.onTap,
    this.quickActionItem,
    this.heroTag,
  });

  final DropWall wall;

  /// "3 of 9", for screen readers.
  final String position;
  final int price;
  final bool unlocked;
  final bool missed;
  final bool busy;
  final VoidCallback? onTap;
  final FeedItemEntity? quickActionItem;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String state = unlocked
        ? l10n.economyDropUnlocked
        : missed
        ? l10n.economyDropMissed
        : l10n.economyDropLocked;
    final String label = wall.by.isEmpty
        ? l10n.economyDropWallSemantics(state, position)
        : l10n.economyDropWallBySemantics(state, position, wall.by);
    final Widget badge = unlocked
        ? DropTileBadge(key: const ValueKey<String>('owned'), icon: Icons.check_rounded, label: l10n.economyOwned)
        : missed
        ? DropTileBadge(key: const ValueKey<String>('missed'), icon: Icons.lock_rounded, label: l10n.economyDropMissed)
        : DropTileBadge(
            key: const ValueKey<String>('locked'),
            icon: Icons.lock_rounded,
            label: formatLocalizedNumber(price, l10n),
            coin: true,
          );
    final Widget tile = PrismWallTile(
      url: wall.thumb,
      semanticLabel: label,
      heroTag: heroTag,
      onTap: onTap,
      overlay: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (missed) ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: Padding(
              padding: const EdgeInsets.all(PrismSpace.xs),
              child: AnimatedSwitcher(duration: context.motion(PrismDurations.base), child: badge),
            ),
          ),
          if (busy)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: Padding(
                  padding: EdgeInsets.all(PrismSpace.sm),
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final FeedItemEntity? item = quickActionItem;
    return item == null ? tile : WallpaperQuickActionRegion(item: item, child: tile);
  }
}
