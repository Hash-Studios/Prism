import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_decoded_image.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Shows the wall a remix starts from, above the prompt field. [onDrop] removes the link and keeps the prompt.
class AiRemixChip extends StatelessWidget {
  const AiRemixChip({super.key, required this.seed, required this.onDrop});

  final AiRemixSeed seed;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String title = seed.title ?? l10n.wallRemixUntitled;
    final String creator = seed.creatorName ?? l10n.wallRemixUnknownCreator;
    final String label = l10n.wallRemixingChip(title, creator);
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(PrismRadius.md)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(PrismRadius.xs),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: seed.thumbnailUrl.isEmpty
                      ? ColoredBox(
                          color: cs.surfaceContainerHighest,
                          child: Icon(Icons.image_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
                        )
                      : AiDecodedImage(url: seed.thumbnailUrl, logicalWidth: 32, logicalHeight: 32),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PrismTextStyles.rowTitle(context),
                ),
              ),
              IconButton(
                onPressed: onDrop,
                tooltip: l10n.wallRemixDropLinkTooltip,
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
