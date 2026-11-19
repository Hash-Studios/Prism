import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/creator_fund/biz/bloc/creator_fund_bloc.j.dart';
import 'package:Prism/features/creator_fund/views/widgets/creator_fund_row.dart';
import 'package:Prism/features/creator_stats/biz/bloc/creator_stats_bloc.j.dart';
import 'package:Prism/features/creator_stats/domain/creator_stats.dart';
import 'package:Prism/features/creator_stats/domain/stats_period.dart';
import 'package:Prism/features/deep_link_input/domain/deep_link_input_workflow.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
        ? PrismPage(
            title: context.l10n.statsTitle,
            body: SignInPrompt(feature: context.l10n.statsTitle),
          )
        : MultiBlocProvider(
            key: ValueKey(owner),
            providers: [
              BlocProvider<CreatorStatsBloc>(
                create: (_) => getIt<CreatorStatsBloc>()..add(const CreatorStatsEvent.load()),
              ),
              BlocProvider<CreatorFundBloc>(
                create: (_) => getIt<CreatorFundBloc>()..add(const CreatorFundEvent.load()),
              ),
            ],
            child: CreatorStatsView(ownerUid: owner),
          ),
  );
}

class CreatorStatsView extends StatefulWidget {
  const CreatorStatsView({super.key, required this.ownerUid});
  final String ownerUid;
  @override
  State<CreatorStatsView> createState() => _CreatorStatsViewState();
}

class _CreatorStatsViewState extends State<CreatorStatsView> {
  static const int _topWallCount = 5;
  StatsPeriod period = StatsPeriod.thisWeek;
  bool showAllWalls = false;

  @override
  Widget build(BuildContext context) => PrismPage(
    title: context.l10n.statsTitle,
    body: BlocBuilder<CreatorStatsBloc, CreatorStatsState>(
      builder: (context, state) {
        if (state.loading) {
          return Semantics(label: context.l10n.statsLoading, child: PrismSkeleton.cards());
        }
        if (state.failed) {
          return GlintState(
            kind: GlintStateKind.error,
            title: context.l10n.statsError,
            actionLabel: context.l10n.statsRetry,
            onAction: () => context.read<CreatorStatsBloc>().add(const CreatorStatsEvent.load()),
          );
        }
        final data = state.data;
        if (data == null) return const SizedBox.shrink();
        if (data.approvedWallCount == 0) {
          return GlintState(
            kind: GlintStateKind.empty,
            title: context.l10n.statsEmptyTitle,
            body: context.l10n.statsEmptyBody,
            actionLabel: context.l10n.statsUpload,
            onAction: () => context.router.push(DeepLinkInputRoute(workflow: DeepLinkInputWorkflow.uploadWall)),
          );
        }
        final ranked = data.ranked(state.metric, period);
        final shown = showAllWalls ? ranked : ranked.take(_topWallCount);
        return ListView(
          padding: const EdgeInsets.all(PrismSpace.page),
          children: [
            StatsOverview(
              weeks: data.weeks,
              totals: data.totals,
              metric: state.metric,
              period: period,
              onPeriod: (value) => setState(() => period = value),
              onMetric: (metric) {
                context.read<CreatorStatsBloc>().add(CreatorStatsEvent.select(metric));
                analytics.track(CreatorStatsMetricSwitchedEvent(metric: metric.name));
              },
            ),
            const SizedBox(height: PrismSpace.xxl),
            Text(context.l10n.statsTopWalls, style: PrismTextStyles.sectionTitle(context)),
            const SizedBox(height: PrismSpace.xs),
            for (final wall in shown)
              _TopWallRow(
                wall: wall,
                metric: state.metric,
                period: period,
                onTap: () {
                  analytics.track(CreatorWallStatsOpenedEvent(wallId: wall.wallId));
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WallStatsPage(
                        ownerUid: widget.ownerUid,
                        wall: wall,
                        initialMetric: state.metric,
                        initialPeriod: period,
                      ),
                    ),
                  );
                },
              ),
            if (ranked.length > _topWallCount)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: PrismButton(
                  label: showAllWalls
                      ? context.l10n.statsShowFewerWalls
                      : context.l10n.statsShowAllWalls(statsNumber(context, ranked.length)),
                  variant: PrismButtonVariant.ghost,
                  size: PrismButtonSize.compact,
                  onPressed: () => setState(() => showAllWalls = !showAllWalls),
                ),
              ),
            const SizedBox(height: PrismSpace.xxl),
            _TipsSummary(tips: data.tips, walls: data.walls),
            const SizedBox(height: PrismSpace.md),
            const CreatorFundRow(),
            const SizedBox(height: PrismSpace.xxl),
            _AboutNumbers(
              notes: [
                context.l10n.statsWeekNote,
                context.l10n.statsHistoryNote,
                context.l10n.statsCountingNote,
                context.l10n.statsUpdated(
                  DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(data.asOf),
                ),
              ],
            ),
            const SizedBox(height: PrismSpace.xxl),
          ],
        );
      },
    ),
  );
}

