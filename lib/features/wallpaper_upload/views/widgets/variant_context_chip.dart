import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/features/wallpaper_upload/biz/variant_seed.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shows which approved wall an upload is a colour variant of, with a control to upload it as a new wallpaper instead.
class VariantContextChip extends StatelessWidget {
  const VariantContextChip({required this.seed, required this.onRemove, super.key});

  final VariantSeed seed;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? title = seed.title?.trim();
    final String label = title == null || title.isEmpty
        ? context.l10n.wallVariantUploadContextUntitled
        : context.l10n.wallVariantUploadContext(title);
    return Container(
      padding: const EdgeInsets.all(PrismSpace.sm),
      decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(PrismRadius.sm)),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(PrismRadius.xs),
            child: SizedBox(
              width: 40,
              height: 40,
              child: CachedNetworkImage(
                cacheManager: PrismImageCache.instance,
                imageUrl: seed.thumbnailUrl,
                fit: BoxFit.cover,
                memCacheWidth: 80,
                placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
                errorWidget: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
              ),
            ),
          ),
          const SizedBox(width: PrismSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface)),
                const SizedBox(height: PrismSpace.xxs),
                Text(
                  context.l10n.wallVariantUploadHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: context.l10n.wallVariantUnlinkTooltip,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
