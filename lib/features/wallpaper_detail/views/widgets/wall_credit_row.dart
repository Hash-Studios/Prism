import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/wall_credit.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Who made a wall and where the credit opens, at the start of the info panel.
class WallCreditRow extends StatelessWidget {
  const WallCreditRow({super.key, required this.credit});

  final WallCredit credit;

  static const double _avatarSize = 26;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool tappable = credit.profileUid != null || credit.externalUrl != null;
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_primaryLine(context) case final String primary)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showsAvatar) ...[_avatar(context), const SizedBox(width: PrismSpace.xs)],
              Flexible(
                child: Text(
                  primary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: PrismTextStyles.rowTitle(context).copyWith(color: cs.onSurface),
                ),
              ),
            ],
          ),
        if (_secondaryLine(context) case (final IconData icon, final String text))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.caption(context),
                  ),
                ),
              ],
            ),
          ),
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

  bool get _showsAvatar => credit.provenance == WallProvenance.creator || credit.provenance == WallProvenance.studio;

  String? _primaryLine(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return switch (credit.provenance) {
      WallProvenance.studio => l10n.wallCreditByHashStudios,
      WallProvenance.creator ||
      WallProvenance.wallhaven => credit.name == null ? null : l10n.wallCreditBy(credit.name!),
      WallProvenance.pexels => credit.name == null ? null : l10n.wallCreditPhotoBy(credit.name!),
    };
  }

  (IconData, String)? _secondaryLine(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (credit.provenance.isPrismExclusive) return (Icons.verified_rounded, l10n.wallCreditPrismExclusive);
    return switch (credit.provenance) {
      WallProvenance.pexels => (Icons.storage_rounded, l10n.wallCreditOnPexels),
      WallProvenance.wallhaven => (Icons.storage_rounded, l10n.wallCreditOnWallhaven),
      WallProvenance.creator || WallProvenance.studio => null,
    };
  }

  Widget _avatar(BuildContext context) {
    final String? name = credit.name ?? (credit.provenance == WallProvenance.studio ? WallCredit.studioName : null);
    return PrismAvatar(url: credit.photoUrl, name: name, size: _avatarSize);
  }

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