/// Period switch, hero number, chart and metric tiles for one eight-week history.
class StatsOverview extends StatelessWidget {
  const StatsOverview({
    super.key,
    required this.weeks,
    required this.totals,
    required this.metric,
    required this.period,
    required this.onPeriod,
    required this.onMetric,
  });
  final List<StatsWeek> weeks;
  final Map<StatsMetric, int?> totals;
  final StatsMetric metric;
  final StatsPeriod period;
  final ValueChanged<StatsPeriod> onPeriod;
  final ValueChanged<StatsMetric> onMetric;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PrismSegmented<StatsPeriod>(
        values: StatsPeriod.values,
        selected: period,
        labelOf: (value) => switch (value) {
          StatsPeriod.thisWeek => context.l10n.statsPeriodThisWeek,
          StatsPeriod.lastWeek => context.l10n.statsPeriodLastWeek,
          StatsPeriod.fourWeeks => context.l10n.statsPeriodFourWeeks,
        },
        onChanged: onPeriod,
      ),
      const SizedBox(height: PrismSpace.xl),
      _Hero(metric: metric, period: period, weeks: weeks, total: totals[metric]),
      const SizedBox(height: PrismSpace.lg),
      StatsChart(weeks: weeks, metric: metric, highlight: period.indexes(weeks.length).toSet()),
      const SizedBox(height: PrismSpace.xl),
      _MetricTiles(weeks: weeks, period: period, selected: metric, onSelected: onMetric),
    ],
  );
}

/// The change from the previous window, for example "+212 (+20%)", or null when either side is unavailable.
/// The percentage is left out when it would round to 0%.
String? statsChange(BuildContext context, int? current, int? previous) {
  if (current == null || previous == null) return null;
  final delta = current - previous;
  if (delta == 0) return context.l10n.statsNoChange;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final sign = delta > 0 ? '+' : '';
  final number = '$sign${NumberFormat.decimalPattern(locale).format(delta)}';
  if (previous == 0 || (delta / previous).abs() < 0.005) return number;
  return '$number ($sign${NumberFormat.percentPattern(locale).format(delta / previous)})';
}

