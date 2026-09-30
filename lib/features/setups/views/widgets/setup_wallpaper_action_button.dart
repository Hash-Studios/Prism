import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/setup_wallpaper_extensions.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

enum SetupWallpaperAction { download, setWallpaper }

/// Circular raised surface behind the round action buttons of the setup detail panel.
class SetupActionCircle extends StatelessWidget {
  const SetupActionCircle({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.primaryColor,
        boxShadow: [
          BoxShadow(color: theme.shadowColor.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 4)),
        ],
        borderRadius: BorderRadius.circular(500),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Downloads or sets the setup wallpaper in-app when it is a Prism wall, and opens its link otherwise.
class SetupWallpaperActionButton extends StatelessWidget {
  const SetupWallpaperActionButton({super.key, required this.setup, required this.action});

  final SetupEntity setup;
  final SetupWallpaperAction action;

  @override
  Widget build(BuildContext context) {
    final wallpaper = setup.wallpaperValue;
    if (!wallpaper.isEncoded && setup.wallId.isNotEmpty) {
      return switch (action) {
        SetupWallpaperAction.download => DownloadButton(link: wallpaper.primaryUrl, colorChanged: false),
        SetupWallpaperAction.setWallpaper => SetWallpaperButton(url: wallpaper.primaryUrl, colorChanged: false),
      };
    }
    final String link = wallpaper.isEncoded ? wallpaper.deepLinkUrl ?? wallpaper.primaryUrl : wallpaper.primaryUrl;
    return GestureDetector(
      onTap: () => openPrismLink(context, link),
      child: SetupActionCircle(
        padding: const EdgeInsets.all(17),
        child: Icon(
          action == SetupWallpaperAction.download ? JamIcons.download : JamIcons.picture,
          color: Theme.of(context).colorScheme.secondary,
          size: 20,
        ),
      ),
    );
  }
}
