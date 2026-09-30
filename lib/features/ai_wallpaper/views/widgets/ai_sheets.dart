import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_field.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_decoded_image.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks the user to confirm sharing [record]. Resolves with the metadata to submit, or null if they cancel.
///
/// The title, description, category and tags come from [metadata] and [prompt]. They are not edited here.
Future<AiSubmissionMetadata?> showAiSubmitSheet(
  BuildContext context, {
  required AiGenerationRecord? record,
  required bool isPremium,
  required AiSubmissionMetadata metadata,
  required String prompt,
  required AiStylePreset style,
}) {
  final String quoted = (metadata.title.isNotEmpty ? metadata.title : prompt).split(',').first.trim();
  return showPrismSheet<AiSubmissionMetadata>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => PrismSheetBody(
      title: 'Share with the community?',
      message: 'Moderators review submissions before they appear in Prism. Only share work you have rights to.',
      scrollable: true,
      actions: <Widget>[
        PrismButton(
          label: 'Submit for review',
          icon: Icons.upload_rounded,
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(_submissionFrom(metadata, prompt, style)),
        ),
        PrismButton(
          label: 'Cancel',
          variant: PrismButtonVariant.ghost,
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ],
      child: record == null
          ? null
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 64,
                  height: 112,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PrismRadius.xs),
                      border: Border.all(color: Theme.of(sheetContext).colorScheme.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(PrismRadius.xs),
                      child: AiDecodedImage(
                        url: record.displayUrl(isPremium: isPremium),
                        logicalWidth: 64,
                        logicalHeight: 112,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: PrismSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '"$quoted"',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: PrismTextStyles.rowTitle(sheetContext),
                      ),
                      const SizedBox(height: PrismSpace.xxs),
                      Text(style.label, style: PrismTextStyles.caption(sheetContext)),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}

AiSubmissionMetadata _submissionFrom(AiSubmissionMetadata metadata, String prompt, AiStylePreset style) {
  final List<String> autoTags = <String>[
    ...prompt
        .split(' ')
        .take(3)
        .map((String w) => w.toLowerCase().replaceAll(RegExp('[^a-z]'), ''))
        .where((String w) => w.length > 2),
    ...metadata.tags,
  ];
  return (
    title: metadata.title.isNotEmpty ? metadata.title : prompt.split(',').first.trim(),
    description: metadata.description.isNotEmpty ? metadata.description : prompt,
    category: metadata.category.isNotEmpty ? metadata.category : style.label,
    tags: autoTags.toSet().toList(),
  );
}

/// Asks what to change about the current wallpaper. Closes itself, then calls [onSubmit].
Future<void> showAiRefineSheet(
  BuildContext context, {
  required TextEditingController controller,
  required int maxChars,
  required int cost,
  required bool enabled,
  required VoidCallback onSubmit,
}) {
  return showPrismSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => PrismSheetBody(
      title: 'Refine this wallpaper',
      message: 'Say what should change. We keep the rest of the composition as close as we can.',
      scrollable: true,
      actions: <Widget>[
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => PrismButton(
            label: 'Generate refinement',
            expand: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const PrismCoinIcon(size: 18),
                const SizedBox(width: PrismSpace.xxs),
                Text('$cost'),
              ],
            ),
            onPressed: !enabled || controller.text.trim().isEmpty
                ? null
                : () {
                    Navigator.of(sheetContext).pop();
                    onSubmit();
                  },
          ),
        ),
      ],
      child: PrismTextField(
        controller: controller,
        autofocus: true,
        hint: 'Darker sky, warmer palette, softer edges…',
        minLines: 2,
        maxLines: 4,
        inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(maxChars)],
      ),
    ),
  );
}
