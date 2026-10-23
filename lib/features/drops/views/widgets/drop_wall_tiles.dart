import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/painters/foil_sheen_painter.dart';
import 'package:Prism/features/drops/views/widgets/drop_chrome.dart';
import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Opens an unlocked wall in the wallpaper detail page. The full url comes from the unlock, not from the Drop doc.
void openDropWall(BuildContext context, DropWall wall, DropUnlock unlock) {
  PrismHaptics.tap();
  final entity = dropWallFeedItem(wall, unlock);
  unawaited(context.router.push(WallpaperDetailRoute(entity: entity)));
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
    ),
    title: wall.title.isEmpty ? null : wall.title,
    review: true,
    firestoreDocumentId: wall.id,
  );
  return PrismFeedItem(id: wall.id, wallpaper: wallpaper);
}

/// The two-column grid of one Drop. Locked tiles are frosted under a seal, owned tiles are sharp. When the Drop is
/// over, locked tiles say "Missed" and cannot be tapped.
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
          final tile = DropWallTile(
            key: ValueKey<String>(wall.id),
            wall: wall,
            serial: dropSerial(index, drop.walls.length),
            busy: busyKey == wall.id,
            quickActionItem: unlock == null ? null : dropWallFeedItem(wall, unlock),
            unlocked: unlock != null,
            missed: unlock == null && !canBuy,
            onTap: unlock != null
                ? () => openDropWall(context, wall, unlock)
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

/// One line under the hero that tells the user a locked wall opens as a preview.
class DropPreviewHint extends StatelessWidget {
  const DropPreviewHint({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color gold = dropEyebrowColor(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpace.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.visibility_outlined, size: 14, color: gold),
          const SizedBox(width: PrismSpace.xs),
          Text(l10n.economyDropTapToPreview, style: dropCapsStyle(size: 10, spacing: 1.8, color: gold)),
        ],
      ),
    );
  }
}

class DropWallTile extends StatefulWidget {
  const DropWallTile({
    super.key,
    required this.wall,
    required this.serial,
    required this.unlocked,
    required this.missed,
    required this.busy,
    required this.onTap,
    this.quickActionItem,
  });

  final DropWall wall;
  final String serial;
  final bool unlocked;
  final bool missed;
  final bool busy;
  final VoidCallback? onTap;
  final FeedItemEntity? quickActionItem;

  @override
  State<DropWallTile> createState() => _DropWallTileState();
}

class _DropWallTileState extends State<DropWallTile> {
  static const double _frostSigma = 14;

  bool _thawing = false;

  @override
  void didUpdateWidget(DropWallTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.unlocked && widget.unlocked) _thawing = true;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String state = widget.unlocked
        ? l10n.economyDropUnlocked
        : widget.missed
        ? l10n.economyDropMissed
        : l10n.economyDropLocked;
    final String label = widget.wall.by.isEmpty
        ? l10n.economyDropWallSemantics(state, widget.serial)
        : l10n.economyDropWallBySemantics(state, widget.serial, widget.wall.by);
    final Widget tile = PrismWallTile(
      url: widget.wall.thumb,
      semanticLabel: label,
      onTap: widget.onTap,
      overlay: _overlay(),
    );
    final FeedItemEntity? item = widget.quickActionItem;
    return item == null ? tile : WallpaperQuickActionRegion(item: item, child: tile);
  }

  Widget _overlay() {
    if (widget.unlocked && !_thawing) return _OwnedMark(serial: widget.serial);
    if (_thawing) {
      return FoilSheen(
        color: DropPalette.sheen,
        once: true,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1, end: 0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          onEnd: () => setState(() => _thawing = false),
          builder: (context, t, _) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _Frost(sigma: _frostSigma * t, scrim: 0.3 * t),
              Opacity(
                opacity: t,
                child: const Center(child: DropSeal()),
              ),
              _OwnedMark(serial: widget.serial),
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _Frost(sigma: _frostSigma, scrim: widget.missed ? 0.6 : 0.3, edge: !widget.missed),
        Center(
          child: widget.busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: DropPalette.gold),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropSeal(struck: widget.missed),
                    if (widget.missed) ...<Widget>[
                      const SizedBox(height: PrismSpace.xs),
                      Text(
                        AppLocalizations.of(context).economyDropMissed,
                        style: dropCapsStyle(size: 10, spacing: 1.8, color: DropPalette.inkMuted),
                      ),
                    ],
                  ],
                ),
        ),
        DropSerialTag(serial: widget.serial),
      ],
    );
  }
}

class _Frost extends StatelessWidget {
  const _Frost({required this.sigma, required this.scrim, this.edge = false});

  final double sigma;
  final double scrim;
  final bool edge;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: PrismWallGrid.tileRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma + 0.001, sigmaY: sigma + 0.001),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: DropPalette.obsidian.withValues(alpha: scrim),
            borderRadius: PrismWallGrid.tileRadius,
            border: edge ? Border.all(color: DropPalette.hairlineStrong, width: 0.8) : null,
          ),
        ),
      ),
    );
  }
}

class _OwnedMark extends StatelessWidget {
  const _OwnedMark({required this.serial});

  final String serial;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DropSerialTag(serial: serial),
        Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Padding(
            padding: const EdgeInsets.all(PrismSpace.xs),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DropPalette.obsidian.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(PrismRadius.xs),
                border: Border.all(color: DropPalette.hairlineStrong, width: 0.8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.check_rounded, size: 12, color: DropPalette.gold),
                    const SizedBox(width: 4),
                    Text(l10n.economyOwned, style: dropCapsStyle(size: 10, spacing: 1.2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
