import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/leaderboard/biz/bloc/leaderboard_bloc.j.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:Prism/features/leaderboard/domain/week_key.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Weekly XP ranking: the people you follow, and the global top list.
@RoutePage()
class LeaderboardPage extends StatefulWidget implements AutoRouteWrapper {
  const LeaderboardPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) => BlocProvider<LeaderboardBloc>(
    create: (_) => getIt<LeaderboardBloc>()..add(const LeaderboardEvent.started()),
    child: this,
  );

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  @override
  void initState() {
    super.initState();
    _trackViewed(LeaderboardTab.friends);
  }

  void _trackViewed(LeaderboardTab tab) => unawaited(analytics.track(LeaderboardViewedEvent(tab: tab.name)));

  Future<void> _refresh(BuildContext context) {
    final LeaderboardBloc bloc = context.read<LeaderboardBloc>();
    final Future<LeaderboardState> settled = bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
    bloc.add(const LeaderboardEvent.refreshed());
    return settled;
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Leaderboard',
      body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
              child: PrismSegmented<LeaderboardTab>(
                values: LeaderboardTab.values,
                selected: state.tab,
                labelOf: (tab) => tab == LeaderboardTab.friends ? 'Friends' : 'Global',
                onChanged: (tab) {
                  _trackViewed(tab);
                  context.read<LeaderboardBloc>().add(LeaderboardEvent.tabChanged(tab));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.xs),
              child: Text(resetCaption(DateTime.now()), style: PrismTextStyles.caption(context)),
            ),
            Expanded(
              child: _Content(state: state, onRefresh: () => _refresh(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Resets Monday · 3d 4h left", counted down to the next Monday 00:00 UTC.
String resetCaption(DateTime now) {
  final int hours = nextWeekStart(now).difference(now.toUtc()).inHours;
  return 'Resets Monday · ${hours ~/ 24}d ${hours % 24}h left';
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.onRefresh});

  final LeaderboardState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final List<LeaderboardEntry> entries = state.entries;
    final LoadStatus status = state.status;
    if (entries.isEmpty && (status == LoadStatus.initial || status == LoadStatus.loading)) {
      return PrismSkeleton.rows();
    }
    if (entries.isEmpty) {
      final bool failed = status == LoadStatus.failure;
      final bool friends = state.tab == LeaderboardTab.friends;
      return RefreshableGlintState(
        kind: failed ? GlintStateKind.error : GlintStateKind.empty,
        title: failed
            ? "Couldn't load the leaderboard"
            : friends
            ? 'Follow creators to see them here.'
            : 'No rankings yet',
        body: failed ? 'Check your connection and try again.' : null,
        actionLabel: failed ? 'Try again' : null,
        onAction: failed ? () => unawaited(onRefresh()) : null,
        onRefresh: onRefresh,
      );
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: cs.surfaceContainerHigh,
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(PrismSpace.xs, 0, PrismSpace.xs, PrismSpace.bottomBarClearance),
        itemCount: entries.length,
        itemBuilder: (context, index) => _EntryRow(entry: entries[index], position: index + 1),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.position});

  final LeaderboardEntry entry;
  final int position;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String name = entry.name.trim().isEmpty ? entry.username : entry.name.trim();
    final String rank = entry.rank.isEmpty ? '' : '${entry.rank[0].toUpperCase()}${entry.rank.substring(1)}';
    final bool tappable = entry.username.isNotEmpty;
    return Semantics(
      container: true,
      button: tappable,
      label: '$position, $name, ${entry.xp} XP',
      child: ExcludeSemantics(
        child: Material(
          color: entry.isMe ? cs.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(PrismRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(PrismRadius.md),
            onTap: tappable ? () => context.router.push(ProfileRoute(profileIdentifier: entry.username)) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.sm),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 32,
                    child: Text('$position', style: PrismTextStyles.numeral(context, 18), textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: PrismSpace.sm),
                  PrismAvatar(url: entry.photo, name: name, size: 40),
                  const SizedBox(width: PrismSpace.sm),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PrismTextStyles.rowTitle(context),
                          ),
                        ),
                        if (rank.isNotEmpty) ...<Widget>[
                          const SizedBox(width: PrismSpace.xs),
                          PrismTag(label: rank, tone: entry.isMe ? PrismTone.accent : PrismTone.neutral),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: PrismSpace.sm),
                  Text('${entry.xp} XP', style: PrismTextStyles.rowTitle(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
