import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Asks whether the next upload is a still photo or a live wall. Null when the sheet is dismissed.
Future<WallKind?> showUploadKindSheet(BuildContext context) {
  return showPrismSheet<WallKind>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
    builder: (sheetContext) {
      final AppLocalizations l10n = sheetContext.l10n;
      return PrismSheetBody(
        title: l10n.uploadKindTitle,
        child: PrismGroup(
          children: <Widget>[
            _KindRow(
              icon: Icons.image_outlined,
              title: l10n.uploadKindPhoto,
              subtitle: l10n.uploadKindPhotoBody,
              onTap: () => Navigator.of(sheetContext).pop(WallKind.still),
            ),
            _KindRow(
              icon: Icons.motion_photos_on_rounded,
              title: l10n.uploadKindLive,
              subtitle: l10n.uploadKindLiveBody,
              onTap: () => Navigator.of(sheetContext).pop(WallKind.live),
            ),
          ],
        ),
      );
    },
  );
}

class _KindRow extends StatelessWidget {
  const _KindRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      onTap: onTap,
      excludeSemantics: true,
      child: PrismRow(icon: icon, title: title, subtitle: subtitle, onTap: onTap),
    );
  }
}
