import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Weekly Drop" on the Rewards page: cover, countdown and how many walls the user owns. Hidden between Drops.
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
        final ColorScheme cs = Theme.of(context).colorScheme;
        final bool none = state.unlockedCount == 0;
        final String cover = drop.walls.isEmpty ? '' : drop.walls.first.thumb;
        Widget image = SizedBox.square(
          dimension: 72,
          child: cover.isEmpty ? ColoredBox(color: cs.surfaceContainerHigh) : PrismImageTile(url: cover),
        );
        if (none) image = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: image);
        return PrismCard(
          semanticLabel:
              'Weekly Drop, ${drop.endsInLabel(state.now)}, ${state.unlockedCount} of ${drop.count} unlocked',
          onTap: () {
            PrismHaptics.tap();
            unawaited(context.router.push(const DropsRoute()));
          },
          child: Row(
            children: <Widget>[
              ClipRRect(borderRadius: BorderRadius.circular(PrismRadius.sm), child: image),
              const SizedBox(width: PrismSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      drop.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.cardTitle(context),
                    ),
                    const SizedBox(height: PrismSpace.xxs),
                    Text(drop.endsInLabel(state.now), style: PrismTextStyles.caption(context)),
                    const SizedBox(height: PrismSpace.xxs),
                    Text('${state.unlockedCount}/${drop.count} unlocked', style: PrismTextStyles.caption(context)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        );
      },
    );
  }
}
