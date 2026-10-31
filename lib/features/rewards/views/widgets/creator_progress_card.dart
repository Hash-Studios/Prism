import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_stats/views/widgets/stats_entry_button.dart';
import 'package:Prism/features/rewards/domain/creator_progress.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

class CreatorProgressCard extends StatelessWidget {
  const CreatorProgressCard({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<CreatorProgressState>(
    valueListenable: CoinsService.instance.creatorNotifier,
    builder: (context, state, _) => CreatorProgressView(
      state: state,
      now: DateTime.now().toUtc(),
      onRefresh: CoinsService.instance.refreshCreatorProgress,
    ),
  );
}

class CreatorProgressView extends StatelessWidget {
  const CreatorProgressView({super.key, required this.state, required this.now, this.onRefresh});

  final CreatorProgressState state;
  final DateTime now;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final CreatorProgress? progress = state.progress;
    final bool stale = state.status == CreatorProgressStatus.unavailable;
    final CreatorWeek? current = progress?.week(now);
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const StatsEntryButton(source: 'rewards'),
          Text(context.l10n.economyCreatorMilestones, style: PrismTextStyles.eyebrow(context)),
          const SizedBox(height: PrismSpace.sm),
          if (state.status == CreatorProgressStatus.loading)
            Text(context.l10n.economyCreatorRefreshing, style: PrismTextStyles.caption(context)),
          if (state.status == CreatorProgressStatus.cached)
            Text(context.l10n.economyCreatorSavedRefresh, style: PrismTextStyles.caption(context)),
          if (stale)
            Text(
              progress == null ? context.l10n.economyCreatorUnavailable : context.l10n.economyCreatorSavedUnavailable,
              style: PrismTextStyles.caption(context),
            ),
          if (progress == null) ...<Widget>[
            Text(context.l10n.economyCreatorIntro, style: PrismTextStyles.body(context)),
          ] else ...<Widget>[
            Text(
              context.l10n.economyCreatorNewMembersThisWeek(current!.newMembers),
              style: PrismTextStyles.rowTitle(context),
            ),
            const SizedBox(height: PrismSpace.xs),
            Text(
              creatorWeekDates(now, context.l10n, Localizations.localeOf(context).toLanguageTag()),
              style: PrismTextStyles.caption(context),
            ),
            Text(
              context.l10n.economyCreatorThisWeekSummary(current.approvedWalls, current.xp),
              style: PrismTextStyles.caption(context),
            ),
            const SizedBox(height: PrismSpace.sm),
            for (final CreatorMetric metric in CreatorMetric.values) _Milestone(progress: progress, metric: metric),
          ],
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: PrismSpace.xs),
              title: Text(context.l10n.economyCreatorWhatCounts, style: PrismTextStyles.rowTitle(context)),
              children: <Widget>[
                if (progress != null) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.l10n.economyCreatorTrackingSince(
                        creatorDate(progress.trackedSince, Localizations.localeOf(context).toLanguageTag()),
                      ),
                      style: PrismTextStyles.caption(context),
                    ),
                  ),
                  const SizedBox(height: PrismSpace.xs),
                  _WeekFeedback(
                    title: context.l10n.economyLastWeek,
                    date: now.subtract(const Duration(days: 7)),
                    progress: progress,
                  ),
                  const SizedBox(height: PrismSpace.sm),
                ],
                Text(context.l10n.economyCreatorRules, style: PrismTextStyles.body(context)),
              ],
            ),
          ),
          if (onRefresh != null)
            TextButton(
              onPressed: state.status == CreatorProgressStatus.loading ? null : onRefresh,
              child: Text(context.l10n.economyCreatorRefresh),
            ),
        ],
      ),
    );
  }
}

class _Milestone extends StatelessWidget {
  const _Milestone({required this.progress, required this.metric});

  final CreatorProgress progress;
  final CreatorMetric metric;

  @override
  Widget build(BuildContext context) {
    final CreatorMilestone? next = progress.next(metric);
    final String label = metric == CreatorMetric.approvedWalls
        ? context.l10n.economyCreatorApprovedWalls
        : context.l10n.economyCreatorQualifyingMembers;
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            next == null
                ? context.l10n.economyCreatorMilestonesComplete(label)
                : context.l10n.economyCreatorMilestoneProgress(label, progress.countFor(metric), next.target),
            style: PrismTextStyles.rowTitle(context),
          ),
          if (next != null) ...<Widget>[
            Text(context.l10n.economyCreatorNextMilestone(next.xp), style: PrismTextStyles.caption(context)),
            const SizedBox(height: PrismSpace.xxs),
            Semantics(
              label: context.l10n.economyCreatorMilestoneSemantics(label),
              value: context.l10n.economyCreatorProgressSemantics(progress.countFor(metric), next.target),
              child: LinearProgressIndicator(
                value: (progress.countFor(metric) / next.target).clamp(0, 1),
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekFeedback extends StatelessWidget {
  const _WeekFeedback({required this.title, required this.date, required this.progress});

  final String title;
  final DateTime date;
  final CreatorProgress progress;

  @override
  Widget build(BuildContext context) {
    final CreatorWeek week = progress.week(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: PrismTextStyles.rowTitle(context)),
        Text(
          creatorWeekDates(date, context.l10n, Localizations.localeOf(context).toLanguageTag()),
          style: PrismTextStyles.caption(context),
        ),
        Text(
          context.l10n.economyCreatorWeekSummary(week.approvedWalls, week.newMembers, week.xp),
          style: PrismTextStyles.caption(context),
        ),
      ],
    );
  }
}
