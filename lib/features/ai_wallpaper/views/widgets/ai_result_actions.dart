import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Under the result: save and try another as buttons, set, share and submit as icons.
class AiResultActions extends StatelessWidget {
  const AiResultActions({
    super.key,
    required this.showSet,
    required this.showRefine,
    required this.canSubmit,
    required this.sharing,
    required this.onSet,
    required this.onSave,
    required this.onShare,
    required this.onRefine,
    required this.onSubmit,
  });

  final bool showSet;
  final bool showRefine;
  final bool canSubmit;

  /// True while the share card renders. The share icon shows a spinner and ignores taps.
  final bool sharing;
  final VoidCallback onSet;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onRefine;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: PrismSpace.xs,
      runSpacing: PrismSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        PrismButton(label: l10n.economyAiSave, onPressed: onSave),
        if (showRefine)
          PrismButton(label: l10n.economyAiTryAnother, variant: PrismButtonVariant.tonal, onPressed: onRefine),
        if (showSet)
          PrismIconButton(
            icon: Icons.wallpaper_rounded,
            tooltip: l10n.economyAiSetAsWallpaper,
            onPressed: onSet,
            filled: true,
          ),
        Semantics(
          liveRegion: sharing,
          label: sharing ? l10n.economyAiPreparingShare : null,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              PrismIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: l10n.economyAiShare,
                onPressed: sharing ? null : onShare,
                filled: true,
              ),
              if (sharing)
                IgnorePointer(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
            ],
          ),
        ),
        if (canSubmit)
          Semantics(
            button: true,
            label: l10n.economyAiSubmitForReview,
            excludeSemantics: true,
            onTap: onSubmit,
            child: PrismIconButton(
              icon: Icons.upload_rounded,
              tooltip: l10n.economyAiSubmitForReview,
              onPressed: onSubmit,
              filled: true,
            ),
          ),
      ],
    );
  }
}

/// Shown when a submission may have gone through but was not confirmed.
class AiUnconfirmedNotice extends StatelessWidget {
  const AiUnconfirmedNotice({super.key, required this.onCheck});

  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PrismCard(
      padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.xs, PrismSpace.xs, PrismSpace.xs),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_rounded, size: 20, color: PrismColors.warning),
          const SizedBox(width: PrismSpace.sm),
          Expanded(child: Text(l10n.economyAiSubmissionUnconfirmed, style: PrismTextStyles.body(context))),
          PrismButton(
            label: l10n.economyAiCheckStatus,
            variant: PrismButtonVariant.ghost,
            size: PrismButtonSize.compact,
            onPressed: onCheck,
          ),
        ],
      ),
    );
  }
}
