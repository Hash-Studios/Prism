import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_section.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:Prism/features/streak/streak_unlock.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _kTileAspect = 0.6;
const int _kColumns = 3;

/// "Streak collection": wallpapers unlocked by a long streak (or enough coins). Hidden when there are none.
class RewardsCollectionSection extends StatelessWidget {
  const RewardsCollectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StreakShopBloc>(
      create: (_) {
        final StreakShopBloc bloc = getIt<StreakShopBloc>();
        bloc.add(const StreakShopLoaded());
        return bloc;
      },
      child: const _CollectionBody(),
    );
  }
}

class _CollectionBody extends StatelessWidget {
  const _CollectionBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StreakShopBloc, StreakShopState>(
      builder: (context, state) {
        final bool loading = state.status == StreakShopStatus.initial || state.status == StreakShopStatus.loading;
        final bool failed = state.status == StreakShopStatus.failure;
        // An optional section: with nothing to unlock there is nothing to show.
        if (!loading && !failed && state.items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PrismSectionHeader(
              title: 'Streak collection',
              padding: EdgeInsets.only(top: PrismSpace.xxl, bottom: PrismSpace.xxs),
            ),
            Text('Wallpapers you unlock by keeping your streak.', style: PrismTextStyles.caption(context)),
            const SizedBox(height: PrismSpace.sm),
            if (loading)
              const _CollectionSkeleton()
            else if (failed)
              GlintState(
                kind: GlintStateKind.error,
                title: "Couldn't load the collection",
                body: 'Check your connection and try again.',
                actionLabel: 'Try again',
                onAction: () => context.read<StreakShopBloc>().add(const StreakShopLoaded()),
                glintSize: 56,
                padding: const EdgeInsets.symmetric(vertical: PrismSpace.md),
              )
            else
              _CollectionGrid(items: state.items),
          ],
        );
      },
    );
  }
}

class _CollectionSkeleton extends StatelessWidget {
  const _CollectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return PrismSkeleton(
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _kColumns; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: PrismWallGrid.spacing),
            const Expanded(
              child: AspectRatio(
                aspectRatio: _kTileAspect,
                child: PulseFill(borderRadius: PrismWallGrid.tileRadius),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({required this.items});

  final List<PrismWallpaper> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cell = (constraints.maxWidth - PrismWallGrid.spacing * (_kColumns - 1)) / _kColumns;
        // The tile, then room for a two line caption.
        final double extent = cell / _kTileAspect + PrismSpace.xs + MediaQuery.textScalerOf(context).scale(32);
        return ValueListenableBuilder<StreakStatus>(
          valueListenable: CoinsService.instance.streakNotifier,
          builder: (context, streak, _) => ValueListenableBuilder<int>(
            valueListenable: CoinsService.instance.balanceNotifier,
            builder: (context, balance, _) => GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _kColumns,
                crossAxisSpacing: PrismWallGrid.spacing,
                mainAxisSpacing: PrismSpace.sm,
                mainAxisExtent: extent,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final PrismWallpaper w = items[index];
                return _CollectionCard(wallpaper: w, unlocked: w.isUnlockedFor(streak, balance));
              },
            ),
          ),
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.wallpaper, required this.unlocked});

  final PrismWallpaper wallpaper;
  final bool unlocked;

  String get _caption {
    final int? days = wallpaper.requiredStreakDays;
    final int? coins = wallpaper.streakShopCoinCost;
    if (days != null) {
      return unlocked ? 'Unlocked at $days days' : 'Unlocks at $days days';
    }
    if (coins != null) {
      return unlocked ? 'Unlocked with coins' : 'Unlocks at $coins coins';
    }
    return unlocked ? 'Unlocked' : 'Locked';
  }

  String get _lockedMessage {
    final int? days = wallpaper.requiredStreakDays;
    final int? coins = wallpaper.streakShopCoinCost;
    if (days != null) {
      return 'Keep your streak for $days days to unlock this.${coins != null ? ' Or have $coins coins.' : ''}';
    }
    if (coins != null) {
      return 'Have $coins coins to unlock this.';
    }
    return "You haven't met the unlock requirements yet.";
  }

  void _onTap(BuildContext context) {
    if (unlocked) {
      HapticFeedback.lightImpact();
      context.router.root.push(
        WallpaperDetailRoute(
          entity: PrismFeedItem(id: wallpaper.id, wallpaper: wallpaper),
        ),
      );
      return;
    }
    showPrismSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => PrismSheetBody(
        title: 'Still locked',
        message: _lockedMessage,
        actions: <Widget>[
          PrismButton(label: 'Got it', expand: true, onPressed: () => Navigator.of(sheetContext).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String category = (wallpaper.core.category ?? '').isEmpty ? 'Wallpaper' : wallpaper.core.category!;
    return Semantics(
      button: true,
      label: '$category, ${unlocked ? 'unlocked' : 'locked'}, $_caption',
      excludeSemantics: true,
      onTap: () => _onTap(context),
      child: PressScale(
        scale: unlocked ? 0.96 : 0.98,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onTap(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: PrismWallTile(
                  url: wallpaper.thumbnailUrl,
                  overlay: unlocked
                      ? null
                      : ClipRRect(
                          borderRadius: PrismWallGrid.tileRadius,
                          child: ColoredBox(
                            color: cs.scrim.withValues(alpha: 0.42),
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: cs.scrim.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(PrismSpace.xs + 1),
                                  child: Icon(Icons.lock_outline_rounded, size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: PrismSpace.xs - 2),
              Text(_caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: PrismTextStyles.caption(context)),
            ],
          ),
        ),
      ),
    );
  }
}
