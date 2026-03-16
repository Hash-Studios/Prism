import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
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
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              backgroundColor: Theme.of(context).primaryColor,
              surfaceTintColor: Colors.transparent,
              floating: true,
              title: const Text('Your Streak'),
              actions: <Widget>[
                ValueListenableBuilder<int>(
                  valueListenable: CoinsService.instance.balanceNotifier,
                  builder: (context, balance, _) => _HexCoinBadge(balance: balance),
                ),
                const SizedBox(width: 16),
              ],
            ),
            SliverToBoxAdapter(child: _HeroSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _DayCardsRow()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _StatusMessage()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(accent: 'Streak', rest: ' Collections'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _StreakShopGrid(isUnlocked: _isUnlocked),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(accent: 'Earn', rest: ' More Coins'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _EarnMethodsList()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ── Coin badge in AppBar ──────────────────────────────────────────────────────

class _HexCoinBadge extends StatelessWidget {
  const _HexCoinBadge({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: <Color>[Color(0xFFFFC107), Color(0xFFFF8F00)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.monetization_on, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$balance',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Gem decorative shape ──────────────────────────────────────────────────────

class _GemShape extends StatelessWidget {
  const _GemShape({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.7853982, // 45°
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[color, color.withValues(alpha: 0.55)],
          ),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────

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
            final int claimDay = status.active ? streakDay : 1;
            final String statusLine;
            final Color statusColor;

            if (status.claimedToday) {
              statusLine = '✓ Claimed Today  ·  $streakDay day streak';
              statusColor = const Color(0xFF00BCD4);
            } else if (status.active) {
              statusLine = 'Claim today for +${CoinPolicy.streakTotalRewardForDay(claimDay)}c!';
              statusColor = Colors.amber.shade600;
            } else {
              statusLine = 'Claim today to start your streak.';
              statusColor = Theme.of(context).colorScheme.secondary;
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.5), width: 1.5),
              ),
              child: Column(
                children: <Widget>[
                  // Decorative gem row
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _GemShape(color: Color(0xFF9C27B0)),
                      SizedBox(width: 10),
                      _GemShape(color: Color(0xFF4CAF50)),
                      SizedBox(width: 10),
                      _GemShape(color: Color(0xFFF44336)),
                      SizedBox(width: 10),
                      _GemShape(color: Color(0xFF00BCD4)),
                      SizedBox(width: 10),
                      _GemShape(color: Color(0xFFFF9800)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Large golden coin with balance
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFFFFC107), Color(0xFFFF8F00)],
                      ),
                      boxShadow: <BoxShadow>[BoxShadow(color: Color(0x55FFC107), blurRadius: 20, spreadRadius: 4)],
                    ),
                    child: Center(
                      child: Text(
                        '$balance',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Headline
                  RichText(
                    text: TextSpan(
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Daily Streak ',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text: 'Coins',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: const Color(0xFFFFC107), fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status line
                  Text(
                    statusLine,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
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

// ── Day Cards Row ─────────────────────────────────────────────────────────────

class _DayCardsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bool isPro = app_state.prismUser.premium;
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int currentDay = status.active ? status.streakDay.clamp(1, 7) : 0;
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final int day = index + 1;
              final int baseReward = CoinPolicy.streakTotalRewardForDay(day);
              final int proBonus = isPro ? (day == 7 ? CoinPolicy.proStreak7Bonus : CoinPolicy.proStreakDailyBonus) : 0;
              final int reward = baseReward + proBonus;
              final bool isCurrent = day == currentDay;
              final bool isPast = currentDay > 0 && day < currentDay;

              return Container(
                width: 72,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: isCurrent
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFFE91E63), Color(0xFF9C27B0)],
                        )
                      : null,
                  color: isCurrent ? null : Theme.of(context).hintColor,
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrent
                      ? null
                      : Border.all(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: isPast ? 0.2 : 0.3),
                        ),
                  boxShadow: isCurrent
                      ? <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Opacity(
                  opacity: isPast ? 0.6 : 1.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '+$reward',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isCurrent ? Colors.white : Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFFFFC107).withValues(alpha: 0.15),
                          border: Border.all(
                            color: isCurrent
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFFFFC107).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Icon(
                          Icons.monetization_on,
                          size: 14,
                          color: isCurrent ? Colors.white : const Color(0xFFFFC107),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Day $day',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isCurrent ? Colors.white : Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Status Message ────────────────────────────────────────────────────────────

class _StatusMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int nextDay = status.active ? (status.streakDay >= 7 ? 1 : status.streakDay + 1) : 1;
        final int nextReward = CoinPolicy.streakTotalRewardForDay(nextDay);

        final IconData icon;
        final String message;
        final Color bgColor;
        final Color textColor;

        if (status.claimedToday) {
          icon = Icons.check_circle_outline;
          message = 'Come back tomorrow for +$nextReward coins.';
          bgColor = const Color(0xFF00BCD4).withValues(alpha: 0.12);
          textColor = const Color(0xFF00BCD4);
        } else if (status.active) {
          icon = Icons.local_fire_department_rounded;
          message = 'Claim today to protect your streak!';
          bgColor = Colors.amber.withValues(alpha: 0.12);
          textColor = Colors.amber.shade700;
        } else {
          icon = Icons.bolt_rounded;
          message = 'Start your streak today';
          bgColor = Theme.of(context).hintColor;
          textColor = Theme.of(context).colorScheme.secondary;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: textColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: textColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.accent, required this.rest});

  final String accent;
  final String rest;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: accent,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: const Color(0xFF00BCD4), fontWeight: FontWeight.w800),
          ),
          TextSpan(
            text: rest,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ── Streak Shop Grid ──────────────────────────────────────────────────────────

class _StreakShopGrid extends StatelessWidget {
  const _StreakShopGrid({required this.isUnlocked});

  final bool Function(PrismWallpaper, StreakStatus, int) isUnlocked;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StreakShopBloc, StreakShopState>(
      builder: (context, state) {
        if (state.status == StreakShopStatus.loading) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        if (state.status == StreakShopStatus.failure) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).hintColor, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: <Widget>[
                Text('Unable to load streak collections', style: Theme.of(context).textTheme.bodyMedium),
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
              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8)),
            ),
          );
        }
        return ValueListenableBuilder<StreakStatus>(
          valueListenable: CoinsService.instance.streakNotifier,
          builder: (context, streakStatus, _) {
            return ValueListenableBuilder<int>(
              valueListenable: CoinsService.instance.balanceNotifier,
              builder: (context, balance, _) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: state.items.length,
                  itemBuilder: (_, index) {
                    final w = state.items[index];
                    final unlocked = isUnlocked(w, streakStatus, balance);
                    return _StreakCollectionCard(
                      wallpaper: w,
                      unlocked: unlocked,
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
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Streak Collection Card ────────────────────────────────────────────────────

class _StreakCollectionCard extends StatelessWidget {
  const _StreakCollectionCard({required this.wallpaper, required this.unlocked, required this.onTap});

  final PrismWallpaper wallpaper;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String thumbnailUrl = wallpaper.thumbnailUrl;
    final String? title = wallpaper.core.category;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Wallpaper image
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: Theme.of(context).hintColor,
                child: const Center(child: Icon(Icons.image_not_supported)),
              ),
            ),
            // Greyscale overlay for locked
            if (!unlocked) Container(decoration: const BoxDecoration(color: Color(0x66000000))),
            // Bottom gradient + text
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[Color(0xCC000000), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (title != null && title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Text(
                      'STREAK COLLECTION',
                      style: TextStyle(
                        color: Color(0xFF00BCD4),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Streak day badge (top right)
            if (wallpaper.requiredStreakDays != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: unlocked ? Colors.green.shade600 : const Color(0xFFFF8F00),
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Center(
                    child: unlocked
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${wallpaper.requiredStreakDays}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ),
            // Lock icon overlay
            if (!unlocked)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_rounded, color: Colors.white70, size: 24),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Earn Methods List ─────────────────────────────────────────────────────────

class _EarnMethodsList extends StatelessWidget {
  const _EarnMethodsList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        _EarnItem(
          icon: Icons.play_circle_outline,
          label: 'Watch Ad',
          amount: '+${CoinPolicy.rewardedAd}c',
          accentColor: Color(0xFF00BCD4),
        ),
        _EarnItem(
          icon: Icons.people_outline,
          label: 'Refer Friend',
          amount: '+${CoinPolicy.referral}c',
          accentColor: Color(0xFF9C27B0),
        ),
      ],
    );
  }
}

class _EarnItem extends StatelessWidget {
  const _EarnItem({required this.icon, required this.label, required this.amount, required this.accentColor});

  final IconData icon;
  final String label;
  final String amount;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).hintColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                amount,
                style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
