import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// "Use your coins": what coins buy, with the price of each. Streak freeze runs [onStreakFreeze].
class RewardsSpendSection extends StatelessWidget {
  const RewardsSpendSection({super.key, this.onStreakFreeze});

  final VoidCallback? onStreakFreeze;

  @override
  Widget build(BuildContext context) {
    final List<_SpendTile> tiles = <_SpendTile>[
      _SpendTile(
        icon: Icons.auto_awesome_rounded,
        label: 'AI wallpaper',
        price: 'from ${CoinPolicy.aiGenerationFast}',
        onTap: () => context.router.root.push(AiTabRoute()),
      ),
      _SpendTile(
        icon: Icons.workspace_premium_rounded,
        label: 'Premium collection',
        price: '${CoinPolicy.premiumPreview24h} for 24 h',
        onTap: () =>
            context.router.root.navigate(const DashboardRoute(children: <PageRouteInfo>[CollectionTabRoute()])),
      ),
      _SpendTile(
        icon: Icons.image_outlined,
        label: 'Premium wallpaper',
        price: '${CoinPolicy.premiumWallpaperDownload}',
        onTap: () => _showInfo(
          context,
          title: 'Premium wallpaper',
          body:
              'Downloading a premium wallpaper costs ${CoinPolicy.premiumWallpaperDownload} coins. Pro makes it free.',
        ),
      ),
      _SpendTile(
        icon: Icons.tune_rounded,
        label: 'Filters',
        price: '${CoinPolicy.premiumFilter} per edit',
        onTap: () => _showInfo(
          context,
          title: 'Filters',
          body: 'Each premium filter edit costs ${CoinPolicy.premiumFilter} coins. Pro makes filters free.',
        ),
      ),
      _SpendTile(
        icon: Icons.ac_unit_rounded,
        label: 'Streak freeze',
        price: '${CoinPolicy.streakFreezeCost}',
        onTap: onStreakFreeze,
      ),
      _SpendTile(
        icon: Icons.download_rounded,
        label: 'Downloads',
        price: '${CoinPolicy.wallpaperDownload}',
        onTap: () => _showInfo(
          context,
          title: 'Downloads',
          body: 'Each wallpaper download costs ${CoinPolicy.wallpaperDownload} coins. Pro makes downloads free.',
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle('Use your coins'),
          const SizedBox(height: 12),
          for (int i = 0; i < tiles.length; i += 2) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(child: tiles[i]),
                const SizedBox(width: 10),
                Expanded(child: tiles[i + 1]),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static void _showInfo(BuildContext context, {required String title, required String body}) {
    showPrismSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  PaywallOrchestrator.instance.presentOrRequireSignIn(
                    context,
                    placement: PaywallPlacement.mainUpsell,
                    source: 'rewards_spend_sheet',
                  );
                },
                child: const Text('See Pro'),
              ),
              TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Close')),
            ],
          ),
        );
      },
    );
  }
}

class _SpendTile extends StatelessWidget {
  const _SpendTile({required this.icon, required this.label, required this.price, required this.onTap});

  final IconData icon;
  final String label;
  final String price;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: '$label, $price coins',
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const PrismCoinIcon(size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700));
  }
}
