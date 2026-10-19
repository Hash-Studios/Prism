import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/leaderboard/biz/bloc/leaderboard_bloc.j.dart';
import 'package:Prism/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:Prism/features/leaderboard/domain/week_key.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/l10n/l10n.dart';
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
      title: context.l10n.economyLeaderboardTitle,
      actions: <Widget>[
        PrismIconButton(
          icon: Icons.info_outline_rounded,
          tooltip: context.l10n.economyLeaderboardHowScoringWorks,
          onPressed: () => showPrismSheet<void>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            builder: (_) => const _ScoringSheet(),
          ),
        ),
      ],
      body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
              child: PrismSegmented<LeaderboardTab>(
                values: LeaderboardTab.values,
                selected: state.tab,
                labelOf: (tab) => tab == LeaderboardTab.friends
                    ? context.l10n.economyLeaderboardFollowing
                    : context.l10n.economyLeaderboardGlobal,
                onChanged: (tab) {
                  _trackViewed(tab);
                  context.read<LeaderboardBloc>().add(LeaderboardEvent.tabChanged(tab));
                },
              ),
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

String resetCaption(AppLocalizations l10n, DateTime now) {
  final int hours = nextWeekStart(now).difference(now.toUtc()).inHours;
  return l10n.economyLeaderboardReset(hours ~/ 24, hours % 24);
}

class _ScoreCaption extends StatelessWidget {
  const _ScoreCaption(this.tab);

  final LeaderboardTab tab;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.l10n.economyLeaderboardRankedByXp, style: PrismTextStyles.body(context)),
        const SizedBox(height: PrismSpace.xxs),
        Text(resetCaption(context.l10n, DateTime.now()), style: PrismTextStyles.caption(context)),
        const SizedBox(height: PrismSpace.xs),
        Text(
          tab == LeaderboardTab.friends
              ? context.l10n.economyLeaderboardFriendsCaption
              : context.l10n.economyLeaderboardGlobalCaption,
          style: PrismTextStyles.caption(context),
        ),
      ],
    ),
  );
}

class _ScoringSheet extends StatelessWidget {
  const _ScoringSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(PrismSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.economyLeaderboardHowScoringWorks,
                  style: PrismTextStyles.sectionTitle(context),
                ),
              ),
              PrismIconButton(
                icon: Icons.close_rounded,
                tooltip: context.l10n.economyLeaderboardCloseScoring,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.md),
          Text(context.l10n.economyLeaderboardScoringIntro, style: PrismTextStyles.body(context)),
          const SizedBox(height: PrismSpace.lg),
          Text(context.l10n.economyLeaderboardFollowing, style: PrismTextStyles.rowTitle(context)),
          const SizedBox(height: PrismSpace.xs),
          Text(context.l10n.economyLeaderboardFriendsDetails, style: PrismTextStyles.body(context)),
          const SizedBox(height: PrismSpace.lg),
          Text(context.l10n.economyLeaderboardGlobal, style: PrismTextStyles.rowTitle(context)),
          const SizedBox(height: PrismSpace.xs),
          Text(context.l10n.economyLeaderboardGlobalDetails, style: PrismTextStyles.body(context)),
          const SizedBox(height: PrismSpace.lg),
          Text(context.l10n.economyLeaderboardOffline, style: PrismTextStyles.caption(context)),
        ],
      ),
    ),
  );
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.onRefresh});

  final LeaderboardState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final List<LeaderboardEntry> entries = state.entries;
    final LoadStatus status = state.status;
    final ColorScheme cs = Theme.of(context).colorScheme;
    Widget withCaption(Widget child) => RefreshIndicator(
      color: cs.primary,
      backgroundColor: cs.surfaceContainerHigh,
      notificationPredicate: (notification) =>
          status != LoadStatus.initial && status != LoadStatus.loading && notification.depth == 0,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(child: _ScoreCaption(state.tab)),
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverToBoxAdapter(
              child: SizedBox(height: constraints.remainingPaintExtent.clamp(300, double.infinity), child: child),
            ),
          ),
        ],
      ),
    );
    if (entries.isEmpty && (status == LoadStatus.initial || status == LoadStatus.loading)) {
      return withCaption(PrismSkeleton.rows());
    }
    if (entries.isEmpty) {
      final bool failed = status == LoadStatus.failure;
      final bool friends = state.tab == LeaderboardTab.friends;
      return withCaption(
        GlintState(
          kind: failed ? GlintStateKind.error : GlintStateKind.empty,
          title: failed
              ? context.l10n.economyLeaderboardLoadFailed
              : friends
              ? context.l10n.economyLeaderboardFollowToSee
              : context.l10n.economyLeaderboardNoRankings,
          body: failed ? context.l10n.errorNetwork : null,
          actionLabel: failed ? context.l10n.actionRetry : null,
          onAction: failed ? () => unawaited(onRefresh()) : null,
        ),
      );
    }
    final bool onlyMe = state.tab == LeaderboardTab.friends && entries.length == 1 && entries.single.isMe;
    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: cs.surfaceContainerHigh,
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(PrismSpace.xs, 0, PrismSpace.xs, PrismSpace.bottomBarClearance),
        itemCount: entries.length + 1 + (onlyMe ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) return _ScoreCaption(state.tab);
          final int entryIndex = index - 1;
          if (entryIndex == entries.length) {
            return Padding(
              padding: const EdgeInsets.all(PrismSpace.page),
              child: Text(context.l10n.economyLeaderboardFollowTip, style: PrismTextStyles.body(context)),
            );
          }
          return _EntryRow(entry: entries[entryIndex], position: entryIndex + 1);
        },
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
    final String rank = entry.rank.isEmpty ? '' : shopRankName(entry.rank, context.l10n);
    final bool tappable = entry.username.isNotEmpty;
    final bool largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    final Widget nameLabel = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: PrismTextStyles.rowTitle(context),
    );
    final Widget rankLabel = PrismTag(label: rank, tone: entry.isMe ? PrismTone.accent : PrismTone.neutral);
    return Semantics(
      container: true,
      button: tappable,
      label: context.l10n.economyLeaderboardEntrySemantics(
        position,
        name,
        entry.isMe ? 'true' : 'false',
        entry.xp,
        rank.isEmpty ? 'false' : 'true',
        rank,
      ),
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
                    child: Text(
                      formatLocalizedNumber(position, context.l10n),
                      style: PrismTextStyles.numeral(context, 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: PrismSpace.sm),
                  PrismAvatar(url: entry.photo, name: name, size: 40, frameId: entry.frameId, premium: entry.premium),
                  const SizedBox(width: PrismSpace.sm),
                  Expanded(
                    child: largeText
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              nameLabel,
                              const SizedBox(height: PrismSpace.xs),
                              Wrap(
                                spacing: PrismSpace.xs,
                                runSpacing: PrismSpace.xs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  if (rank.isNotEmpty) rankLabel,
                                  Text(context.l10n.economyXp(entry.xp), style: PrismTextStyles.rowTitle(context)),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: <Widget>[
                              Flexible(child: nameLabel),
                              if (rank.isNotEmpty) ...<Widget>[const SizedBox(width: PrismSpace.xs), rankLabel],
                            ],
                          ),
                  ),
                  if (!largeText) ...<Widget>[
                    const SizedBox(width: PrismSpace.sm),
                    Text(context.l10n.economyXp(entry.xp), style: PrismTextStyles.rowTitle(context)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
