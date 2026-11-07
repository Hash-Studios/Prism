import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/glint/cover_mosaic.dart';
import 'package:Prism/features/badges/biz/bloc/badges_bloc.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/l10n/l10n.dart';
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
        final List<BadgeInfo> earnedBadges = badgeCatalog.where((BadgeInfo b) => earned.contains(b.id)).toList();
        final int count = earnedBadges.length;
        // Earned first, each half in catalog order.
        final List<BadgeInfo> badges = <BadgeInfo>[
          ...earnedBadges,
          ...badgeCatalog.where((BadgeInfo b) => !earned.contains(b.id)),
        ];
        return Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(context.l10n.economyBadges, style: PrismTextStyles.sectionTitle(context)),
              ),
              const SizedBox(height: 4),
              Text(context.l10n.economyBadgeEarnedCount(count, badges.length), style: PrismTextStyles.caption(context)),
              const SizedBox(height: 12),
              for (int i = 0; i < badges.length; i += 2) ...<Widget>[
                if (i > 0) const SizedBox(height: 12),
                // Both tiles in a row take the taller one's height.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: _BadgeTile(info: badges[i], earned: earned.contains(badges[i].id)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: i + 1 < badges.length
                            ? _BadgeTile(info: badges[i + 1], earned: earned.contains(badges[i + 1].id))
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
      label: context.l10n.economyBadgeSemantics(
        info.name(context.l10n),
        earned ? context.l10n.economyBadgeStatusEarned : context.l10n.economyBadgeStatusLocked,
        info.description(context.l10n),
      ),
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Bundled wallpaper art. Earned: full colour. Locked: grey and dim, plus the lock, so colour is not the
            // only cue.
            SizedBox(
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColorFiltered(
                    colorFilter: earned ? _identity : _grey,
                    child: Image.asset(
                      kCoverMosaicAssets[_coverIndex(info.id)],
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
                    ),
                  ),
                  if (!earned) ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
                  PositionedDirectional(
                    start: 12,
                    bottom: 8,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: earned ? 0.92 : 0.7),
                          ),
                          child: Icon(info.icon, size: 20, color: earned ? Colors.black87 : Colors.black45),
                        ),
                        if (!earned)
                          PositionedDirectional(
                            end: -4,
                            bottom: -4,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.surfaceContainerHighest,
                                border: Border.all(color: cs.surface, width: 1.5),
                              ),
                              child: Icon(Icons.lock_rounded, size: 11, color: cs.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    info.name(context.l10n),
                    style: PrismTextStyles.rowTitle(context).copyWith(color: earned ? null : cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(info.description(context.l10n), style: PrismTextStyles.caption(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _coverIndex(String id) {
  final int i = badgeCatalog.indexWhere((BadgeInfo b) => b.id == id);
  return (i < 0 ? 0 : i) % kCoverMosaicAssets.length;
}

const ColorFilter _identity = ColorFilter.mode(Colors.transparent, BlendMode.dst);
const ColorFilter _grey = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);
