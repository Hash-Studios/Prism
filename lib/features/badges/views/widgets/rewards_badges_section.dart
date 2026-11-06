import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/badges/biz/bloc/badges_bloc.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How far a locked badge is, from facts the app already has. The thresholds mirror `functions/src/badges.ts`.
typedef BadgeProgress = ({int done, int target});

/// Progress for [id], or null when the app has no local count for it (for example AI spends or challenge wins).
BadgeProgress? badgeProgressFor(
  String id, {
  required int streakBest,
  required int following,
  required int profileSteps,
  required int profileStepsTotal,
}) {
  BadgeProgress of(int done, int target) => (done: done.clamp(0, target), target: target);
  return switch (id) {
    'week_warrior' => of(streakBest, 7),
    'streak_master' => of(streakBest, 28),
    'social_butterfly' => of(following, 10),
    'profile_complete' => of(profileSteps, profileStepsTotal),
    _ => null,
  };
}

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
      builder: (context, state) => ValueListenableBuilder<StreakStatus>(
        valueListenable: CoinsService.instance.streakNotifier,
        builder: (context, streak, _) => _grid(context, state.earnedIds.toSet(), streak),
      ),
    );
  }

  Widget _grid(BuildContext context, Set<String> earned, StreakStatus streak) {
    final ProfileCompletenessStatus profile = ProfileCompletenessEvaluator.evaluate(
      app_state.prismUser,
      defaultProfilePhotoUrl: app_state.defaultProfilePhotoUrl,
    );
    final Map<String, BadgeProgress> progress = <String, BadgeProgress>{
      for (final BadgeInfo b in badgeCatalog)
        if (!earned.contains(b.id))
          if (badgeProgressFor(
                b.id,
                streakBest: streak.best > streak.count ? streak.best : streak.count,
                following: app_state.prismUser.following.length,
                profileSteps: profile.completedSteps,
                profileStepsTotal: profile.totalSteps,
              )
              case final BadgeProgress p)
            b.id: p,
    };
    double share(BadgeInfo b) => switch (progress[b.id]) {
      final BadgeProgress p => p.done / p.target,
      null => -1,
    };
    final List<BadgeInfo> earnedBadges = badgeCatalog.where((BadgeInfo b) => earned.contains(b.id)).toList();
    // Locked badges with progress first, closest to done first; the sort is stable, so ties keep catalog order.
    final List<BadgeInfo> locked = badgeCatalog.where((BadgeInfo b) => !earned.contains(b.id)).toList()
      ..sort((BadgeInfo a, BadgeInfo b) => share(b).compareTo(share(a)));
    // The closest badge leads the section as the next thing to do.
    final BadgeInfo? next = locked.isNotEmpty && progress.containsKey(locked.first.id) ? locked.first : null;
    final List<BadgeInfo> rest = <BadgeInfo>[...earnedBadges, ...locked.skip(next == null ? 0 : 1)];
    Widget tile(BadgeInfo b) => _BadgeTile(info: b, earned: earned.contains(b.id), progress: progress[b.id]);
    return Padding(
      padding: const EdgeInsets.only(top: PrismSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(context.l10n.economyBadges, style: PrismTextStyles.sectionTitle(context)),
          ),
          const SizedBox(height: PrismSpace.xxs),
          Text(
            context.l10n.economyBadgeEarnedCount(earnedBadges.length, badgeCatalog.length),
            style: PrismTextStyles.caption(context),
          ),
          const SizedBox(height: PrismSpace.sm),
          if (next != null) ...<Widget>[
            _BadgeTile(info: next, earned: false, progress: progress[next.id], highlighted: true),
            const SizedBox(height: PrismSpace.sm),
          ],
          for (int i = 0; i < rest.length; i += 2) ...<Widget>[
            if (i > 0) const SizedBox(height: PrismSpace.sm),
            // Both tiles in a row take the taller one's height.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: tile(rest[i])),
                  const SizedBox(width: PrismSpace.sm),
                  Expanded(child: i + 1 < rest.length ? tile(rest[i + 1]) : const SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.info, required this.earned, this.progress, this.highlighted = false});

  final BadgeInfo info;
  final bool earned;
  final BadgeProgress? progress;

  /// The closest badge to earn: full width, the accent ring and an accent bar.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l10n = context.l10n;
    final BadgeProgress? p = progress;
    final Color ink = cs.onSurface.withValues(alpha: 0.5);
    // Earned is full colour; locked shows its own glyph at half ink; the next badge takes the accent.
    final Widget glyph = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned
            ? cs.primary
            : highlighted
            ? cs.primary.withValues(alpha: 0.14)
            : cs.onSurface.withValues(alpha: 0.06),
      ),
      child: Icon(
        info.icon,
        size: 22,
        color: earned
            ? cs.onPrimary
            : highlighted
            ? cs.primary
            : ink,
      ),
    );
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(info.name(l10n), style: PrismTextStyles.rowTitle(context)),
        const SizedBox(height: 2),
        Text(info.description(l10n), style: PrismTextStyles.caption(context)),
        if (p != null) ...<Widget>[
          const SizedBox(height: PrismSpace.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: LinearProgressIndicator(
                  value: p.done / p.target,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                  color: highlighted ? cs.primary : cs.onSurfaceVariant,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(width: PrismSpace.xs),
              Text(
                '${formatLocalizedNumber(p.done, l10n)}/${formatLocalizedNumber(p.target, l10n)}',
                style: PrismTextStyles.caption(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: highlighted ? cs.primary : null,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ],
    );
    final Widget card = PrismCard(
      padding: const EdgeInsets.all(PrismSpace.md),
      child: highlighted
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                glyph,
                const SizedBox(width: PrismSpace.sm),
                Expanded(child: copy),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                glyph,
                const SizedBox(height: PrismSpace.sm - 2),
                copy,
              ],
            ),
    );
    return Semantics(
      label: l10n.economyBadgeSemantics(
        info.name(l10n),
        earned ? l10n.economyBadgeStatusEarned : l10n.economyBadgeStatusLocked,
        info.description(l10n),
      ),
      value: p == null ? null : '${formatLocalizedNumber(p.done, l10n)}/${formatLocalizedNumber(p.target, l10n)}',
      excludeSemantics: true,
      child: highlighted
          ? DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PrismRadius.lg),
                border: Border.all(color: cs.primary, width: 1.5),
              ),
              child: card,
            )
          : card,
    );
  }
}
