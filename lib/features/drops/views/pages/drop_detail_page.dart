import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_actions.dart';
import 'package:Prism/features/drops/views/widgets/drop_header.dart';
import 'package:Prism/features/drops/views/widgets/drop_wall_tiles.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One Drop by week. Walls the user did not unlock before the Drop ended say "Missed" and cannot be bought.
@RoutePage()
class DropDetailPage extends StatelessWidget {
  const DropDetailPage({super.key, @PathParam('weekKey') required this.weekKey});

  final String weekKey;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DropsBloc>(
      create: (_) => getIt<DropsBloc>()..add(DropsEvent.started(weekKey: weekKey)),
      child: const _DropDetailView(),
    );
  }
}

class _DropDetailView extends StatelessWidget {
  const _DropDetailView();

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Drop',
      body: BlocConsumer<DropsBloc, DropsState>(
        listenWhen: (previous, current) => current.lastResult != null && current.lastResult != previous.lastResult,
        listener: (context, state) => toastUnlockResult(state.lastResult!),
        builder: (context, state) {
          if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
            return const LoadingCards();
          }
          final DropEntity? drop = state.drop;
          if (state.status == LoadStatus.failure) {
            return GlintState(
              kind: GlintStateKind.error,
              title: "Couldn't load this Drop",
              body: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => context.read<DropsBloc>().add(const DropsEvent.refreshed()),
            );
          }
          if (drop == null) {
            return const GlintState(kind: GlintStateKind.empty, title: 'This Drop is gone');
          }
          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: DropHeader(drop: drop, now: state.now, remaining: state.lockedWalls.length, live: state.isLive),
              ),
              DropWallGrid(
                drop: drop,
                unlocked: state.unlocked,
                canBuy: state.isLive,
                busyKey: state.busyKey,
                onLockedTap: (wall) => askToUnlock(context, state, wall),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: PrismSpace.bottomBarClearance)),
            ],
          );
        },
      ),
    );
  }
}
