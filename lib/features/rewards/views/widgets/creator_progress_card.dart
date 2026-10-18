import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/rewards/domain/creator_progress.dart';
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
          Text('CREATOR MILESTONES', style: PrismTextStyles.eyebrow(context)),
          const SizedBox(height: PrismSpace.sm),
          if (state.status == CreatorProgressStatus.loading)
            Text('Refreshing creator progress…', style: PrismTextStyles.caption(context)),
          if (state.status == CreatorProgressStatus.cached)
            Text('Saved progress. Refresh to update.', style: PrismTextStyles.caption(context)),
          if (stale)
            Text(
              progress == null ? 'Creator progress is unavailable.' : 'Saved progress. Refresh is unavailable.',
              style: PrismTextStyles.caption(context),
            ),
          if (progress == null) ...<Widget>[
            Text(
              'Earn XP when your wallpapers are approved and new members favourite them. Progress appears after your first qualifying contribution.',
              style: PrismTextStyles.body(context),
            ),
          ] else ...<Widget>[
            Text(
              '${current!.newMembers} new members favourited your wallpapers this week',
              style: PrismTextStyles.rowTitle(context),
            ),
            const SizedBox(height: PrismSpace.xs),
            Text(creatorWeekDates(now), style: PrismTextStyles.caption(context)),
            Text(
              '${current.approvedWalls} eligible wallpapers approved · ${current.xp} milestone XP',
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
              title: Text('What counts & history', style: PrismTextStyles.rowTitle(context)),
              children: <Widget>[
                if (progress != null) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tracking since ${creatorDate(progress.trackedSince)} UTC',
                      style: PrismTextStyles.caption(context),
                    ),
                  ),
                  const SizedBox(height: PrismSpace.xs),
                  _WeekFeedback(title: 'Last week', date: now.subtract(const Duration(days: 7)), progress: progress),
                  const SizedBox(height: PrismSpace.sm),
                ],
                Text(
                  'Approved wallpapers must be your own eligible uploads. Older uploads may be ineligible if Prism cannot verify the original upload. Each other member counts once across all your eligible work, on their first qualifying favourite. They must be signed in, have a verified email and an account at least seven days old. Your own favourites do not count. Counts are historical, not your current audience. Removing favourites does not undo XP. Creator milestones earn extra XP. Weeks run Monday to Sunday in UTC; delayed activity can appear in a later week.',
                  style: PrismTextStyles.body(context),
                ),
              ],
            ),
          ),
          if (onRefresh != null)
            TextButton(
              onPressed: state.status == CreatorProgressStatus.loading ? null : onRefresh,
              child: const Text('Refresh progress'),
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
    final String label = metric == CreatorMetric.approvedWalls ? 'Approved wallpapers' : 'Qualifying members';
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            next == null ? '$label milestones complete' : '$label: ${progress.countFor(metric)} / ${next.target}',
            style: PrismTextStyles.rowTitle(context),
          ),
          if (next != null) ...<Widget>[
            Text('Next milestone: +${next.xp} XP', style: PrismTextStyles.caption(context)),
            const SizedBox(height: PrismSpace.xxs),
            Semantics(
              label: '$label milestone',
              value: '${progress.countFor(metric)} of ${next.target}',
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
        Text(creatorWeekDates(date), style: PrismTextStyles.caption(context)),
        Text(
          '${week.approvedWalls} eligible wallpapers approved · ${week.newMembers} new qualifying members · ${week.xp} milestone XP',
          style: PrismTextStyles.caption(context),
        ),
      ],
    );
  }
}
