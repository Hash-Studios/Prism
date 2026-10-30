import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_field.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_wallpaper_helpers.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_decoded_image.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

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
  final AppLocalizations l10n = AppLocalizations.of(context);
  final String quoted = (metadata.title.isNotEmpty ? metadata.title : prompt).split(',').first.trim();
  return showPrismSheet<AiSubmissionMetadata>(
    context,
    builder: (sheetContext) => PrismSheetBody(
      title: l10n.economyAiShareWithCommunity,
      message: l10n.economyAiShareReviewNotice,
      actions: <Widget>[
        PrismButton(
          label: l10n.economyAiSubmitForReview,
          icon: Icons.upload_rounded,
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(_submissionFrom(metadata, prompt, style)),
        ),
        PrismButton(
          label: l10n.economyCancel,
          variant: PrismButtonVariant.ghost,
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (record != null)
            Row(
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
                      Text(aiStyleLabel(l10n, style), style: PrismTextStyles.caption(sheetContext)),
                    ],
                  ),
                ),
              ],
            ),
          if (record?.challengeId != null) ...[
            const SizedBox(height: PrismSpace.md),
            Text(l10n.challengeContext(record!.challengeTheme ?? '')),
          ],
          const SizedBox(height: PrismSpace.md),
          Text(l10n.economyAiSubmitPromptNotice, style: PrismTextStyles.caption(sheetContext)),
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

/// Asks what to change for a new version of the current wallpaper. Closes itself, then calls [onSubmit].
Future<void> showAiRefineSheet(
  BuildContext context, {
  required TextEditingController controller,
  required int maxChars,
  required int cost,
  required bool enabled,
  required VoidCallback onSubmit,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return showPrismSheet<void>(
    context,
    dismissKeyboardOnDrag: true,
    builder: (sheetContext) => PrismSheetBody(
      title: l10n.economyAiTryAnotherVersion,
      message: l10n.economyAiRefineExplanation,
      actions: <Widget>[
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => PrismButton(
            label: l10n.economyAiGenerateAnother,
            expand: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const PrismCoinIcon(size: 18),
                const SizedBox(width: PrismSpace.xxs),
                Text(formatLocalizedNumber(cost, l10n)),
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
        hint: l10n.economyAiRemixHint,
        minLines: 2,
        maxLines: 4,
        maxLength: maxChars,
      ),
    ),
  );
}

/// Asks before the first follow-up chip spends coins, and again only when the price goes up. True means go ahead.
Future<bool> showAiFollowUpConfirmSheet(BuildContext context, {required int cost}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool? confirmed = await showPrismSheet<bool>(
    context,
    builder: (sheetContext) => PrismSheetBody(
      title: l10n.aiFollowUpConfirmTitle,
      message: l10n.aiFollowUpConfirmBody(cost),
      actions: <Widget>[
        PrismButton(
          label: l10n.aiFollowUpConfirmAction,
          expand: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PrismCoinIcon(size: 18),
              const SizedBox(width: PrismSpace.xxs),
              Text(formatLocalizedNumber(cost, l10n)),
            ],
          ),
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
        PrismButton(
          label: l10n.economyCancel,
          variant: PrismButtonVariant.ghost,
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
