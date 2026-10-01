import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Shows the sheet for one new badge. [onSeeRewards] runs after the sheet closes with "See badges".
Future<void> showBadgeCelebrateSheet(BuildContext context, EarnedBadge badge, {VoidCallback? onSeeRewards}) async {
  PrismHaptics.success();
  final bool? seeRewards = await showPrismSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => BadgeCelebrateSheet(badge: badge),
  );
  if (seeRewards == true) onSeeRewards?.call();
}

class BadgeCelebrateSheet extends StatelessWidget {
  const BadgeCelebrateSheet({super.key, required this.badge});

  final EarnedBadge badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BadgeInfo? info = badgeInfo(badge.id);
    final bool small = MediaQuery.sizeOf(context).height < 700;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Glint(mood: GlintMood.celebrate, size: small ? 88 : 140),
            const SizedBox(height: 8),
            Text('New badge', style: PrismTextStyles.caption(context)),
            const SizedBox(height: 4),
            Text(
              info?.name ?? 'Badge earned',
              textAlign: TextAlign.center,
              style: PrismTextStyles.sheetHeadline(context),
            ),
            if (info != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(info.description, textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
            ],
            if (badge.coins > 0) ...<Widget>[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const PrismCoinIcon(size: 32),
                  const SizedBox(width: 10),
                  Text('+${badge.coins}', style: PrismTextStyles.numeral(context, 44)),
                ],
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                  textStyle: PrismTextStyles.rowTitle(context),
                ),
                child: const Text('Nice'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                PrismHaptics.tap();
                Navigator.of(context).pop(true);
              },
              child: Text('See badges', style: PrismTextStyles.rowTitle(context).copyWith(color: cs.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
