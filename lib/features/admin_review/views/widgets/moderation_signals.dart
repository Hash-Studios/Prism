import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/wall_moderation.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_signals_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One pill per server flag, most serious first. Nothing when the wall was not checked or came back clear. A tap on
/// any pill opens the detail sheet. Set [onImage] false on a plain surface; the default is for pills over a wallpaper.
class ModerationSignals extends StatelessWidget {
  const ModerationSignals({super.key, required this.moderation, this.onImage = true});

  final WallModeration? moderation;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final WallModeration? found = moderation;
    if (found == null) return const SizedBox.shrink();
    final List<String> labels = moderationPillLabels(context, found);
    if (labels.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String label in labels) _SignalPill(label: label, onImage: onImage, moderation: found),
      ],
    );
  }
}

/// The pill text for each flag that has something to show.
List<String> moderationPillLabels(BuildContext context, WallModeration moderation) {
  final AppLocalizations l10n = context.l10n;
  return <String>[
    for (final ModerationFlag flag in moderation.flags)
      ?switch (flag) {
        ModerationFlag.unsafe =>
          moderation.unsafe.isEmpty ? null : l10n.adminModerationUnsafe(moderation.unsafe.join(', ')),
        ModerationFlag.duplicate =>
          moderation.duplicate == null ? null : l10n.adminModerationDuplicate(moderation.duplicate!.percent),
        ModerationFlag.webMatch =>
          moderation.web.isEmpty
              ? null
              : moderation.web.length == 1
              ? l10n.adminModerationWeb(moderation.web.first.host)
              : l10n.adminModerationWebMore(moderation.web.first.host, moderation.web.length - 1),
        ModerationFlag.logo => moderation.logos.isEmpty ? null : l10n.adminModerationLogo(moderation.logos.first),
        ModerationFlag.text =>
          moderation.words.isEmpty ? null : l10n.adminModerationText(moderation.words.take(2).join(' ')),
      },
  ];
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({required this.label, required this.onImage, required this.moderation});

  final String label;
  final bool onImage;
  final WallModeration moderation;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle style = PrismTextStyles.caption(
      context,
    ).copyWith(color: onImage ? Colors.white : cs.onSurface, fontWeight: FontWeight.w700);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => _open(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxs),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: onImage ? Colors.black.withValues(alpha: 0.45) : cs.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PrismRadius.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: 5),
              child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    PrismHaptics.selection();
    showModerationSignalsSheet(context, moderation);
  }
}
