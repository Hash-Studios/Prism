import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The meta row under the bio: [leading] (for example the Pro pill), then one chip that counts the earned badges and
/// opens a sheet that lists them by name, then [trailing] (for example the rank). Empty when the user has no badge this
/// app version knows and there is no [leading] or [trailing] item.
class ProfileBadgeRow extends StatelessWidget {
  const ProfileBadgeRow({super.key, required this.badgeIds, this.leading, this.trailing});

  final List<String> badgeIds;

  /// Shown first in the same row, for example the Pro pill, so the profile has one meta row.
  final Widget? leading;

  /// Shown last in the same row, for example the rank chip.
  final Widget? trailing;

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
    if (badges.isEmpty && leading == null && trailing == null) return const SizedBox.shrink();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String label = context.l10n.profileBadgeCount(badges.length);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          ?leading,
          if (badges.isNotEmpty)
            Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              onTap: () => _showAll(context, badges),
              child: PressScale(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: () => _showAll(context, badges),
                  // 44 point tap target around the pill. No Container alignment: in a Wrap it would fill the row.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: Center(
                      widthFactor: 1,
                      // The same pill as the Pro badge, so the two read as one row.
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(PrismRadius.pill),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.xxs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.military_tech_rounded, size: 14, color: cs.onPrimaryContainer),
                              const SizedBox(width: PrismSpace.xxs),
                              Flexible(
                                child: Text(
                                  label,
                                  style: PrismTextStyles.caption(
                                    context,
                                  ).copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ?trailing,
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
