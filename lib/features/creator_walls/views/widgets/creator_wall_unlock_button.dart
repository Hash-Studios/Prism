import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_walls/data/creator_wall_unlocks.dart';
import 'package:Prism/features/creator_walls/views/widgets/creator_wall_unlock_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The primary action on a priced wall's detail page. It replaces Set and Download until the buyer unlocks the wall.
/// [onUnlocked] runs when the unlock sheet reports the wall opened.
class CreatorWallUnlockButton extends StatelessWidget {
  const CreatorWallUnlockButton({super.key, required this.wall, this.checking = false, this.onUnlocked, this.unlocks});

  final PrismWallpaper wall;

  /// True while the unlock marker is being read. Shows a spinner and blocks taps.
  final bool checking;

  final VoidCallback? onUnlocked;

  @visibleForTesting
  final CreatorWallUnlocks? unlocks;

  @override
  Widget build(BuildContext context) {
    return PrismButton(
      label: context.l10n.creatorWallUnlockButton(wall.creatorPrice),
      trailing: const PrismCoinIcon(size: 18),
      loading: checking,
      haptic: false,
      onPressed: () async {
        if (!await requireSignedInAction(context) || !context.mounted) return;
        final String wallDocId = wall.firestoreDocumentId?.trim() ?? '';
        final CreatorWallUnlocks store = unlocks ?? CreatorWallUnlocks.instance;
        if (wallDocId.isNotEmpty) store.invalidate(wallDocId);
        final bool unlocked = await showCreatorWallUnlockSheet(context, wall: wall, unlocks: store);
        if (unlocked) onUnlocked?.call();
      },
    );
  }
}
