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

/// Creator milestones as one row: the title, a one-line summary, Stats and a chevron. Tapping the row shows the
/// milestones, the rules and the history.
class CreatorProgressView extends StatefulWidget {
  const CreatorProgressView({
    super.key,
    required this.state,
    required this.now,
    this.onRefresh,
    this.initiallyExpanded = false,
  });

  final CreatorProgressState state;
  final DateTime now;
  final VoidCallback? onRefresh;
  final bool initiallyExpanded;

  @override
  State<CreatorProgressView> createState() => _CreatorProgressViewState();
}

class _CreatorProgressViewState extends State<CreatorProgressView> {
  late bool _expanded = widget.initiallyExpanded;

  /// One line under the title: the next milestone, else the refresh state when nothing is saved yet.
  String? _summary(BuildContext context, CreatorProgress? progress) {
    final AppLocalizations l10n = context.l10n;
    if (progress == null) {
      return switch (widget.state.status) {
        CreatorProgressStatus.loading => l10n.economyCreatorRefreshing,
        CreatorProgressStatus.unavailable => l10n.economyCreatorUnavailable,
        _ => null,
      };
    }
    for (final CreatorMetric metric in CreatorMetric.values) {
      final CreatorMilestone? next = progress.next(metric);
      if (next != null) {
        return l10n.economyCreatorMilestoneProgress(_metricLabel(l10n, metric), progress.countFor(metric), next.target);
      }
    }
    return l10n.economyCreatorMilestonesComplete(_metricLabel(l10n, CreatorMetric.values.last));
  }

  @override
  Widget build(BuildContext context) {
    final CreatorProgress? progress = widget.state.progress;
    final String? summary = _summary(context, progress);
    final Duration duration = context.motion(PrismDurations.fast);
    return PrismCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: _expanded,
            // Transparent Material so the ripple draws over the card, not under it.
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(PrismRadius.lg),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, PrismSpace.sm, PrismSpace.sm, PrismSpace.sm),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Semantics(
                              header: true,
                              child: Text(
                                context.l10n.economyCreatorMilestones,
                                style: PrismTextStyles.rowTitle(context),
                              ),
                            ),
                            // Open, the milestone rows below repeat the count.
                            if (summary != null && (!_expanded || progress == null))
                              Text(
                                summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: PrismTextStyles.caption(context),
                              ),
                          ],
                        ),
                      ),
                      const StatsEntryButton(source: 'rewards'),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: duration,
                        child: Icon(Icons.expand_more_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, PrismSpace.sm), child: _body(context, progress))
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, CreatorProgress? progress) {
    final DateTime now = widget.now;
    final bool stale = widget.state.status == CreatorProgressStatus.unavailable;
    final VoidCallback? onRefresh = widget.onRefresh;
    final CreatorWeek? current = progress?.week(now);
    final CreatorProgressStatus status = widget.state.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The summary row already names the state when nothing is saved.
        if (progress != null && status == CreatorProgressStatus.loading)
          Text(context.l10n.economyCreatorRefreshing, style: PrismTextStyles.caption(context)),
        if (status == CreatorProgressStatus.cached)
          Text(context.l10n.economyCreatorSavedRefresh, style: PrismTextStyles.caption(context)),
        if (progress != null && stale)
          Text(context.l10n.economyCreatorSavedUnavailable, style: PrismTextStyles.caption(context)),
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
            shape: const Border(),
            collapsedShape: const Border(),
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
        if (onRefresh != null && (widget.state.status == CreatorProgressStatus.cached || stale))
          // Shifted by the ghost button's own padding so the label lines up with the text above.
          Transform.translate(
            offset: Offset(Directionality.of(context) == TextDirection.rtl ? PrismSpace.md : -PrismSpace.md, 0),
            child: PrismButton(
              label: context.l10n.economyCreatorRefresh,
              variant: PrismButtonVariant.ghost,
              size: PrismButtonSize.compact,
              onPressed: onRefresh,
            ),
          ),
      ],
    );
  }
}

String _metricLabel(AppLocalizations l10n, CreatorMetric metric) =>
    metric == CreatorMetric.approvedWalls ? l10n.economyCreatorApprovedWalls : l10n.economyCreatorQualifyingMembers;

class _Milestone extends StatelessWidget {
  const _Milestone({required this.progress, required this.metric});

  final CreatorProgress progress;
  final CreatorMetric metric;

  @override
  Widget build(BuildContext context) {
    final CreatorMilestone? next = progress.next(metric);
    final String label = _metricLabel(context.l10n, metric);
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
