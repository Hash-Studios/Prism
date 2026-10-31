import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/creator_stats/biz/bloc/creator_stats_bloc.j.dart';
import 'package:Prism/features/creator_stats/domain/creator_stats.dart';
import 'package:Prism/features/deep_link_input/domain/deep_link_input_workflow.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

String statsLabel(BuildContext context, StatsMetric metric) => switch (metric) {
  StatsMetric.views => context.l10n.statsViews,
  StatsMetric.saves => context.l10n.statsSaves,
  StatsMetric.sets => context.l10n.statsSets,
  StatsMetric.downloads => context.l10n.statsDownloads,
  StatsMetric.shares => context.l10n.statsShares,
  StatsMetric.folderAdds => context.l10n.statsFolderAdds,
  StatsMetric.remixes => context.l10n.statsRemixes,
};
String statsNumber(BuildContext context, int? value) =>
    value == null ? '–' : NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(value);

@RoutePage()
class CreatorStatsPage extends StatefulWidget {
  const CreatorStatsPage({super.key, this.source = 'link'});
  final String source;
  @override
  State<CreatorStatsPage> createState() => _CreatorStatsPageState();
}

class _CreatorStatsPageState extends State<CreatorStatsPage> {
  @override
  void initState() {
    super.initState();
    analytics.track(CreatorStatsOpenedEvent(source: widget.source));
  }

  @override
  Widget build(BuildContext context) => BlocSelector<SessionBloc, SessionState, String?>(
    selector: (state) => state.session.loggedIn ? state.session.userId : null,
    builder: (context, owner) => owner == null
        ? Scaffold(
            appBar: AppBar(title: Text(context.l10n.statsTitle)),
            body: SignInPrompt(feature: context.l10n.statsTitle),
          )
        : BlocProvider(
            key: ValueKey(owner),
            create: (_) => getIt<CreatorStatsBloc>()..add(const CreatorStatsEvent.load()),
            child: CreatorStatsView(ownerUid: owner),
          ),
  );
}

