import 'dart:async';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Horizontal inset for page sections (matches common 4pt rhythm: 5×4).
const double _kPagePadding = 20;

/// Tight gap between related blocks (hero ↔ days ↔ status).
const double _kTightGap = 8;

/// Space before a new section after a completed group.
const double _kSectionGap = 28;

/// Space between major page regions (shop ↔ earn).
const double _kMajorGap = 32;

bool _streakMotionOn(BuildContext context) => !MediaQuery.of(context).disableAnimations;

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
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              surfaceTintColor: Colors.transparent,
              floating: true,
              title: const Text('Daily streak'),
              actions: const <Widget>[
                CoinBalanceChip(sourceTag: 'streak_page', showStreak: false),
                SizedBox(width: _kTightGap),
              ],
            ),
            SliverToBoxAdapter(child: _HeroSection()),
            const SliverToBoxAdapter(child: SizedBox(height: _kTightGap)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
                child: _DayCardsRow(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _kTightGap)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
                child: _StatusMessage(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _kSectionGap)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _kPagePadding),
                child: _SectionTitle(title: 'Streak shop'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _kTightGap)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
                child: _StreakShopGrid(isUnlocked: _isUnlocked),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _kMajorGap)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _kPagePadding),
                child: _SectionTitle(title: 'Earn coins'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _kTightGap)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _kPagePadding),
                child: _EarnMethodsList(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int streakDay = status.active ? status.streakDay.clamp(1, 7) : 0;
        final int claimDay = status.active ? streakDay : 1;
        final int nextDay = status.active ? (status.streakDay >= 7 ? 1 : status.streakDay + 1) : 1;
        final int nextReward = CoinPolicy.streakTotalRewardForDay(nextDay);
        final int todayReward = CoinPolicy.streakTotalRewardForDay(claimDay);

        final String headlineFigure = status.active ? '$streakDay' : '0';
        final String headlineCaption = !status.active
            ? 'Start in Daily rewards'
            : streakDay == 1
            ? 'day in a row'
            : 'days in a row';
        final String nextUnlockLine;
        if (status.claimedToday) {
          nextUnlockLine = 'Tomorrow: +$nextReward coins · day $nextDay';
        } else if (status.active) {
          nextUnlockLine = 'Claim today in Daily rewards for +$todayReward coins';
        } else {
          nextUnlockLine = 'Day 1 pays +${CoinPolicy.streakTotalRewardForDay(1)} coins when you claim';
        }

        final Color top = scheme.primaryContainer;
        final Color bottom = Color.lerp(scheme.primaryContainer, scheme.surface, 0.72)!;
        final bool motion = _streakMotionOn(context);
        final Widget heroChild = ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(_kPagePadding, 16, _kPagePadding, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[top, bottom],
              ),
              border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35), width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    headlineFigure,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  headlineCaption,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  nextUnlockLine,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );

        return AnimatedSwitcher(
          duration: motion ? const Duration(milliseconds: 360) : Duration.zero,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            if (!motion) {
              return child;
            }
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.035),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<String>(
              '${status.claimedToday}_${status.active}_${streakDay}_$claimDay'
              '_${status.streakDay}_$nextReward',
            ),
            child: heroChild,
          ),
        );
      },
    );
  }
}

// ── Day Cards Row ─────────────────────────────────────────────────────────────

class _DayCardsRow extends StatefulWidget {
  @override
  State<_DayCardsRow> createState() => _DayCardsRowState();
}

class _DayCardsRowState extends State<_DayCardsRow> with SingleTickerProviderStateMixin {
  late final AnimationController _rowEntrance;

  @override
  void initState() {
    super.initState();
    _rowEntrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_streakMotionOn(context)) {
        _rowEntrance.forward();
      } else {
        _rowEntrance.value = 1;
      }
    });
  }

  @override
  void dispose() {
    _rowEntrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPro = app_state.prismUser.premium;
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int currentDay = status.active ? status.streakDay.clamp(1, 7) : 0;
        return FadeTransition(
          opacity: CurvedAnimation(parent: _rowEntrance, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: _rowEntrance, curve: Curves.easeOutCubic)),
            child: SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final ColorScheme scheme = Theme.of(context).colorScheme;
                  final int day = index + 1;
                  final int baseReward = CoinPolicy.streakTotalRewardForDay(day);
                  final int proBonus = isPro
                      ? (day == 7 ? CoinPolicy.proStreak7Bonus : CoinPolicy.proStreakDailyBonus)
                      : 0;
                  final int reward = baseReward + proBonus;
                  final bool isCurrent = day == currentDay;
                  final bool isPast = currentDay > 0 && day < currentDay;

                  return Semantics(
                    container: true,
                    label:
                        'Day $day, $reward Prism coins${isCurrent
                            ? ', current day'
                            : isPast
                            ? ', completed'
                            : ''}',
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCurrent ? scheme.primaryContainer : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? scheme.outlineVariant.withValues(alpha: 0.45)
                              : scheme.outlineVariant.withValues(alpha: isPast ? 0.22 : 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Opacity(
                        opacity: isPast ? 0.55 : 1.0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              '+$reward',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: isCurrent ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
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
                                    ? scheme.onPrimaryContainer.withValues(alpha: 0.12)
                                    : scheme.surfaceContainerHighest,
                                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45), width: 0.5),
                              ),
                              child: const PrismCoinIcon(size: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Day $day',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isCurrent ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
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
        if (status.claimedToday) {
          return const SizedBox.shrink();
        }

        final ColorScheme scheme = Theme.of(context).colorScheme;
        final IconData icon;
        final String message;

        if (status.active) {
          icon = Icons.local_fire_department_rounded;
          message = 'Open Daily rewards and claim before the day ends to keep your streak.';
        } else {
          icon = Icons.bolt_rounded;
          message = 'Open Daily rewards and tap Claim to start a 7-day streak.';
        }

        return Semantics(
          container: true,
          label: message,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: _kPagePadding - 4, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4), width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Section title ───────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600, height: 1.25),
    );
  }
}

