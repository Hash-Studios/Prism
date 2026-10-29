import 'dart:io';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

String appliedTargetLabel(AppLocalizations l10n, String target) => switch (target) {
  'home' => l10n.wallpaperAutoRotateHomeScreen,
  'lock' => l10n.wallpaperAutoRotateLockScreen,
  'both' => l10n.wallpaperHistoryBothScreens,
  'set' => l10n.historyActionSet,
  'download' => l10n.historyActionDownloaded,
  _ => target,
};

/// Room under a tile for the screen and the time, at the current text size.
double appliedWallpaperFooterHeight(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5).scale(36) + PrismSpace.xs;

/// One wallpaper in history: the image, what happened to it and when. A tap opens it; the button on the image, when
/// given, sets it again. A recently viewed tile shows only the time.
class AppliedWallpaperTile extends StatelessWidget {
  const AppliedWallpaperTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onSetAgain,
    this.onRemove,
    this.isCurrent = false,
  });

  final AppliedWallpaper item;
  final VoidCallback onTap;
  final VoidCallback? onSetAgain;

  /// Removes the tile from the list. Offered on long press and as a screen reader action.
  final VoidCallback? onRemove;

  /// True for the newest home or lock tile, which is what Prism last set on that screen.
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = context.l10n;
    final bool viewed = item.target == 'view';
    final String target = viewed ? '' : appliedTargetLabel(l10n, item.target);
    final String time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(item.appliedAt.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final String label = switch (item.target) {
      'view' => l10n.historyViewedTileLabel(time),
      'set' || 'download' => l10n.historySyncedTileLabel(target, time),
      _ => l10n.wallpaperHistoryTileLabel(isCurrent ? l10n.wallpaperHistoryCurrentPrefix : '', target, time),
    };
    final Widget placeholder = ColoredBox(color: scheme.surfaceContainerHigh);
    final String thumbnail = item.thumbnailUrl.isEmpty ? item.fullUrl : item.thumbnailUrl;
    final Widget image = thumbnail.startsWith('http')
        ? PrismImageTile(url: thumbnail, memCacheWidth: 400)
        : Image.file(File(thumbnail), fit: BoxFit.cover, cacheWidth: 400, errorBuilder: (_, _, _) => placeholder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: PressScale(
            scale: 0.97,
            child: Semantics(
              button: true,
              image: true,
              label: label,
              customSemanticsActions: onRemove == null
                  ? null
                  : <CustomSemanticsAction, VoidCallback>{
                      CustomSemanticsAction(label: l10n.wallpaperHistoryRemoveAction): onRemove!,
                    },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                onLongPress: onRemove,
                child: ClipRRect(
                  borderRadius: PrismWallGrid.tileRadius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      placeholder,
                      image,
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: PrismWallGrid.tileRadius,
                            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
                          ),
                        ),
                      ),
                      if (isCurrent)
                        PositionedDirectional(
                          start: PrismSpace.xs,
                          top: PrismSpace.xs,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(color: scheme.primary, shape: const StadiumBorder()),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: 3),
                              child: Text(
                                l10n.wallpaperHistoryCurrent,
                                style: PrismTextStyles.caption(
                                  context,
                                ).copyWith(color: onColor(scheme.primary), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      if (onSetAgain != null)
                        PositionedDirectional(
                          end: PrismSpace.xxs,
                          bottom: PrismSpace.xxs,
                          child: PrismIconButton(
                            icon: Icons.replay_rounded,
                            tooltip: l10n.wallpaperHistorySetAgain,
                            onImage: true,
                            iconSize: 20,
                            onPressed: onSetAgain,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: appliedWallpaperFooterHeight(context),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: PrismSpace.xxs),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (!viewed)
                      Text(
                        target,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 13),
                      ),
                    Text(time, maxLines: 1, overflow: TextOverflow.ellipsis, style: PrismTextStyles.caption(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
