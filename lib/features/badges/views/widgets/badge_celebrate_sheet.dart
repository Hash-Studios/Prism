import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Shows the sheet for one new badge. [onSeeRewards] runs after the sheet closes with "See badges".
Future<void> showBadgeCelebrateSheet(BuildContext context, EarnedBadge badge, {VoidCallback? onSeeRewards}) async {
  PrismHaptics.success();
  final bool? seeRewards = await showPrismSheet<bool>(context, builder: (_) => BadgeCelebrateSheet(badge: badge));
  if (seeRewards == true) onSeeRewards?.call();
}

class BadgeCelebrateSheet extends StatelessWidget {
  const BadgeCelebrateSheet({super.key, required this.badge});

  final EarnedBadge badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BadgeInfo? info = badgeInfo(badge.id);
    final bool inlineApproval = DailyMomentConfig.enabled && badge.id == 'creator';
    final bool small = MediaQuery.sizeOf(context).height < 700;
    return PrismSheetBody(
      title: context.l10n.economyNewBadge,
      actions: <Widget>[
        PrismButton(label: context.l10n.economyNice, expand: true, onPressed: () => Navigator.of(context).pop(false)),
        PrismButton(
          label: context.l10n.economySeeBadges,
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Glint(mood: inlineApproval ? GlintMood.calm : GlintMood.celebrate, size: small ? 88 : 140),
          const SizedBox(height: PrismSpace.xs),
          Text(
            info?.name(context.l10n) ?? context.l10n.economyBadgeEarned,
            textAlign: TextAlign.center,
            style: PrismTextStyles.sheetHeadline(context),
          ),
          if (info != null) ...<Widget>[
            const SizedBox(height: PrismSpace.xxs),
            if (!inlineApproval)
              Text(info.description(context.l10n), textAlign: TextAlign.center, style: PrismTextStyles.body(context))
            else
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  Text(
                    info.description(context.l10n),
                    textAlign: TextAlign.center,
                    style: PrismTextStyles.body(context),
                  ),
                  if (badge.coins > 0)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        context.l10n.economyCoinsEarned(badge.coins),
                        style: PrismTextStyles.rowTitle(context).copyWith(color: cs.primary),
                      ),
                    ),
                ],
              ),
          ],
          if (!inlineApproval && badge.coins > 0) ...<Widget>[
            const SizedBox(height: PrismSpace.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const PrismCoinIcon(size: 32),
                const SizedBox(width: 10),
                Text(
                  '+${formatLocalizedNumber(badge.coins, context.l10n)}',
                  style: PrismTextStyles.numeral(context, 44),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