// ── Streak shop loading (rotating copy, motion-aware) ─────────────────────────

class _StreakShopLoading extends StatefulWidget {
  const _StreakShopLoading();

  @override
  State<_StreakShopLoading> createState() => _StreakShopLoadingState();
}

class _StreakShopLoadingState extends State<_StreakShopLoading> {
  static const List<String> _lines = <String>[
    'Gathering streak-only wallpapers…',
    'Checking what your streak can unlock next…',
    'Preparing the preview grid…',
  ];

  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (MediaQuery.of(context).disableAnimations) {
        return;
      }
      _timer = Timer.periodic(const Duration(milliseconds: 2100), (_) {
        if (mounted) {
          setState(() => _i = (_i + 1) % _lines.length);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool motion = _streakMotionOn(context);
    final String line = _lines[_i];

    return SizedBox(
      height: 200,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Semantics(
                label: 'Loading streak shop',
                child: CircularProgressIndicator(color: scheme.primary),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: motion ? const Duration(milliseconds: 280) : Duration.zero,
                switchInCurve: Curves.easeOutCubic,
                child: Text(
                  line,
                  key: ValueKey<String>(line),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                ),
              ),
            ],
          ),
        ),
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
          return const _StreakShopLoading();
        }
        if (state.status == StreakShopStatus.failure) {
          return Container(
            padding: const EdgeInsets.all(_kPagePadding),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  "Couldn't load streak wallpapers. Check your connection and try again.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
                const SizedBox(height: _kTightGap),
                TextButton(
                  onPressed: () => context.read<StreakShopBloc>().add(const StreakShopLoaded()),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        if (state.items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(_kPagePadding),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'No streak-only wallpapers yet.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'New drops show up here—worth a quick peek later.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35),
                ),
              ],
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
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
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
                          HapticFeedback.lightImpact();
                          final entity = PrismDetailEntity(wallpaper: w);
                          context.router.push(WallpaperDetailRoute(entity: entity));
                        } else {
                          final String req;
                          if (w.requiredStreakDays != null) {
                            req = 'Reach a ${w.requiredStreakDays}-day streak to unlock this wallpaper.';
                          } else if (w.streakShopCoinCost != null) {
                            req = 'Save ${w.streakShopCoinCost} Prism coins to unlock this wallpaper.';
                          } else {
                            req = "You haven't met the unlock requirements yet.";
                          }
                          toasts.codeSend(req);
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
    final MediaQueryData mq = MediaQuery.of(context);
    final int thumbCacheWidth = (mq.size.width / 2 * mq.devicePixelRatio).round().clamp(120, 1600);

    final String categoryLabel = (title == null || title.isEmpty) ? 'Wallpaper' : title;
    final StringBuffer sem = StringBuffer(categoryLabel);
    if (unlocked) {
      sem.write(', unlocked');
    } else {
      sem.write(', locked');
      if (wallpaper.requiredStreakDays != null) {
        sem.write(', needs ${wallpaper.requiredStreakDays}-day streak');
      } else if (wallpaper.streakShopCoinCost != null) {
        sem.write(', needs ${wallpaper.streakShopCoinCost} coins');
      }
    }

    return Semantics(
      button: true,
      label: sem.toString(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  cacheWidth: thumbCacheWidth,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Center(
                      child: Semantics(
                        label: 'Wallpaper preview unavailable',
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ),
                // Greyscale overlay for locked
                if (!unlocked)
                  Container(
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.42)),
                  ),
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          'STREAK COLLECTION',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Streak day badge (top right)
                if (wallpaper.requiredStreakDays != null)
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: unlocked
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.5),
                      ),
                      child: Center(
                        child: unlocked
                            ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 16)
                            : Text(
                                '${wallpaper.requiredStreakDays}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
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
    final Color accent = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _EarnItem(
          icon: Icons.play_circle_outline,
          label: 'Watch a short video',
          amount: '+${CoinPolicy.rewardedAd}c',
          accentColor: accent,
          spacingBelow: _kTightGap,
        ),
        _EarnItem(
          icon: Icons.people_outline,
          label: 'Invite a friend',
          amount: '+${CoinPolicy.referral}c',
          accentColor: accent,
          spacingBelow: 0,
        ),
      ],
    );
  }
}

class _EarnItem extends StatelessWidget {
  const _EarnItem({
    required this.icon,
    required this.label,
    required this.amount,
    required this.accentColor,
    required this.spacingBelow,
  });

  final IconData icon;
  final String label;
  final String amount;
  final Color accentColor;
  final double spacingBelow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: spacingBelow),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _kPagePadding - 4, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, height: 1.3),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                amount,
                style: TextStyle(color: accentColor, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
