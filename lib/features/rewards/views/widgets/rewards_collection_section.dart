import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:Prism/features/streak/streak_unlock.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _kCardAspect = 0.6;

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
        if (!loading && !failed && state.items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Streak collection', style: PrismTextStyles.sectionTitle(context)),
              const SizedBox(height: 4),
              Text('Wallpapers you unlock by keeping your streak.', style: PrismTextStyles.caption(context)),
              const SizedBox(height: 12),
              if (loading)
                const _CollectionSkeleton()
              else if (failed)
                Row(
                  children: <Widget>[
                    Expanded(child: Text("Couldn't load the collection.", style: PrismTextStyles.body(context))),
                    TextButton(
                      onPressed: () {
                        PrismHaptics.tap();
                        context.read<StreakShopBloc>().add(const StreakShopLoaded());
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                )
              else
                _CollectionGrid(items: state.items),
            ],
          ),
        );
      },
    );
  }
}

class _CollectionSkeleton extends StatelessWidget {
  const _CollectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return PulsePlaceholder(
      builder: (context, _) => Row(
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            const Expanded(
              child: AspectRatio(
                aspectRatio: _kCardAspect,
                child: PulseFill(borderRadius: BorderRadius.all(Radius.circular(14))),
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
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, streak, _) => ValueListenableBuilder<int>(
        valueListenable: CoinsService.instance.balanceNotifier,
        builder: (context, balance, _) => GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 14,
            childAspectRatio: 0.44,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final PrismWallpaper w = items[index];
            return _CollectionCard(wallpaper: w, unlocked: w.isUnlockedFor(streak, balance));
          },
        ),
      ),
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
      PrismHaptics.tap();
      context.router.root.push(
        WallpaperDetailRoute(
          entity: PrismFeedItem(id: wallpaper.id, wallpaper: wallpaper),
        ),
      );
      return;
    }
    PrismHaptics.warning();
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_lockedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MediaQueryData mq = MediaQuery.of(context);
    final int cacheWidth = (mq.size.width / 3 * mq.devicePixelRatio).round().clamp(120, 1200);
    final String category = (wallpaper.core.category ?? '').isEmpty ? 'Wallpaper' : wallpaper.core.category!;
    return Semantics(
      button: true,
      label: '$category, ${unlocked ? 'unlocked' : 'locked'}, $_caption',
      excludeSemantics: true,
      onTap: () => _onTap(context),
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onTap(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.network(
                        wallpaper.thumbnailUrl,
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth,
                        errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHigh),
                      ),
                      if (!unlocked) ...<Widget>[
                        ColoredBox(color: scheme.scrim.withValues(alpha: 0.42)),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: scheme.scrim.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.white70),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PrismTextStyles.caption(context).copyWith(height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
