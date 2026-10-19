import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_chrome.dart';
import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Drop ticket on the Rewards page: a fan of frosted walls, the countdown and how many walls the user owns.
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
        return Padding(
          padding: const EdgeInsets.only(bottom: PrismSpace.sm),
          child: PressScale(
            scale: 0.98,
            child: Semantics(
              button: true,
              label:
                  'The Drop, ${drop.endsInLabel(state.now)}, ${state.unlockedCount} of ${drop.count} collected. Preview',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  PrismHaptics.tap();
                  unawaited(context.router.push(const DropsRoute()));
                },
                child: DropSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(PrismSpace.md),
                    child: Row(
                      children: <Widget>[
                        _FrostedFan(walls: drop.walls),
                        const SizedBox(width: PrismSpace.md),
                        Expanded(
                          child: _Details(drop: drop, state: state),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.drop, required this.state});

  final DropEntity drop;
  final DropsState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('THE DROP · ${dropWeekLabel(drop.weekKey)}', style: dropCapsStyle(size: 10, spacing: 2)),
        const SizedBox(height: 6),
        Text(
          drop.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: PrismFonts.fraunces,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: DropPalette.ink,
          ),
        ),
        const SizedBox(height: PrismSpace.sm),
        DropCountdown(drop: drop, now: state.now, digitSize: 20),
        const SizedBox(height: PrismSpace.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${state.unlockedCount}/${drop.count} collected',
                style: const TextStyle(
                  fontFamily: PrismFonts.proximaNova,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: DropPalette.inkMuted,
                ),
              ),
            ),
            const _PreviewPill(),
          ],
        ),
      ],
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: DropPalette.foil, borderRadius: BorderRadius.circular(PrismRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Text('Preview', style: dropCapsStyle(spacing: 0.8, color: DropPalette.obsidian)),
      ),
    );
  }
}

class _FrostedFan extends StatelessWidget {
  const _FrostedFan({required this.walls});

  final List<DropWall> walls;

  static const double _width = 58;
  static const double _height = 92;

  @override
  Widget build(BuildContext context) {
    final List<DropWall> shown = walls.take(3).toList();
    const List<double> turns = <double>[-0.17, 0, 0.17];
    const List<double> shifts = <double>[0, 22, 44];
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
                  child: SizedBox(
                    width: _width,
                    height: _height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(PrismRadius.xs),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: wall.thumb.isEmpty
                                ? const ColoredBox(color: DropPalette.obsidianRaised)
                                : PrismImageTile(url: wall.thumb),
                          ),
                          ColoredBox(color: DropPalette.obsidian.withValues(alpha: 0.3)),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(PrismRadius.xs),
                              border: Border.all(color: DropPalette.hairlineStrong, width: 0.8),
                            ),
                          ),
                          if (i == shown.length - 1) const Center(child: DropSeal(size: 28)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
