import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism/prism_section.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// "Use your coins": what coins buy, with the price of each. Streak freeze runs [onStreakFreeze].
class RewardsSpendSection extends StatelessWidget {
  const RewardsSpendSection({super.key, this.onStreakFreeze});

  final VoidCallback? onStreakFreeze;

  @override
  Widget build(BuildContext context) {
    final int graceLeft = CoinsService.instance.graceDownloadsLeft;
    final bool isPro = app_state.prismUser.premium;
    final int aiFrom = proPrice(CoinPolicy.aiGenerationFast, isPro);
    final int dropWall = proPrice(CoinPolicy.dropWall, isPro);
    final int shopFrom = shopFromPrice(DateTime.now());
    final String? graceNote = graceLeft <= 0
        ? null
        : graceLeft == CoinPolicy.graceDownloads
        ? context.l10n.economyFirstDownloadsFree(graceLeft)
        : context.l10n.economyFreeDownloadsLeft(graceLeft);
    final List<_SpendTile> tiles = <_SpendTile>[
      _SpendTile(
        icon: Icons.auto_awesome_rounded,
        label: context.l10n.economyAiWallpaper,
        price: context.l10n.economyPriceFrom(aiFrom),
        spokenPrice: context.l10n.economyPriceFromCoins(aiFrom),
        onTap: () => context.router.root.push(AiTabRoute()),
      ),
      _SpendTile(
        icon: Icons.lock_open_rounded,
        label: context.l10n.economyDrops,
        price: context.l10n.economyPriceCoinsPerWall(dropWall),
        spokenPrice: context.l10n.economyPriceCoinsPerWallSemantics(dropWall),
        onTap: () => context.router.root.push(const DropsRoute()),
      ),
      _SpendTile(
        icon: Icons.storefront_outlined,
        label: context.l10n.economyShopTitle,
        price: context.l10n.economyPriceFrom(shopFrom),
        spokenPrice: context.l10n.economyPriceFromCoins(shopFrom),
        onTap: () => context.router.root.push(const ShopRoute()),
      ),
      _SpendTile(
        icon: Icons.workspace_premium_rounded,
        label: context.l10n.economyPremiumCollection,
        price: context.l10n.economyPriceForHours(CoinPolicy.premiumPreview24h, 24),
        spokenPrice: context.l10n.economyPriceCoinsForHours(CoinPolicy.premiumPreview24h, 24),
        onTap: () =>
            context.router.root.navigate(const DashboardRoute(children: <PageRouteInfo>[CollectionTabRoute()])),
      ),
      _SpendTile(
        icon: Icons.rocket_launch_outlined,
        label: context.l10n.economyBoost,
        price: '${CoinPolicy.boostWall}',
        spokenPrice: context.l10n.economyPriceCoins(CoinPolicy.boostWall),
        onTap: () => _showInfo(
          context,
          title: context.l10n.economyBoost,
          body: context.l10n.economyBoostInfo(CoinPolicy.boostWall),
          showPro: false,
        ),
      ),
      _SpendTile(
        icon: Icons.card_giftcard_rounded,
        label: context.l10n.economyGiftPass,
        price: '${CoinPolicy.giftPremiumPass}',
        spokenPrice: context.l10n.economyPriceCoins(CoinPolicy.giftPremiumPass),
        onTap: () => _showInfo(
          context,
          title: context.l10n.economyGiftPass,
          body: context.l10n.economyGiftPassInfo(CoinPolicy.giftPremiumPass),
          showPro: false,
        ),
      ),
      _SpendTile(
        icon: Icons.ac_unit_rounded,
        label: context.l10n.economyStreakFreeze,
        price: '${CoinPolicy.streakFreezeCost}',
        spokenPrice: context.l10n.economyPriceCoins(CoinPolicy.streakFreezeCost),
        onTap: onStreakFreeze,
        haptic: false,
      ),
      _SpendTile(
        icon: Icons.download_rounded,
        label: context.l10n.economyDownloads,
        price: '${CoinPolicy.wallpaperDownload}',
        note: graceNote,
        spokenPrice: context.l10n.economyPriceCoinsWithNote(
          CoinPolicy.wallpaperDownload,
          (graceNote != null).toString(),
          graceNote ?? '',
        ),
        onTap: () => _showInfo(
          context,
          title: context.l10n.economyDownloads,
          body: context.l10n.economyDownloadsInfo(
            CoinPolicy.wallpaperDownload,
            CoinPolicy.graceDownloads,
            (graceNote != null).toString(),
          ),
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismSectionHeader(
          title: context.l10n.economyUseYourCoins,
          padding: EdgeInsets.only(top: PrismSpace.xxl, bottom: PrismSpace.sm),
        ),
        for (int i = 0; i < tiles.length; i += 2) ...<Widget>[
          if (i > 0) const SizedBox(height: PrismSpace.xs + 2),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: tiles[i]),
                const SizedBox(width: PrismSpace.xs + 2),
                Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static void _showInfo(BuildContext context, {required String title, required String body, bool showPro = true}) {
    showPrismSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => PrismSheetBody(
        title: title,
        message: body,
        actions: <Widget>[
          if (showPro)
            PrismButton(
              label: sheetContext.l10n.economySeePro,
              expand: true,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                PaywallOrchestrator.instance.presentOrRequireSignIn(
                  context,
                  placement: PaywallPlacement.mainUpsell,
                  source: 'rewards_spend_sheet',
                );
              },
            ),
          PrismButton(
            label: sheetContext.l10n.actionClose,
            expand: true,
            variant: showPro ? PrismButtonVariant.ghost : PrismButtonVariant.primary,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    );
  }
}

class _SpendTile extends StatelessWidget {
  const _SpendTile({
    required this.icon,
    required this.label,
    required this.price,
    required this.spokenPrice,
    required this.onTap,
    this.note,
    this.haptic = true,
  });

  final IconData icon;
  final String label;
  final String price;
  final String spokenPrice;
  final VoidCallback? onTap;

  /// A second caption line under the price, for example "first 3 free".
  final String? note;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    void handleTap() {
      if (haptic) PrismHaptics.tap();
      onTap?.call();
    }

    return PrismCard(
      onTap: onTap == null ? null : handleTap,
      semanticLabel: context.l10n.economySpendItemSemantics(label, spokenPrice),
      padding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(PrismRadius.xs + 2),
                ),
                child: Icon(icon, size: 20, color: cs.onSurface),
              ),
              const SizedBox(height: PrismSpace.sm),
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
              const SizedBox(height: PrismSpace.xs),
              Row(
                children: <Widget>[
                  const PrismCoinIcon(size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      price,
                      style: PrismTextStyles.caption(
                        context,
                      ).copyWith(color: cs.onSurface.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (note != null) Text(note!, style: PrismTextStyles.caption(context)),
            ],
          ),
        ),
      ),
    );
  }
}