class _Hero extends StatelessWidget {
  const _Hero({required this.metric, required this.period, required this.weeks, required this.total});
  final StatsMetric metric;
  final StatsPeriod period;
  final List<StatsWeek> weeks;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = period.value(weeks, metric);
    final previous = period.previous(weeks, metric);
    final change = statsChange(context, current, previous);
    final delta = current == null || previous == null ? 0 : current - previous;
    final comparison = change == null
        ? context.l10n.statsNoComparison
        : switch (period) {
            StatsPeriod.thisWeek => context.l10n.statsVsLastWeek(change),
            StatsPeriod.lastWeek => context.l10n.statsVsWeekBefore(change),
            StatsPeriod.fourWeeks => context.l10n.statsVsFourWeeksBefore(change),
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(statsLabel(context, metric).toUpperCase(), style: PrismTextStyles.eyebrow(context)),
        const SizedBox(height: PrismSpace.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(statsNumber(context, current), style: PrismTextStyles.numeral(context, 52)),
        ),
        const SizedBox(height: PrismSpace.xs),
        Row(
          children: [
            if (delta != 0) ...[
              Icon(
                delta > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: MediaQuery.textScalerOf(context).scale(18),
                color: cs.primary,
              ),
              const SizedBox(width: PrismSpace.xxs),
            ],
            Flexible(
              child: Text(
                comparison,
                style: PrismTextStyles.rowTitle(context).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ),
        const SizedBox(height: PrismSpace.xxs),
        Text(context.l10n.statsTotal(statsNumber(context, total)), style: PrismTextStyles.caption(context)),
      ],
    );
  }
}

class _MetricTiles extends StatelessWidget {
  const _MetricTiles({required this.weeks, required this.period, required this.selected, required this.onSelected});
  final List<StatsWeek> weeks;
  final StatsPeriod period;
  final StatsMetric selected;
  final ValueChanged<StatsMetric> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(10) >= 16;
      final columns = largeText ? 1 : (constraints.maxWidth >= 560 ? 3 : 2);
      const metrics = StatsMetric.values;
      return Column(
        children: [
          for (var start = 0; start < metrics.length; start += columns)
            Padding(
              padding: EdgeInsets.only(top: start == 0 ? 0 : PrismSpace.xs),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = start; i < start + columns; i++) ...[
                      if (i > start) const SizedBox(width: PrismSpace.xs),
                      Expanded(
                        child: i < metrics.length
                            ? _MetricTile(
                                metric: metrics[i],
                                value: period.value(weeks, metrics[i]),
                                change: statsChange(
                                  context,
                                  period.value(weeks, metrics[i]),
                                  period.previous(weeks, metrics[i]),
                                ),
                                selected: metrics[i] == selected,
                                onTap: () => onSelected(metrics[i]),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.metric,
    required this.value,
    required this.change,
    required this.selected,
    required this.onTap,
  });
  final StatsMetric metric;
  final int? value;
  final String? change;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: PressScale(
        child: _Activatable(
          onActivate: selected ? null : onTap,
          radius: PrismRadius.md,
          child: AnimatedContainer(
            duration: context.motion(PrismDurations.fast),
            curve: PrismCurves.move,
            padding: const EdgeInsets.all(PrismSpace.sm),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(PrismRadius.md),
              border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statsLabel(context, metric),
                  style: PrismTextStyles.caption(context).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: PrismSpace.xxs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    statsNumber(context, value),
                    style: PrismTextStyles.sectionTitle(
                      context,
                    ).copyWith(fontSize: 24, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
                if (change != null)
                  Text(
                    change!,
                    style: PrismTextStyles.caption(
                      context,
                    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A custom control that takes taps, keyboard focus and Enter or Space, with a focus ring.
class _Activatable extends StatefulWidget {
  const _Activatable({required this.onActivate, required this.child, this.radius = PrismRadius.xs});
  final VoidCallback? onActivate;
  final Widget child;
  final double radius;
  @override
  State<_Activatable> createState() => _ActivatableState();
}

class _ActivatableState extends State<_Activatable> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    enabled: widget.onActivate != null,
    onShowFocusHighlight: (value) => setState(() => focused = value),
    actions: <Type, Action<Intent>>{
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onActivate?.call();
          return null;
        },
      ),
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onActivate,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: focused ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2) : null,
        ),
        child: widget.child,
      ),
    ),
  );
}

class _TopWallRow extends StatelessWidget {
  const _TopWallRow({required this.wall, required this.metric, required this.period, required this.onTap});
  final WallStats wall;
  final StatsMetric metric;
  final StatsPeriod period;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => PrismRow(
      padding: const EdgeInsets.symmetric(vertical: PrismSpace.xs),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(PrismRadius.xs),
        child: SizedBox(
          width: 40,
          height: 54,
          child: wall.thumbnailUrl.isEmpty
              ? ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHigh)
              : Image.network(
                  wall.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) =>
                      ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHigh),
                ),
        ),
      ),
      title: wall.title.isEmpty ? context.l10n.statsUntitled : wall.title,
      subtitle: statsLabel(context, metric),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
        child: Text(
          statsNumber(context, period.value(wall.weeks, metric)),
          textAlign: TextAlign.end,
          style: PrismTextStyles.rowTitle(context).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
      onTap: onTap,
    ),
  );
}

