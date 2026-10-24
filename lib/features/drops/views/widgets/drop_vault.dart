import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_chrome.dart';
import 'package:Prism/features/drops/views/widgets/drop_wall_tiles.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// "Your vault": one strip of owned walls per past Drop.
class DropVault extends StatelessWidget {
  const DropVault({super.key, required this.drops, required this.unlocked});

  final List<DropEntity> drops;
  final Map<String, DropUnlock> unlocked;

  static const double _tileWidth = 104;
  static const double _tileHeight = 184;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (drops.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _GoldHeader(title: l10n.economyDropYourVault),
        for (final DropEntity drop in drops) ...<Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(PrismWallGrid.margin + 4, PrismSpace.xxs, 0, PrismSpace.xxs),
            child: Text(drop.displayTitle(context.l10n), style: PrismTextStyles.caption(context)),
          ),
          SizedBox(
            height: _tileHeight + favouriteFooterHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: PrismWallGrid.padding,
              itemCount: drop.walls.where((w) => unlocked.containsKey(w.id)).length,
              separatorBuilder: (_, _) => const SizedBox(width: PrismWallGrid.spacing),
              itemBuilder: (context, index) {
                final DropWall wall = drop.walls.where((w) => unlocked.containsKey(w.id)).elementAt(index);
                final String heroTag = prismHeroTag(
                  Scrollable.maybeOf(context) ?? context,
                  index,
                  'drop-vault-${drop.weekKey}-${wall.id}',
                );
                return SizedBox(
                  width: _tileWidth,
                  child: FavouriteWallpaperCard(
                    item: dropWallFeedItem(wall, unlocked[wall.id]!),
                    child: PrismWallTile(
                      url: wall.thumb,
                      heroTag: heroTag,
                      semanticLabel: wall.by.isEmpty
                          ? l10n.economyDropUnlockedWall
                          : l10n.economyDropUnlockedWallBy(wall.by),
                      onTap: () => openDropWall(context, wall, unlocked[wall.id]!, heroTag: heroTag),
                      overlay: DropSerialTag(serial: dropSerial(drop.walls.indexOf(wall), drop.count)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// "Past drops": one row per ended Drop, opening its grid.
class PastDropRows extends StatelessWidget {
  const PastDropRows({super.key, required this.drops, required this.unlocked});

  final List<DropEntity> drops;
  final Map<String, DropUnlock> unlocked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (drops.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _GoldHeader(title: l10n.economyDropPastDrops),
        Padding(
          padding: PrismWallGrid.padding,
          child: PrismGroup(
            children: <Widget>[
              for (final DropEntity drop in drops)
                PrismRow(
                  title: drop.displayTitle(context.l10n),
                  subtitle: l10n.economyDropUnlockedCount(
                    drop.walls.where((w) => unlocked.containsKey(w.id)).length,
                    drop.count,
                  ),
                  onTap: () {
                    PrismHaptics.tap();
                    unawaited(context.router.push(DropDetailRoute(weekKey: drop.weekKey)));
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoldHeader extends StatelessWidget {
  const _GoldHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          PrismWallGrid.margin + 4,
          PrismSpace.xl,
          PrismSpace.md,
          PrismSpace.xs,
        ),
        child: Text(title, style: dropCapsStyle(color: dropEyebrowColor(context))),
      ),
    );
  }
}