class CreatorStatsView extends StatelessWidget {
  const CreatorStatsView({super.key, required this.ownerUid});
  final String ownerUid;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.statsTitle)),
    body: SafeArea(
      child: BlocBuilder<CreatorStatsBloc, CreatorStatsState>(
        builder: (context, state) {
          if (state.loading) return Center(child: CircularProgressIndicator(semanticsLabel: context.l10n.statsLoading));
          if (state.failed) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.statsError),
                    TextButton(
                      onPressed: () => context.read<CreatorStatsBloc>().add(const CreatorStatsEvent.load()),
                      child: Text(context.l10n.statsRetry),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = state.data;
          if (data == null) return const SizedBox.shrink();
          if (data.approvedWallCount == 0) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Center(child: Glint()),
                const SizedBox(height: PrismSpace.md),
                Text(context.l10n.statsEmptyTitle, style: PrismTextStyles.screenTitle(context)),
                Text(context.l10n.statsEmptyBody),
                TextButton(
                  onPressed: () => context.router.push(DeepLinkInputRoute(workflow: DeepLinkInputWorkflow.uploadWall)),
                  child: Text(context.l10n.statsUpload),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(context.l10n.statsWeekNote, style: PrismTextStyles.caption(context)),
              for (final metric in StatsMetric.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _MetricSummary(metric: metric, weeks: data.weeks, total: data.totals[metric]),
                ),
              const SizedBox(height: 24),
              _Selector(
                metric: state.metric,
                onSelected: (metric) {
                  context.read<CreatorStatsBloc>().add(CreatorStatsEvent.select(metric));
                  analytics.track(CreatorStatsMetricSwitchedEvent(metric: metric.name));
                },
              ),
              StatsChart(weeks: data.weeks, metric: state.metric),
              Text(context.l10n.statsHistoryNote, style: PrismTextStyles.caption(context)),
              const SizedBox(height: 24),
              Text(context.l10n.statsTopWalls, style: PrismTextStyles.sectionTitle(context)),
              for (final wall in data.ranked(state.metric))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: wall.thumbnailUrl.isEmpty
                      ? null
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            wall.thumbnailUrl,
                            width: 48,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => const SizedBox(width: 48),
                          ),
                        ),
                  title: Text(wall.title.isEmpty ? context.l10n.statsUntitled : wall.title),
                  subtitle: Text(
                    context.l10n.statsWallValue(
                      statsLabel(context, state.metric),
                      statsNumber(context, wall.weeks.last.metrics[state.metric]),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    analytics.track(CreatorWallStatsOpenedEvent(wallId: wall.wallId));
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WallStatsPage(ownerUid: ownerUid, wall: wall, initialMetric: state.metric),
                      ),
                    );
                  },
                ),
              Text(context.l10n.statsCountingNote, style: PrismTextStyles.caption(context)),
              Text(
                context.l10n.statsUpdated(
                  DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(data.asOf),
                ),
                style: PrismTextStyles.caption(context),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({required this.metric, required this.weeks, required this.total});
  final StatsMetric metric;
  final List<StatsWeek> weeks;
  final int? total;
  @override
  Widget build(BuildContext context) {
    final current = weeks.last.metrics[metric];
    final previous = weeks[weeks.length - 2].metrics[metric];
    final delta = current == null || previous == null ? null : current - previous;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(statsLabel(context, metric), style: PrismTextStyles.rowTitle(context)),
        Text(
          context.l10n.statsComparison(statsNumber(context, current), statsNumber(context, previous)),
          style: PrismTextStyles.body(context),
        ),
        Text(context.l10n.statsTotal(statsNumber(context, total)), style: PrismTextStyles.caption(context)),
        if (delta != null)
          Row(
            children: [
              Icon(
                delta > 0
                    ? Icons.north_east
                    : delta < 0
                    ? Icons.south_east
                    : Icons.east,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  context.l10n.statsChange('${delta > 0 ? '+' : ''}${statsNumber(context, delta)}'),
                  style: PrismTextStyles.caption(context),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Selector extends StatelessWidget {
  const _Selector({required this.metric, required this.onSelected});
  final StatsMetric metric;
  final ValueChanged<StatsMetric> onSelected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final value in StatsMetric.values)
        ChoiceChip(
          label: Text(statsLabel(context, value)),
          selected: value == metric,
          onSelected: (_) => onSelected(value),
        ),
    ],
  );
}

class WallStatsPage extends StatefulWidget {
  const WallStatsPage({super.key, required this.ownerUid, required this.wall, required this.initialMetric});
  final String ownerUid;
  final WallStats wall;
  final StatsMetric initialMetric;
  @override
  State<WallStatsPage> createState() => _WallStatsPageState();
}

class _WallStatsPageState extends State<WallStatsPage> {
  late StatsMetric metric = widget.initialMetric;
  @override
  Widget build(BuildContext context) => BlocSelector<SessionBloc, SessionState, String?>(
    selector: (state) => state.session.loggedIn ? state.session.userId : null,
    builder: (context, owner) => owner != widget.ownerUid
        ? Scaffold(
            appBar: AppBar(title: Text(context.l10n.statsTitle)),
            body: Center(child: Text(context.l10n.statsUnavailable)),
          )
        : Scaffold(
            appBar: AppBar(title: Text(widget.wall.title.isEmpty ? context.l10n.statsUntitled : widget.wall.title)),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Selector(
                    metric: metric,
                    onSelected: (value) {
                      setState(() => metric = value);
                      analytics.track(CreatorStatsMetricSwitchedEvent(metric: value.name));
                    },
                  ),
                  _MetricSummary(metric: metric, weeks: widget.wall.weeks, total: widget.wall.totals[metric]),
                  StatsChart(weeks: widget.wall.weeks, metric: metric),
                  Text(context.l10n.statsHistoryNote),
                  Text(context.l10n.statsCountingNote),
                ],
              ),
            ),
          ),
  );
}

class StatsChart extends StatelessWidget {
  const StatsChart({super.key, required this.weeks, required this.metric});
  final List<StatsWeek> weeks;
  final StatsMetric metric;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final summary = weeks
        .map(
          (week) => context.l10n.statsChartWeek(
            DateFormat.yMMMd(locale).format(week.start),
            week.metrics[metric] == null ? context.l10n.statsUnavailable : statsNumber(context, week.metrics[metric]),
          ),
        )
        .join('; ');
    return Semantics(
      label: context.l10n.statsChartSummary(statsLabel(context, metric), summary),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: CustomPaint(
                  painter: _Bars(
                    values: weeks.map((w) => w.metrics[metric]).toList(),
                    color: Theme.of(context).colorScheme.primary,
                    baseline: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final week in weeks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      context.l10n.statsChartWeek(
                        DateFormat.yMMMd(locale).format(week.start),
                        week.metrics[metric] == null
                            ? context.l10n.statsUnavailable
                            : statsNumber(context, week.metrics[metric]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bars extends CustomPainter {
  _Bars({required this.values, required this.color, required this.baseline});
  final List<int?> values;
  final Color color;
  final Color baseline;
  @override
  void paint(Canvas canvas, Size size) {
    final maximum = values.whereType<int>().fold<int>(1, math.max);
    final step = size.width / values.length;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final x = i * step + step * .2;
      final width = step * .6;
      if (value == null) {
        canvas.drawLine(
          Offset(x, size.height - 8),
          Offset(x + width, size.height - 8),
          Paint()
            ..color = baseline
            ..strokeWidth = 2,
        );
        continue;
      }
      final height = value == 0 ? 2.0 : math.max(3.0, (size.height - 8) * value / maximum);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - height, width, height), const Radius.circular(4)),
        Paint()..color = color.withValues(alpha: value == 0 ? 0.35 : 1.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Bars old) => old.values != values || old.color != color || old.baseline != baseline;
}