/// Tips all time, per week with tips (newest first) and per wall, most coins first.
class _TipsSummary extends StatelessWidget {
  const _TipsSummary({required this.tips, required this.walls});
  final CreatorTips tips;
  final List<WallStats> walls;
  @override
  Widget build(BuildContext context) {
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final Map<String, String> titles = {for (final wall in walls) wall.wallId: wall.title};
    final List<MapEntry<String, TipTally>> byWall = tips.walls.entries.toList()
      ..sort((a, b) => b.value.coins.compareTo(a.value.coins));
    final List<TipWeek> weeks = tips.weeks.reversed.where((week) => week.count > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.statsTips, style: PrismTextStyles.sectionTitle(context)),
        const SizedBox(height: PrismSpace.xs),
        PrismCard(
          child: tips.count == 0
              ? Text(context.l10n.statsTipsEmpty, style: PrismTextStyles.body(context))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.statsTipsTotal(tips.count, tips.coins),
                      style: PrismTextStyles.cardTitle(context),
                    ),
                    if (weeks.isNotEmpty) const SizedBox(height: PrismSpace.sm),
                    for (final week in weeks)
                      Text(
                        context.l10n.statsTipsWeek(DateFormat.MMMd(locale).format(week.start), week.count, week.coins),
                        style: PrismTextStyles.body(context),
                      ),
                    if (byWall.isNotEmpty) const SizedBox(height: PrismSpace.sm),
                    for (final entry in byWall)
                      Text(
                        '${(titles[entry.key] ?? '').isEmpty ? context.l10n.statsUntitled : titles[entry.key]}: '
                        '${context.l10n.statsTipsWall(entry.value.count, entry.value.coins)}',
                        style: PrismTextStyles.body(context),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AboutNumbers extends StatelessWidget {
  const _AboutNumbers({required this.notes});
  final List<String> notes;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(context.l10n.statsAboutTitle, style: PrismTextStyles.rowTitle(context)),
      for (final note in notes) ...[
        const SizedBox(height: PrismSpace.xs),
        Text(note, style: PrismTextStyles.caption(context)),
      ],
    ],
  );
}

class WallStatsPage extends StatefulWidget {
  const WallStatsPage({
    super.key,
    required this.ownerUid,
    required this.wall,
    required this.initialMetric,
    this.initialPeriod = StatsPeriod.thisWeek,
  });
  final String ownerUid;
  final WallStats wall;
  final StatsMetric initialMetric;
  final StatsPeriod initialPeriod;
  @override
  State<WallStatsPage> createState() => _WallStatsPageState();
}

class _WallStatsPageState extends State<WallStatsPage> {
  late StatsMetric metric = widget.initialMetric;
  late StatsPeriod period = widget.initialPeriod;
  @override
  Widget build(BuildContext context) => BlocSelector<SessionBloc, SessionState, String?>(
    selector: (state) => state.session.loggedIn ? state.session.userId : null,
    builder: (context, owner) => owner != widget.ownerUid
        ? PrismPage(
            title: context.l10n.statsTitle,
            body: Center(child: Text(context.l10n.statsUnavailable)),
          )
        : PrismPage(
            title: widget.wall.title.isEmpty ? context.l10n.statsUntitled : widget.wall.title,
            body: ListView(
              padding: const EdgeInsets.all(PrismSpace.page),
              children: [
                StatsOverview(
                  weeks: widget.wall.weeks,
                  totals: widget.wall.totals,
                  metric: metric,
                  period: period,
                  onPeriod: (value) => setState(() => period = value),
                  onMetric: (value) {
                    setState(() => metric = value);
                    analytics.track(CreatorStatsMetricSwitchedEvent(metric: value.name));
                  },
                ),
                const SizedBox(height: PrismSpace.xxl),
                _AboutNumbers(
                  notes: [context.l10n.statsWeekNote, context.l10n.statsHistoryNote, context.l10n.statsCountingNote],
                ),
                const SizedBox(height: PrismSpace.xxl),
              ],
            ),
          ),
  );
}

/// The smallest even step of 2, 4, 6, 8, 10, 12, 16 or 20 times a power of ten at or above [peak].
int statsAxisTop(int peak) {
  for (var magnitude = 1; ; magnitude *= 10) {
    for (final factor in const [2, 4, 6, 8, 10, 12, 16, 20]) {
      if (factor * magnitude >= peak) return factor * magnitude;
    }
  }
}

/// Eight weekly bars with a value axis, week labels and tap-to-read. Each bar is a screen-reader button.
class StatsChart extends StatefulWidget {
  const StatsChart({super.key, required this.weeks, required this.metric, this.highlight = const {}});
  final List<StatsWeek> weeks;
  final StatsMetric metric;

