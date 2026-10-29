import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The result's actions: Apply as the one primary button, and save, share, submit and try another as icons.
class AiResultActions extends StatelessWidget {
  const AiResultActions({
    super.key,
    required this.showSave,
    required this.showRefine,
    required this.canSubmit,
    required this.sharing,
    required this.applying,
    required this.onApply,
    required this.onSave,
    required this.onShare,
    required this.onRefine,
    required this.onSubmit,
  });

  /// False on iOS, where Apply already saves to Photos.
  final bool showSave;
  final bool showRefine;
  final bool canSubmit;

  /// True while the share card renders. The share icon shows a spinner and ignores taps.
  final bool sharing;

  /// True while Apply gets the wallpaper ready. Apply shows a spinner and ignores taps.
  final bool applying;
  final VoidCallback onApply;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onRefine;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Widget> secondary = <Widget>[
      if (showSave) ...<Widget>[
        PrismIconButton(icon: Icons.download_rounded, tooltip: l10n.economyAiSave, onPressed: onSave, filled: true),
        const SizedBox(width: PrismSpace.xs),
      ],
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
      if (canSubmit) ...<Widget>[
        const SizedBox(width: PrismSpace.xs),
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
      if (showRefine) ...<Widget>[
        const SizedBox(width: PrismSpace.xs),
        PrismIconButton(
          icon: Icons.auto_fix_high_rounded,
          tooltip: l10n.economyAiTryAnother,
          onPressed: onRefine,
          filled: true,
        ),
      ],
    ];
    final Widget apply = PrismButton(
      label: l10n.aiResultApply,
      icon: Icons.wallpaper_rounded,
      expand: true,
      loading: applying,
      onPressed: onApply,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final int icons = 1 + (showSave ? 1 : 0) + (canSubmit ? 1 : 0) + (showRefine ? 1 : 0);
        final double applyMin = MediaQuery.textScalerOf(context).scale(_applyMinWidth);
        if (icons * (44 + PrismSpace.xs) + PrismSpace.xs + applyMin <= box.maxWidth) {
          return Row(
            children: <Widget>[
              ...secondary,
              const SizedBox(width: PrismSpace.sm),
              Expanded(child: apply),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: secondary),
            const SizedBox(height: PrismSpace.sm),
            apply,
          ],
        );
      },
    );
  }

  /// Apply's icon, label and padding at 1x text. Narrower than this, Apply takes its own row.
  static const double _applyMinWidth = 132;
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
