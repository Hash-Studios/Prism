import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:flutter/material.dart';

const int _maxRecentlySet = 8;

/// A row of the wallpapers the user set last. A tap opens the set sheet for that wallpaper again.
class RecentlySetRow extends StatelessWidget {
  const RecentlySetRow({super.key, this.items});

  /// Replaces the history store, for tests.
  final List<AppliedWallpaper>? items;

  List<AppliedWallpaper> _recent() {
    final List<AppliedWallpaper> all = items ?? getIt<WallpaperHistoryStore>().items();
    final Set<String> seen = <String>{};
    return all.where((item) => seen.add(item.fullUrl)).take(_maxRecentlySet).toList(growable: false);
  }

  void _setAgain(BuildContext context, AppliedWallpaper item) {
    PrismHaptics.tap();
    unawaited(SetWallpaperFlow.run(context, url: item.fullUrl, thumbnailUrl: item.thumbnailUrl, forceSheet: true));
  }

  Widget _thumbnail(AppliedWallpaper item) {
    final String url = item.thumbnailUrl;
    return url.startsWith('/')
        ? Image.file(File(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
        : PrismImageTile(url: url);
  }

  @override
  Widget build(BuildContext context) {
    final List<AppliedWallpaper> recent = _recent();
    if (recent.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text('Recently set', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary)),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final AppliedWallpaper item = recent[index];
              return Semantics(
                button: true,
                label: 'Set this wallpaper again',
                child: AspectRatio(
                  aspectRatio: 0.6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _thumbnail(item),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(onTap: () => _setAgain(context, item)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