  /// Week indexes drawn at full strength; the rest are muted. Empty draws every bar at full strength.
  final Set<int> highlight;
  @override
  State<StatsChart> createState() => _StatsChartState();
}

class _StatsChartState extends State<StatsChart> {
  int? picked;

  @override
  void didUpdateWidget(covariant StatsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metric != widget.metric || !setEquals(oldWidget.highlight, widget.highlight)) picked = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weeks = widget.weeks;
    final values = [for (final week in weeks) week.metrics[widget.metric]];
    final newest = widget.highlight.isEmpty ? weeks.length - 1 : widget.highlight.reduce(math.max);
    final selected = (picked ?? newest).clamp(0, weeks.length - 1);
    String weekText(int i) => l10n.statsChartWeek(
      DateFormat.yMMMd(locale).format(weeks[i].start),
      values[i] == null ? l10n.statsUnavailable : statsNumber(context, values[i]),
    );
    final peak = values.whereType<int>().fold<int>(0, math.max);
    if (values.every((value) => value == 0)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(PrismSpace.lg),
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(PrismRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsChartEmpty, style: PrismTextStyles.rowTitle(context)),
            const SizedBox(height: PrismSpace.xxs),
            Text(l10n.statsChartEmptyHint, style: PrismTextStyles.caption(context)),
          ],
        ),
      );
    }
    final top = statsAxisTop(peak);
    final axis = NumberFormat.compact(locale: locale);
    final labelStyle = PrismTextStyles.caption(context).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final scaler = MediaQuery.textScalerOf(context);
    final yLabels = [axis.format(top), axis.format(top ~/ 2), axis.format(0)];
    final xLabels = [for (final week in weeks) DateFormat.MMMd(locale).format(week.start)];
    final gutter = _widest(yLabels, labelStyle, scaler) + PrismSpace.xs;
    final labelHeight = scaler.scale(labelStyle.fontSize!) * (labelStyle.height ?? 1.35);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            weekText(selected),
            style: PrismTextStyles.rowTitle(context).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        Text(l10n.statsChartHint, style: PrismTextStyles.caption(context)),
        const SizedBox(height: PrismSpace.sm),
        SizedBox(
          height: 150 + labelHeight * 1.5 + PrismSpace.xs,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _Bars(
                    values: values,
                    top: top,
                    highlight: widget.highlight,
                    selected: selected,
                    yLabels: yLabels,
                    xLabels: xLabels,
                    labelStyle: labelStyle,
                    scaler: scaler,
                    gutter: gutter,
                    textDirection: Directionality.of(context),
                    bar: cs.primary,
                    muted: cs.outlineVariant,
                    grid: cs.onSurface.withValues(alpha: 0.08),
                    ink: cs.onSurface,
                  ),
                ),
              ),
              Positioned.fill(
                right: gutter,
                child: Row(
                  children: [
                    for (var i = 0; i < weeks.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == selected,
                          label: weekText(i),
                          onTap: () => setState(() => picked = i),
                          excludeSemantics: true,
                          child: _Activatable(
                            onActivate: () => setState(() => picked = i),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static double _widest(List<String> labels, TextStyle style, TextScaler scaler) {
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest;
  }
}

class _Bars extends CustomPainter {
  _Bars({
    required this.values,
    required this.top,
    required this.highlight,
    required this.selected,
    required this.yLabels,
    required this.xLabels,
    required this.labelStyle,
    required this.scaler,
    required this.gutter,
    required this.textDirection,
    required this.bar,
    required this.muted,
    required this.grid,
    required this.ink,
  });
  final List<int?> values;
  final int top;
  final Set<int> highlight;
  final int selected;
  final List<String> yLabels;
  final List<String> xLabels;
  final TextStyle labelStyle;
  final TextScaler scaler;
  final double gutter;
  final TextDirection textDirection;
  final Color bar;
  final Color muted;
  final Color grid;
  final Color ink;

  TextPainter _label(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: textDirection,
    textScaler: scaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final ys = yLabels.map(_label).toList();
    final xs = xLabels.map(_label).toList();
    final topPad = ys.first.height / 2;
    final xHeight = xs.fold<double>(0, (h, p) => math.max(h, p.height));
    final baseline = size.height - xHeight - PrismSpace.xs;
    final plot = baseline - topPad;
    final width = size.width - gutter;
    final step = width / values.length;

    for (var i = 0; i < ys.length; i++) {
      final y = topPad + plot * i / (ys.length - 1);
      canvas.drawLine(Offset(0, y), Offset(width, y), Paint()..color = grid);
      ys[i].paint(canvas, Offset(size.width - ys[i].width, y - ys[i].height / 2));
    }

    var stride = 1;
    final widestX = xs.fold<double>(0, (w, p) => math.max(w, p.width));
    while (stride < values.length && widestX + PrismSpace.xxs > stride * step) {
      stride *= 2;
    }

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final x = i * step + step * .18;
      final w = step * .64;
      final strong = highlight.isEmpty || highlight.contains(i);
      if (value == null) {
        canvas.drawLine(
          Offset(x + w * .2, baseline - 1),
          Offset(x + w * .8, baseline - 1),
          Paint()
            ..color = muted
            ..strokeWidth = 2,
        );
      } else {
        final h = value == 0 ? 2.0 : math.max(3.0, plot * value / top);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, baseline - h, w, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = bar.withValues(alpha: value == 0 || !strong ? 0.35 : 1.0),
        );
      }
      if (i == selected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, baseline + 2, w, 3), const Radius.circular(2)),
          Paint()..color = ink,
        );
      }
    }
    var nextLabelLeft = width + PrismSpace.xxs;
    for (var i = values.length - 1; i >= 0; i -= stride) {
      final label = xs[i];
      final dx = (i * step + (step - label.width) / 2).clamp(0.0, math.max(0.0, width - label.width)).toDouble();
      if (dx + label.width + PrismSpace.xxs <= nextLabelLeft) {
        label.paint(canvas, Offset(dx, baseline + PrismSpace.xs));
        nextLabelLeft = dx;
      }
    }
    for (final painter in [...ys, ...xs]) {
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _Bars old) =>
      !listEquals(old.values, values) ||
      old.top != top ||
      !setEquals(old.highlight, highlight) ||
      old.selected != selected ||
      !listEquals(old.yLabels, yLabels) ||
      !listEquals(old.xLabels, xLabels) ||
      old.labelStyle != labelStyle ||
      old.scaler != scaler ||
      old.gutter != gutter ||
      old.textDirection != textDirection ||
      old.bar != bar ||
      old.muted != muted ||
      old.grid != grid ||
      old.ink != ink;
}
