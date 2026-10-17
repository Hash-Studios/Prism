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
      title: 'Prism Draw',
      body: ValueListenableBuilder<EconomyConfig>(
        valueListenable: EconomyConfig.notifier,
        builder: (context, config, _) {
          if (!config.flags.drawEnabled) {
            return const GlintState(kind: GlintStateKind.nothingNew, title: 'The Draw is not open yet.');
          }
          return BlocConsumer<DrawBloc, DrawState>(
            listenWhen: (previous, current) => current.purchase != null && previous.purchase != current.purchase,
            listener: (context, state) => _toast(state.purchase!),
            builder: (context, state) {
              final DrawEntity? draw = state.draw;
              if (draw == null) {
                if (state.status == LoadStatus.failure) {
                  return RefreshableGlintState(
                    kind: GlintStateKind.error,
                    title: "Couldn't load the Draw",
                    body: 'Check your connection and try again.',
                    actionLabel: 'Try again',
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

  void _toast(DrawTicketResult result) {
    switch (result.outcome) {
      case DrawTicketOutcome.bought:
        toasts.success('Ticket bought. You hold ${result.tickets} of $maxDrawTickets.');
      case DrawTicketOutcome.limit:
        toasts.error('You already hold all $maxDrawTickets tickets this week.');
      case DrawTicketOutcome.disabled:
        toasts.error('The Draw is not open yet.');
      case DrawTicketOutcome.closed:
        toasts.error('This draw is closed. The next one opens Monday.');
      case DrawTicketOutcome.proNotEligible:
        toasts.error('Pro members are not eligible.');
      case DrawTicketOutcome.insufficient:
        toasts.error('Not enough coins for a ticket.');
      case DrawTicketOutcome.failed:
        toasts.error("Couldn't buy a ticket. Try again.");
    }
  }
}

/// "3d 4h" while a day or more is left, else "4h 20m".
String drawTimeLeft(DateTime closesAt, DateTime now) {
  final Duration left = closesAt.difference(now);
  if (left <= Duration.zero) return '0m';
  if (left.inHours >= 24) return '${left.inDays}d ${left.inHours % 24}h';
  return '${left.inHours}h ${left.inMinutes % 60}m';
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
              Text("THIS WEEK'S PRIZE", style: PrismTextStyles.eyebrow(context)),
              const SizedBox(height: PrismSpace.xs),
              Text(
                '$months month${months == 1 ? '' : 's'} of Pro + the Prism frame',
                style: PrismTextStyles.sheetHeadline(context),
              ),
              const SizedBox(height: PrismSpace.sm),
              Text('$pot tickets from ${draw.participants} people', style: PrismTextStyles.body(context)),
              const SizedBox(height: PrismSpace.xxs),
              Text('Closes in ${drawTimeLeft(draw.closesAt, DateTime.now())}', style: PrismTextStyles.caption(context)),
            ],
          ),
        ),
        const SizedBox(height: PrismSpace.md),
        PrismCard(
          color: cs.surfaceContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Your tickets: $mine of $maxDrawTickets', style: PrismTextStyles.cardTitle(context)),
              const SizedBox(height: PrismSpace.xxs),
              Text('Your chance: $mine/$pot', style: PrismTextStyles.body(context)),
              const SizedBox(height: PrismSpace.md),
              PrismButton(
                label: 'Buy a ticket · ${CoinPolicy.drawTicket}',
                trailing: const PrismCoinIcon(size: 18),
                expand: true,
                loading: state.busy,
                onPressed: canBuy ? () => context.read<DrawBloc>().add(const DrawEvent.ticketRequested()) : null,
              ),
              if (premium) ...<Widget>[
                const SizedBox(height: PrismSpace.xs),
                Text('Pro members are not eligible', style: PrismTextStyles.caption(context)),
              ] else if (mine >= maxDrawTickets) ...<Widget>[
                const SizedBox(height: PrismSpace.xs),
                Text('You hold all $maxDrawTickets tickets this week.', style: PrismTextStyles.caption(context)),
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
                subtitle: 'Last winner',
                showChevron: false,
              ),
            PrismRow(
              icon: Icons.gavel_rounded,
              title: 'Official rules',
              onTap: () => unawaited(openPrismLink(context, drawRulesUrl)),
            ),
          ],
        ),
      ],
    );
  }
}
