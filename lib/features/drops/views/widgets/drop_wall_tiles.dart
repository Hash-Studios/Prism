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
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Opens an unlocked wall in the wallpaper detail page. The full url comes from the unlock, not from the Drop doc.
void openDropWall(BuildContext context, DropWall wall, DropUnlock unlock) {
  PrismHaptics.tap();
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
  unawaited(
    context.router.push(
      WallpaperDetailRoute(
        entity: PrismFeedItem(id: wall.id, wallpaper: wallpaper),
      ),
    ),
  );
}

/// The two-column grid of one Drop. Locked tiles are blurred, owned tiles are sharp. When the Drop is over, locked
/// tiles say "Missed" and cannot be tapped.
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
        gridDelegate: PrismWallGrid.delegate(context, columns: 2),
        itemCount: drop.walls.length,
        itemBuilder: (context, index) {
          final DropWall wall = drop.walls[index];
          final DropUnlock? unlock = unlocked[wall.id];
          return DropWallTile(
            wall: wall,
            busy: busyKey == wall.id,
            unlocked: unlock != null,
            missed: unlock == null && !canBuy,
            onTap: unlock != null
                ? () => openDropWall(context, wall, unlock)
                : canBuy
                ? () => onLockedTap(wall)
                : null,
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
    required this.unlocked,
    required this.missed,
    required this.busy,
    required this.onTap,
  });

  final DropWall wall;
  final bool unlocked;
  final bool missed;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String state = unlocked
        ? 'Unlocked'
        : missed
        ? 'Missed'
        : 'Locked';
    final String by = wall.by.isEmpty ? '' : ' by ${wall.by}';
    return PrismWallTile(
      url: wall.thumb,
      semanticLabel: '$state wall$by',
      onTap: onTap,
      overlay: unlocked
          ? const Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(
                padding: EdgeInsets.all(PrismSpace.xs),
                child: PrismTag(label: 'Unlocked', tone: PrismTone.success, icon: Icons.check_rounded),
              ),
            )
          : ClipRRect(
              borderRadius: PrismWallGrid.tileRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Center(
                  child: busy
                      ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : PrismTag(
                          label: missed ? 'Missed' : 'Locked',
                          icon: missed ? Icons.timer_off_outlined : Icons.lock_outline_rounded,
                        ),
                ),
              ),
            ),
    );
  }
}
