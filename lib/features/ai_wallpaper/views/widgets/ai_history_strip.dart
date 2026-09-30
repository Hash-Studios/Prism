import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_section.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_decoded_image.dart';
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
                  Expanded(child: Text("Couldn't load your recent wallpapers.", style: PrismTextStyles.body(context))),
                  PrismButton(
                    label: 'Try again',
                    variant: PrismButtonVariant.ghost,
                    size: PrismButtonSize.compact,
                    onPressed: onRetry,
                  ),
                ],
              )
            : Text(
                'Each wallpaper you generate appears here, so you can compare or switch back.',
                style: PrismTextStyles.body(context),
              ),
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
          itemBuilder: (_, int index) => _Thumb(
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
        const PrismSectionHeader(
          title: 'Recent',
          small: true,
          padding: EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xl, PrismSpace.page, PrismSpace.sm),
        ),
        body,
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.record, required this.selected, required this.isPremium, required this.onTap});

  final AiGenerationRecord record;
  final bool selected;
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.xs);
    final String date = DateFormat('d MMM').format(record.createdAt.toLocal());
    return Semantics(
      button: true,
      selected: selected,
      label: 'Generation from $date',
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: context.motion(PrismDurations.fast),
            curve: PrismCurves.enter,
            width: AiHistoryStrip._thumbWidth,
            height: AiHistoryStrip._thumbHeight,
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
                logicalWidth: AiHistoryStrip._thumbWidth,
                logicalHeight: AiHistoryStrip._thumbHeight,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
