import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:flutter/material.dart';

/// Earned badges as small icons under the bio. Empty when the user has none this app version knows.
class ProfileBadgeRow extends StatelessWidget {
  const ProfileBadgeRow({super.key, required this.badgeIds});

  final List<String> badgeIds;

  @override
  Widget build(BuildContext context) {
    final List<BadgeInfo> badges = <BadgeInfo>[
      for (final String id in badgeIds.toSet())
        if (badgeInfo(id) case final BadgeInfo info) info,
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final BadgeInfo info in badges)
            Tooltip(
              message: info.name,
              child: Semantics(
                label: '${info.name} badge',
                excludeSemantics: true,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary.withValues(alpha: 0.14)),
                  child: Icon(info.icon, size: 18, color: cs.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
