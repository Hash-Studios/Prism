import 'dart:io';

import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String appliedTargetLabel(String target) => switch (target) {
  'home' => 'Home screen',
  'lock' => 'Lock screen',
  'both' => 'Both screens',
  _ => target,
};

class AppliedWallpaperTile extends StatelessWidget {
  const AppliedWallpaperTile({super.key, required this.item, required this.onTap});

  final AppliedWallpaper item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String target = appliedTargetLabel(item.target);
    final String date = DateFormat.MMMd().add_jm().format(item.appliedAt.toLocal());
    final Widget placeholder = ColoredBox(color: scheme.surfaceContainerHighest);
    final String thumbnail = item.thumbnailUrl.isEmpty ? item.fullUrl : item.thumbnailUrl;
    final Widget image = thumbnail.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: thumbnail,
            fit: BoxFit.cover,
            memCacheWidth: 400,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          )
        : Image.file(File(thumbnail), fit: BoxFit.cover, cacheWidth: 400, errorBuilder: (_, _, _) => placeholder);
    return Semantics(
      button: true,
      label: 'Set again. $target, $date',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.expand(child: image),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              target,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(color: scheme.secondary),
            ),
            Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.secondary.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
