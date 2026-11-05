import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/user_search/data/photo_search_service.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The picked photo above photo search results: a small thumbnail, what the search matches, the photo's main colours,
/// a Clear button, and a note that says where the photo went.
class PhotoSearchChip extends StatelessWidget {
  const PhotoSearchChip({super.key, required this.photo, required this.onClear});

  final PhotoQuery photo;
  final VoidCallback onClear;

  String _note(BuildContext context) => switch (photo.labelsStatus) {
    PhotoLabelsStatus.found => context.l10n.searchPhotoSentNote,
    PhotoLabelsStatus.guest => context.l10n.searchPhotoGuestNote,
    PhotoLabelsStatus.capped => context.l10n.searchPhotoCappedNote(photoSearchDailyCap),
    PhotoLabelsStatus.unavailable => context.l10n.searchPhotoUnavailableNote,
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String colours = photo.palette
        .map((entry) => prismPaletteColorDisplayName(entry.color, context.l10n))
        .join(', ');
    // With large text, Clear goes under the note so the labels keep the full width.
    final bool stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final Widget clear = Tooltip(
      message: context.l10n.searchPhotoClearTooltip,
      excludeFromSemantics: true,
      child: Semantics(
        label: context.l10n.searchPhotoClearTooltip,
        excludeSemantics: true,
        button: true,
        onTap: onClear,
        child: PrismButton(
          label: context.l10n.searchPhotoClear,
          onPressed: onClear,
          variant: PrismButtonVariant.tonal,
          size: PrismButtonSize.compact,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Semantics(
              image: true,
              label: context.l10n.searchPhotoChipLabel,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PrismRadius.xs),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PrismRadius.xs),
                    border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                  ),
                  child: Image.memory(
                    photo.preview,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    cacheWidth: 132,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: PrismSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    photo.labels.isEmpty
                        ? context.l10n.searchPhotoColourMatches
                        : context.l10n.searchPhotoMatchesFor(photo.labels.take(3).join(', ').toLowerCase()),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.rowTitle(context),
                  ),
                  const SizedBox(height: PrismSpace.xxs),
                  Semantics(
                    label: context.l10n.searchPhotoMainColours(colours),
                    child: ExcludeSemantics(
                      child: Row(
                        children: <Widget>[
                          for (final PaletteShare entry in photo.palette)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: PrismSpace.xxs),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: entry.color.color,
                                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.3)),
                                ),
                                child: const SizedBox.square(dimension: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!stacked) ...<Widget>[const SizedBox(width: PrismSpace.xs), clear],
          ],
        ),
        const SizedBox(height: PrismSpace.xs),
        Text(_note(context), style: PrismTextStyles.caption(context)),
        if (stacked) ...<Widget>[const SizedBox(height: PrismSpace.xs), clear],
      ],
    );
  }
}
