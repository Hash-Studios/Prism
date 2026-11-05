import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/wall_credit.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where a wall is from and where the credit opens, at the start of the info panel.
class WallCreditRow extends StatelessWidget {
  const WallCreditRow({super.key, required this.credit});

  final WallCredit credit;

  @override
  Widget build(BuildContext context) {
    // The summary above names the creator, so the details say only where the wall is from.
    final (IconData icon, String text) = _sourceLine(context.l10n);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool tappable = credit.profileUid != null || credit.externalUrl != null;
    final bool external = credit.profileUid == null && credit.externalUrl != null;
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: PrismTextStyles.body(context)),
        ),
        if (external) ...[
          const SizedBox(width: PrismSpace.xxs),
          Icon(Icons.open_in_new_rounded, size: 16, color: cs.onSurfaceVariant),
        ],
      ],
    );
    if (!tappable) return content;
    return Semantics(
      button: true,
      hint: credit.profileUid != null ? context.l10n.wallCreditOpenProfileHint : context.l10n.wallCreditOpenSourceHint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _open(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(alignment: AlignmentDirectional.centerStart, child: content),
          ),
        ),
      ),
    );
  }

  (IconData, String) _sourceLine(AppLocalizations l10n) => switch (credit.provenance) {
    WallProvenance.creator || WallProvenance.studio => (Icons.verified_rounded, l10n.wallCreditPrismExclusive),
    WallProvenance.pexels => (Icons.storage_rounded, l10n.wallCreditOnPexels),
    WallProvenance.wallhaven => (Icons.storage_rounded, l10n.wallCreditOnWallhaven),
  };

  Future<void> _open(BuildContext context) async {
    final String? profileUid = credit.profileUid;
    if (profileUid != null) {
      PrismHaptics.tap();
      context.router.push(ProfileRoute(profileIdentifier: profileUid));
      return;
    }
    final Uri? externalUrl = credit.externalUrl;
    if (externalUrl == null) return;
    final bool ok = await launchUrl(externalUrl, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) toasts.error(context.l10n.wallpaperProfileOpenError);
  }
}
