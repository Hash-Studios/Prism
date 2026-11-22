import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism_loader.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The result's actions: Apply as the one primary button, and save, share, submit, try another and report as icons.
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
    required this.onReport,
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

  /// Opens the report sheet. Google Play requires an in-app way to flag AI output.
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    VoidCallback tap(VoidCallback action) => () {
      PrismHaptics.tap();
      action();
    };
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
              onPressed: sharing ? null : tap(onShare),
              filled: true,
            ),
            if (sharing) IgnorePointer(child: const Center(child: PrismLoader(size: 22))),
          ],
        ),
      ),
      if (canSubmit) ...<Widget>[
        const SizedBox(width: PrismSpace.xs),
        Semantics(
          button: true,
          label: l10n.economyAiSubmitForReview,
          excludeSemantics: true,
          onTap: tap(onSubmit),
          child: PrismIconButton(
            icon: Icons.upload_rounded,
            tooltip: l10n.economyAiSubmitForReview,
            onPressed: tap(onSubmit),
            filled: true,
          ),
        ),
      ],
      if (showRefine) ...<Widget>[
        const SizedBox(width: PrismSpace.xs),
        PrismIconButton(
          icon: Icons.auto_fix_high_rounded,
          tooltip: l10n.economyAiTryAnother,
          onPressed: tap(onRefine),
          filled: true,
        ),
      ],
      const SizedBox(width: PrismSpace.xs),
      // showContentReportSheet plays the tap haptic.
      PrismIconButton(icon: Icons.flag_rounded, tooltip: l10n.coreReport, onPressed: onReport, filled: true),
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
        final int icons = 2 + (showSave ? 1 : 0) + (canSubmit ? 1 : 0) + (showRefine ? 1 : 0);
        final double applyMin = _applyMinWidth(context, l10n.aiResultApply);
        // Android pads each icon's tap target to 48.
        final double iconWidth = Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded
            ? kMinInteractiveDimension
            : 44;
        if (icons * iconWidth + (icons - 1) * PrismSpace.xs + PrismSpace.sm + applyMin <= box.maxWidth) {
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
            Wrap(
              spacing: PrismSpace.xs,
              runSpacing: PrismSpace.xs,
              alignment: WrapAlignment.center,
              children: secondary.where((Widget child) => child is! SizedBox).toList(),
            ),
            const SizedBox(height: PrismSpace.sm),
            apply,
          ],
        );
      },
    );
  }

  /// Apply's padding, icon and measured label. Narrower than this, Apply takes its own row, so a long translation
  /// such as German `Übernehmen` is never cut off.
  static double _applyMinWidth(BuildContext context, String label) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: PrismTextStyles.button),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double width = 2 * PrismSpace.xl + 20 + PrismSpace.xs + painter.width;
    painter.dispose();
    return width;
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
