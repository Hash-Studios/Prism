import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_section.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_decoded_image.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The "Recent" row of past generations. Tapping one shows it at the top of the page.
class AiHistoryStrip extends StatelessWidget {
  const AiHistoryStrip({
    super.key,
    required this.loading,
    required this.failed,
    required this.history,
    required this.selectedId,
    required this.isPremium,
    required this.onSelect,
    required this.onRetry,
  });

  static const double _thumbWidth = 64;
  static const double _thumbHeight = 112;

  final bool loading;
  final bool failed;
  final List<AiGenerationRecord> history;
  final String? selectedId;
  final bool isPremium;
  final ValueChanged<AiGenerationRecord> onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Widget body;
    if (loading && history.isEmpty) {
      body = SizedBox(
        height: _thumbHeight,
        child: PrismSkeleton(
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
            children: <Widget>[
              for (int i = 0; i < 4; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: PrismSpace.xs),
                const PrismBone(width: _thumbWidth, height: _thumbHeight, radius: PrismRadius.xs),
              ],
            ],
          ),
        ),
      );
    } else if (history.isEmpty) {
      body = Padding(
        padding: PrismSpace.pageInsets,
        child: failed
            ? Row(
                children: <Widget>[
                  Expanded(child: Text(l10n.economyAiHistoryFailed, style: PrismTextStyles.body(context))),
                  PrismButton(
                    label: l10n.economyAiTryAgain,
                    variant: PrismButtonVariant.ghost,
                    size: PrismButtonSize.compact,
                    onPressed: onRetry,
                  ),
                ],
              )
            : Text(l10n.economyAiHistoryEmpty, style: PrismTextStyles.body(context)),
      );
    } else {
      body = SizedBox(
        height: _thumbHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
          addAutomaticKeepAlives: false,
          itemCount: history.length,
          separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.xs),
          itemBuilder: (_, int index) => AiGenerationThumb(
            record: history[index],
            selected: history[index].id == selectedId,
            isPremium: isPremium,
            onTap: () => onSelect(history[index]),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismSectionHeader(
          title: l10n.economyAiRecent,
          small: true,
          padding: EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xl, PrismSpace.page, PrismSpace.sm),
        ),
        body,
      ],
    );
  }
}

/// One past generation as a tappable thumbnail. The Recent row and the session strip both use it.
class AiGenerationThumb extends StatelessWidget {
  const AiGenerationThumb({
    super.key,
    required this.record,
    required this.selected,
    required this.isPremium,
    required this.onTap,
    this.width = AiHistoryStrip._thumbWidth,
    this.height = AiHistoryStrip._thumbHeight,
    this.semanticLabel,
  });

  final AiGenerationRecord record;
  final bool selected;
  final bool isPremium;
  final VoidCallback onTap;
  final double width;
  final double height;

  /// Replaces the default label, which names the day it was made.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.xs);
    final String label =
        semanticLabel ??
        l10n.economyAiGenerationFrom(DateFormat.MMMd(l10n.localeName).format(record.createdAt.toLocal()));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: context.motion(PrismDurations.fast),
            curve: PrismCurves.enter,
            width: width,
            height: height,
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.08),
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: AiDecodedImage(
                url: record.displayUrl(isPremium: isPremium),
                logicalWidth: width,
                logicalHeight: height,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
