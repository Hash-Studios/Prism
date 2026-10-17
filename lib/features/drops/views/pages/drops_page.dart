import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_actions.dart';
import 'package:Prism/features/drops/views/widgets/drop_header.dart';
import 'package:Prism/features/drops/views/widgets/drop_vault.dart';
import 'package:Prism/features/drops/views/widgets/drop_wall_tiles.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// This week's Drop: a grid of blurred walls to unlock, the vault of past unlocks and the past Drops.
@RoutePage()
class DropsPage extends StatelessWidget {
  const DropsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DropsBloc>(
      create: (_) => getIt<DropsBloc>()..add(const DropsEvent.started()),
      child: const _DropsView(),
    );
  }
}

class _DropsView extends StatelessWidget {
  const _DropsView();

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Weekly Drop',
      body: BlocConsumer<DropsBloc, DropsState>(
        listenWhen: (previous, current) => current.lastResult != null && current.lastResult != previous.lastResult,
        listener: (context, state) => toastUnlockResult(state.lastResult!),
        builder: (context, state) {
          if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
            return const LoadingCards();
          }
          if (state.status == LoadStatus.failure) {
            return GlintState(
              kind: GlintStateKind.error,
              title: "Couldn't load the Drop",
              body: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => context.read<DropsBloc>().add(const DropsEvent.refreshed()),
            );
          }
          return _DropsBody(state: state);
        },
      ),
    );
  }
}

class _DropsBody extends StatelessWidget {
  const _DropsBody({required this.state});

  final DropsState state;

  @override
  Widget build(BuildContext context) {
    final DropEntity? drop = state.drop;
    final bool live = state.isLive;
    return CustomScrollView(
      slivers: <Widget>[
        if (drop == null || !live)
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 320,
              child: GlintState(
                kind: GlintStateKind.nothingNew,
                title: 'No Drop right now',
                body: 'The next Drop lands Monday.',
              ),
            ),
          )
        else ...<Widget>[
          SliverToBoxAdapter(
            child: DropHeader(drop: drop, now: state.now, remaining: state.lockedWalls.length, live: true),
          ),
          DropWallGrid(
            drop: drop,
            unlocked: state.unlocked,
            canBuy: true,
            busyKey: state.busyKey,
            onLockedTap: (wall) => askToUnlock(context, state, wall),
          ),
        ],
        SliverToBoxAdapter(
          child: DropVault(drops: state.vault, unlocked: state.unlocked),
        ),
        SliverToBoxAdapter(
          child: PastDropRows(drops: state.past, unlocked: state.unlocked),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: PrismSpace.bottomBarClearance)),
      ],
    );
  }
}
