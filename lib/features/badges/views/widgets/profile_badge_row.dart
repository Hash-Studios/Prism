import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Earned badges as small icons under the bio. Empty when the user has none this app version knows and there is no
/// [leading] item. More than [_maxShown] badges show the first [_maxShown - 1] and a "+N" pill that lists all of them
/// by name.
class ProfileBadgeRow extends StatelessWidget {
  const ProfileBadgeRow({super.key, required this.badgeIds, this.leading});

  final List<String> badgeIds;

  /// Shown first in the same row, for example the Pro pill, so the profile has one meta row.
  final Widget? leading;

  static const int _maxShown = 5;

  void _showAll(BuildContext context, List<BadgeInfo> badges) {
    showPrismSheet<void>(
      context,
      builder: (BuildContext sheetContext) => PrismSheetBody(
        title: sheetContext.l10n.economyBadges,
        child: PrismGroup(
          children: <Widget>[
            for (final BadgeInfo info in badges)
              PrismRow(
                leading: _BadgeDot(info: info),
                title: info.name(sheetContext.l10n),
                subtitle: info.description(sheetContext.l10n),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<BadgeInfo> badges = <BadgeInfo>[
      for (final String id in badgeIds.toSet())
        if (badgeInfo(id) case final BadgeInfo info) info,
    ];
    if (badges.isEmpty && leading == null) return const SizedBox.shrink();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool overflow = badges.length > _maxShown;
    final List<BadgeInfo> shown = overflow ? badges.take(_maxShown - 1).toList(growable: false) : badges;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          ?leading,
          for (final BadgeInfo info in shown)
            Tooltip(
              message: info.name(context.l10n),
              child: Semantics(
                label: context.l10n.economyBadgeName(info.name(context.l10n)),
                excludeSemantics: true,
                child: _BadgeDot(info: info),
              ),
            ),
          if (overflow)
            Semantics(
              button: true,
              label: context.l10n.economyBadges,
              value: '+${badges.length - shown.length}',
              excludeSemantics: true,
              onTap: () => _showAll(context, badges),
              child: PressScale(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: () => _showAll(context, badges),
                  // 44 point tap target around the 32 point pill.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    // No Container alignment: in a Wrap it would stretch the pill to the full row width.
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(PrismRadius.pill),
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          '+${badges.length - shown.length}',
                          style: PrismTextStyles.rowTitle(context).copyWith(color: cs.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot({required this.info});

  final BadgeInfo info;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary.withValues(alpha: 0.14)),
      child: Icon(info.icon, size: 18, color: cs.primary),
    );
  }
}
