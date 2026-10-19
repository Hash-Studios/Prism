import 'dart:async';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/draw/biz/bloc/draw_bloc.j.dart';
import 'package:Prism/features/draw/domain/entities/draw_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const int maxDrawTickets = 5;
const String drawRulesUrl = 'https://prismwalls.com/draw-rules';

/// The weekly Prism Draw: buy up to five tickets, one winner each Monday.
@RoutePage()
class DrawPage extends StatelessWidget implements AutoRouteWrapper {
  const DrawPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) =>
      BlocProvider<DrawBloc>(create: (_) => getIt<DrawBloc>()..add(const DrawEvent.started()), child: this);

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: context.l10n.economyDrawTitle,
      body: ValueListenableBuilder<EconomyConfig>(
        valueListenable: EconomyConfig.notifier,
        builder: (context, config, _) {
          if (!config.flags.drawEnabled) {
            return GlintState(kind: GlintStateKind.nothingNew, title: context.l10n.economyDrawNotOpen);
          }
          return BlocConsumer<DrawBloc, DrawState>(
            listenWhen: (previous, current) => current.purchase != null && previous.purchase != current.purchase,
            listener: (context, state) => _toast(context, state.purchase!),
            builder: (context, state) {
              final DrawEntity? draw = state.draw;
              if (draw == null) {
                if (state.status == LoadStatus.failure) {
                  return RefreshableGlintState(
                    kind: GlintStateKind.error,
                    title: context.l10n.economyDrawLoadFailed,
                    body: context.l10n.errorNetwork,
                    actionLabel: context.l10n.actionRetry,
                    onAction: () => context.read<DrawBloc>().add(const DrawEvent.refreshed()),
                    onRefresh: () => _refresh(context),
                  );
                }
                return PrismSkeleton.rows(rows: 4, avatar: false);
              }
              return RefreshIndicator(
                onRefresh: () => _refresh(context),
                child: _DrawBody(state: state, draw: draw),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _refresh(BuildContext context) {
    final DrawBloc bloc = context.read<DrawBloc>();
    final Future<DrawState> settled = bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
    bloc.add(const DrawEvent.refreshed());
    return settled;
  }

  void _toast(BuildContext context, DrawTicketResult result) {
    final AppLocalizations l10n = context.l10n;
    switch (result.outcome) {
      case DrawTicketOutcome.bought:
        toasts.success(l10n.economyDrawTicketBought(result.tickets, maxDrawTickets));
      case DrawTicketOutcome.limit:
        toasts.error(l10n.economyDrawAllTicketsHeld(maxDrawTickets));
      case DrawTicketOutcome.disabled:
        toasts.error(l10n.economyDrawNotOpen);
      case DrawTicketOutcome.closed:
        toasts.error(l10n.economyDrawClosed);
      case DrawTicketOutcome.proNotEligible:
        toasts.error(l10n.economyDrawProNotEligible);
      case DrawTicketOutcome.insufficient:
        toasts.error(l10n.economyDrawNotEnoughCoins);
      case DrawTicketOutcome.failed:
        toasts.error(l10n.economyDrawPurchaseFailed);
    }
  }
}

/// "3d 4h" while a day or more is left, else "4h 20m".
String drawTimeLeft(AppLocalizations l10n, DateTime closesAt, DateTime now) {
  final Duration left = closesAt.difference(now);
  if (left <= Duration.zero) return l10n.economyCountdownMinutes(0);
  if (left.inHours >= 24) return l10n.economyCountdownDaysHours(left.inDays, left.inHours % 24);
  return l10n.economyCountdownHoursMinutes(left.inHours, left.inMinutes % 60);
}

class _DrawBody extends StatelessWidget {
  const _DrawBody({required this.state, required this.draw});

  final DrawState state;
  final DrawEntity draw;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool premium = app_state.prismUser.premium;
    final int mine = state.myTickets;
    final int pot = mine > draw.tickets ? mine : draw.tickets;
    final bool canBuy = !premium && mine < maxDrawTickets;
    final String? lastWinner = state.lastWinner?.winnerName;
    final int months = draw.prizeProMonths;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        PrismSpace.page,
        PrismSpace.xs,
        PrismSpace.page,
        PrismSpace.bottomBarClearance,
      ),
      children: <Widget>[
        PrismCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(context.l10n.economyDrawThisWeeksPrize, style: PrismTextStyles.eyebrow(context)),
              const SizedBox(height: PrismSpace.xs),
              Text(context.l10n.economyDrawPrizeDescription(months), style: PrismTextStyles.sheetHeadline(context)),
              const SizedBox(height: PrismSpace.sm),
              Text(
                context.l10n.economyDrawTicketsAndPeople(pot, draw.participants),
                style: PrismTextStyles.body(context),
              ),
              const SizedBox(height: PrismSpace.xxs),
              Text(
                context.l10n.economyDrawClosesIn(drawTimeLeft(context.l10n, draw.closesAt, DateTime.now())),
                style: PrismTextStyles.caption(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: PrismSpace.md),
        PrismCard(
          color: cs.surfaceContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                context.l10n.economyDrawYourTickets(mine, maxDrawTickets),
                style: PrismTextStyles.cardTitle(context),
              ),
              const SizedBox(height: PrismSpace.xxs),
              Text(context.l10n.economyDrawYourChance(mine, pot), style: PrismTextStyles.body(context)),
              const SizedBox(height: PrismSpace.md),
              PrismButton(
                label: context.l10n.economyDrawBuyTicket(CoinPolicy.drawTicket),
                trailing: const PrismCoinIcon(size: 18),
                expand: true,
                loading: state.busy,
                onPressed: canBuy ? () => context.read<DrawBloc>().add(const DrawEvent.ticketRequested()) : null,
              ),
              if (premium) ...<Widget>[
                const SizedBox(height: PrismSpace.xs),
                Text(context.l10n.economyDrawProNotEligible, style: PrismTextStyles.caption(context)),
              ] else if (mine >= maxDrawTickets) ...<Widget>[
                const SizedBox(height: PrismSpace.xs),
                Text(context.l10n.economyDrawAllTicketsHeld(maxDrawTickets), style: PrismTextStyles.caption(context)),
              ],
            ],
          ),
        ),
        const SizedBox(height: PrismSpace.md),
        PrismGroup(
          children: <Widget>[
            if (lastWinner != null)
              PrismRow(
                icon: Icons.emoji_events_rounded,
                title: lastWinner,
                subtitle: context.l10n.economyDrawLastWinner,
                showChevron: false,
              ),
            PrismRow(
              icon: Icons.gavel_rounded,
              title: context.l10n.economyDrawOfficialRules,
              onTap: () => unawaited(openPrismLink(context, drawRulesUrl)),
            ),
          ],
        ),
      ],
    );
  }
}
