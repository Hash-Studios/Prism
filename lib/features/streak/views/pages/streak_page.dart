import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/streak_shop_policy.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class StreakPage extends StatefulWidget {
  const StreakPage({super.key});

  @override
  State<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends State<StreakPage> {
  bool _isUnlocked(PrismWallpaper wallpaper, StreakStatus status, int balance) {
    final streakOk =
        (wallpaper.requiredStreakDays == null) || (status.active && status.streakDay >= wallpaper.requiredStreakDays!);
    final coinOk = (wallpaper.streakShopCoinCost == null) || balance >= wallpaper.streakShopCoinCost!;
    return streakOk || coinOk;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StreakShopBloc>(
      create: (_) {
        final bloc = getIt<StreakShopBloc>();
        bloc.add(const StreakShopLoaded());
        return bloc;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          title: const Text('Your Streak'),
          actions: const [],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroSection(),
              const SizedBox(height: 20),
              _DayCardsRow(),
              const SizedBox(height: 16),
              _StatusMessage(),
              const SizedBox(height: 24),
              Text(
                'Streak Shop',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _StreakShopGrid(isUnlocked: _isUnlocked),
              const SizedBox(height: 24),
              Text(
                'Earn More Coins',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _EarnMethodsList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        return ValueListenableBuilder<int>(
          valueListenable: CoinsService.instance.balanceNotifier,
          builder: (context, balance, _) {
            final int streakDay = status.active ? status.streakDay.clamp(1, 7) : 0;
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Colors.orange.withValues(alpha: 0.2), Colors.deepOrange.withValues(alpha: 0.15)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: <Widget>[
                  Icon(Icons.monetization_on_rounded, size: 48, color: Colors.amber.shade700),
                  const SizedBox(height: 8),
                  Text(
                    streakDay > 0 ? '$streakDay Days Streak!' : 'Start your streak!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$balance coins',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DayCardsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bool isPro = app_state.prismUser.premium;
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int currentDay = status.active ? status.streakDay.clamp(1, 7) : 0;
        return SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final int day = index + 1;
              final int baseReward = CoinPolicy.streakTotalRewardForDay(day);
              final int proBonus = isPro ? (day == 7 ? CoinPolicy.proStreak7Bonus : CoinPolicy.proStreakDailyBonus) : 0;
              final int reward = baseReward + proBonus;
              final bool isCurrent = day == currentDay;
              return Container(
                width: 56,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCurrent ? null : Theme.of(context).hintColor,
                  gradient: isCurrent
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFFE91E63), Color(0xFF9C27B0)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrent
                      ? null
                      : Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'D$day',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isCurrent ? Colors.white : Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+$reward',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isCurrent ? Colors.white : Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int nextDay = status.active ? (status.streakDay >= 7 ? 1 : status.streakDay + 1) : 1;
        final int nextReward = CoinPolicy.streakTotalRewardForDay(nextDay);
        final String msg = status.claimedToday
            ? 'Come back tomorrow for +$nextReward coins.'
            : status.active
            ? 'Claim today to protect your streak!'
            : 'Claim today to start your streak.';
        return Text(
          msg,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.9)),
        );
      },
    );
  }
}

class _StreakShopGrid extends StatelessWidget {
  const _StreakShopGrid({required this.isUnlocked});

  final bool Function(PrismWallpaper, StreakStatus, int) isUnlocked;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StreakShopBloc, StreakShopState>(
      builder: (context, state) {
        if (state.status == StreakShopStatus.loading) {
          return SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
          );
        }
        if (state.status == StreakShopStatus.failure) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).hintColor, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: <Widget>[
                Text('Unable to load streak shop', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.read<StreakShopBloc>().add(const StreakShopLoaded()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state.items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).hintColor, borderRadius: BorderRadius.circular(12)),
            child: Text(
              'No exclusive wallpapers yet. Check back soon!',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8)),
            ),
          );
        }
        return ValueListenableBuilder<StreakStatus>(
          valueListenable: CoinsService.instance.streakNotifier,
          builder: (context, streakStatus, _) {
            return ValueListenableBuilder<int>(
              valueListenable: CoinsService.instance.balanceNotifier,
              builder: (context, balance, _) {
                return SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) {
                      final w = state.items[index];
                      final unlocked = isUnlocked(w, streakStatus, balance);
                      return GestureDetector(
                        onTap: () {
                          if (unlocked) {
                            final entity = PrismDetailEntity(wallpaper: w);
                            context.router.push(WallpaperDetailRoute(entity: entity));
                          } else {
                            final req = w.requiredStreakDays != null
                                ? '${w.requiredStreakDays} day streak'
                                : w.streakShopCoinCost != null
                                ? '${w.streakShopCoinCost} coins'
                                : 'Unlock requirement';
                            toasts.codeSend('Requires: $req');
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                w.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: Theme.of(context).hintColor,
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                            ),
                            if (!unlocked)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      const Icon(Icons.lock_rounded, color: Colors.white70, size: 28),
                                      const SizedBox(height: 4),
                                      Text(
                                        w.requiredStreakDays != null
                                            ? '${w.requiredStreakDays} day streak'
                                            : w.streakShopCoinCost != null
                                            ? '${w.streakShopCoinCost} coins'
                                            : 'Locked',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EarnMethodsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _EarnItem(icon: Icons.play_circle_outline, label: 'Watch Ad (+${CoinPolicy.rewardedAd}c)'),
        _EarnItem(icon: Icons.people_outline, label: 'Refer Friend (+${CoinPolicy.referral}c)'),
        _EarnItem(icon: Icons.ac_unit, label: 'Streak Freeze (${StreakShopPolicy.streakFreezeCoins}c)'),
      ],
    );
  }
}

class _EarnItem extends StatelessWidget {
  const _EarnItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Theme.of(context).hintColor, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 12),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
