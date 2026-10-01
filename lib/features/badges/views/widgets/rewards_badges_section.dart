import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/badges/biz/bloc/badges_bloc.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Badges": every badge, earned ones in colour. Opening it asks the server to award any new badge.
class RewardsBadgesSection extends StatelessWidget {
  const RewardsBadgesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BadgesBloc>(
      create: (_) => getIt<BadgesBloc>()..add(const BadgesLoaded()),
      child: const _BadgesBody(),
    );
  }
}

class _BadgesBody extends StatelessWidget {
  const _BadgesBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BadgesBloc, BadgesState>(
      builder: (context, state) {
        final Set<String> earned = state.earnedIds.toSet();
        final int count = badgeCatalog.where((BadgeInfo b) => earned.contains(b.id)).length;
        return Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(header: true, child: Text('Badges', style: PrismTextStyles.sectionTitle(context))),
              const SizedBox(height: 4),
              Text('$count of ${badgeCatalog.length} earned', style: PrismTextStyles.caption(context)),
              const SizedBox(height: 12),
              for (int i = 0; i < badgeCatalog.length; i += 2) ...<Widget>[
                if (i > 0) const SizedBox(height: 12),
                // Both tiles in a row take the taller one's height.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: _BadgeTile(info: badgeCatalog[i], earned: earned.contains(badgeCatalog[i].id)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: i + 1 < badgeCatalog.length
                            ? _BadgeTile(info: badgeCatalog[i + 1], earned: earned.contains(badgeCatalog[i + 1].id))
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.info, required this.earned});

  final BadgeInfo info;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      label: '${info.name}, ${earned ? 'earned' : 'locked'}. ${info.description}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned ? cs.primary : cs.onSurface.withValues(alpha: 0.08),
              ),
              child: Icon(
                earned ? info.icon : Icons.lock_outline_rounded,
                size: 22,
                color: earned ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              info.name,
              style: PrismTextStyles.rowTitle(
                context,
              ).copyWith(color: earned ? null : cs.onSurface.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 2),
            Text(info.description, style: PrismTextStyles.caption(context)),
          ],
        ),
      ),
    );
  }
}
