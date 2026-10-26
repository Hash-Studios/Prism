import 'dart:async';

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_chrome.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Drop card on the Rewards page: three of its walls, the name, the time left and how many walls the user owns.
/// Hidden between Drops.
class DropCard extends StatefulWidget {
  const DropCard({super.key});

  @override
  State<DropCard> createState() => _DropCardState();
}

class _DropCardState extends State<DropCard> {
  late final DropsBloc _bloc = getIt<DropsBloc>()..add(const DropsEvent.started());

  @override
  void dispose() {
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EconomyConfig>(
      valueListenable: EconomyConfig.notifier,
      builder: (context, config, _) {
        if (!config.flags.dropsEnabled) return const SizedBox.shrink();
        return BlocProvider<DropsBloc>.value(value: _bloc, child: const DropCardView());
      },
    );
  }
}

class DropCardView extends StatelessWidget {
  const DropCardView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DropsBloc, DropsState>(
      builder: (context, state) {
        final DropEntity? drop = state.drop;
        if (drop == null || !state.isLive) return const SizedBox.shrink();
        final AppLocalizations l10n = context.l10n;
        return Padding(
          padding: const EdgeInsets.only(bottom: PrismSpace.sm),
          child: PrismCard(
            padding: const EdgeInsets.all(PrismSpace.md),
            semanticLabel: l10n.economyDropCardSemantics(
              drop.endsInLabel(l10n, state.now),
              state.unlockedCount,
              drop.count,
            ),
            onTap: () {
              PrismHaptics.tap();
              unawaited(context.router.push(const DropsRoute()));
            },
            child: Row(
              children: <Widget>[
                _WallFan(walls: drop.walls),
                const SizedBox(width: PrismSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.economyWeeklyDrop, style: PrismTextStyles.caption(context)),
                      const SizedBox(height: 2),
                      Text(
                        drop.displayTitle(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PrismTextStyles.cardTitle(context),
                      ),
                      const SizedBox(height: PrismSpace.xs),
                      DropTimeTag(drop: drop, now: state.now),
                      const SizedBox(height: PrismSpace.xs),
                      Text(
                        l10n.economyDropCollected(state.unlockedCount, drop.count),
                        style: PrismTextStyles.caption(context),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WallFan extends StatelessWidget {
  const _WallFan({required this.walls});

  final List<DropWall> walls;

  static const double _width = 58;
  static const double _height = 92;

  @override
  Widget build(BuildContext context) {
    final List<DropWall> shown = walls.take(3).toList();
    const List<double> turns = <double>[-0.17, 0, 0.17];
    const List<double> shifts = <double>[0, 22, 44];
    final Color edge = Theme.of(context).colorScheme.outlineVariant;
    return ExcludeSemantics(
      child: SizedBox(
        width: _width + 44 + 6,
        height: _height + 16,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            for (final (int i, DropWall wall) in shown.indexed)
              Positioned(
                left: shifts[i],
                top: i == 1 ? 0 : 8,
                child: Transform.rotate(
                  angle: turns[i],
                  child: Container(
                    width: _width,
                    height: _height,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PrismRadius.xs),
                      border: Border.all(color: edge, width: 0.8),
                    ),
                    child: PrismImageTile(url: wall.thumb),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
