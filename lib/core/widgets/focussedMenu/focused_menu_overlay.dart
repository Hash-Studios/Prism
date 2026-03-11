import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/widgets/focussedMenu/focused_menu_data.dart';
import 'package:Prism/core/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/core/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class FocusedMenuOverlay extends StatefulWidget {
  const FocusedMenuOverlay({
    super.key,
    required this.menuData,
    required this.childOffset,
    required this.childSize,
    required this.child,
  });

  final FocusedMenuData menuData;
  final Offset childOffset;
  final Size childSize;
  final Widget child;

  @override
  State<FocusedMenuOverlay> createState() => _FocusedMenuOverlayState();
}

class _FocusedMenuOverlayState extends State<FocusedMenuOverlay> {
  bool _showActionButtons = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showActionButtons = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuData = widget.menuData;
    final childOffset = widget.childOffset;
    final childSize = widget.childSize;
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    final maxMenuWidth = size.width * 0.63;
    final menuHeight = size.height * 0.14;

    final bool renderRight = (childOffset.dx + maxMenuWidth) < size.width;
    final bool renderBottom = (childOffset.dy + menuHeight + childSize.height) < size.height;

    final double leftOffset = renderRight
        ? orientation == Orientation.portrait
              ? childOffset.dx + childSize.width + size.width * 0.015
              : childOffset.dx + childSize.width + size.width * 0.01
        : orientation == Orientation.portrait
        ? (childOffset.dx - maxMenuWidth + childSize.width)
        : (childOffset.dx - maxMenuWidth + childSize.width + size.width * 0.3);

    final double topOffset = renderBottom
        ? childOffset.dy + childSize.height + size.width * 0.015
        : orientation == Orientation.portrait
        ? childOffset.dy - menuHeight + size.width * 0.125
        : childOffset.dy - menuHeight;

    final double fabHeartTopOffset = renderBottom
        ? orientation == Orientation.portrait
              ? size.width * 0.175
              : size.width * 0.1
        : orientation == Orientation.portrait
        ? -size.width * 0.175
        : -size.width * 0.1;

    final double fabWallLeftOffset = renderRight
        ? orientation == Orientation.portrait
              ? -size.width * 0.175
              : -size.width * 0.1
        : orientation == Orientation.portrait
        ? size.width * 0.175
        : size.width * 0.1;

    final double fabWallTopOffset = renderBottom
        ? orientation == Orientation.portrait
              ? size.width * 0.05
              : size.width * 0.02
        : orientation == Orientation.portrait
        ? -size.width * 0.05
        : -size.width * 0.02;

    final double fabHeartLeftOffset = renderRight
        ? orientation == Orientation.portrait
              ? -size.width * 0.05
              : -size.width * 0.02
        : orientation == Orientation.portrait
        ? size.width * 0.05
        : size.width * 0.02;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: context.prismModeStyleForContext(listen: false) == 'Dark'
                  ? Colors.black.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.75),
            ),
          ),
          Positioned(
            top: childOffset.dy,
            left: childOffset.dx,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: AbsorbPointer(
                child: RepaintBoundary(
                  child: SizedBox(width: childSize.width, height: childSize.height, child: widget.child),
                ),
              ),
            ),
          ),
          Positioned(
            top: childOffset.dy + childSize.height * menuData.cardTopFactor,
            left: childOffset.dx,
            child: RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 200),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(scale: value, alignment: Alignment.bottomRight, child: child);
                },
                child: Container(
                  width: childSize.width,
                  height: childSize.height * menuData.cardHeightFactor,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor,
                    borderRadius: const BorderRadius.all(Radius.circular(20.0)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(20.0)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(15, 7, 15, 15),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              ActionChip(
                                pressElevation: 5,
                                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                                avatar: Icon(menuData.titleIcon, color: menuData.titleForegroundColor, size: 20),
                                backgroundColor: menuData.titleBackgroundColor ?? Colors.black,
                                label: Text(
                                  menuData.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium!.copyWith(color: menuData.titleForegroundColor),
                                ),
                                onPressed: menuData.onTitleTap == null ? null : () => menuData.onTitleTap!(context),
                              ),
                              Text(
                                menuData.subtitle,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                              ),
                              for (final stat in menuData.stats.take(3))
                                Row(
                                  children: [
                                    Icon(stat.icon, size: 20, color: Theme.of(context).colorScheme.secondary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        stat.label,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).hintColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                              child: Icon(JamIcons.close, color: Theme.of(context).colorScheme.secondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showActionButtons)
            RepaintBoundary(
              child: Stack(
                children: [
                  if (!hideSetWallpaperUi)
                    Positioned(
                      top: topOffset,
                      left: leftOffset,
                      child: SetWallpaperButton(colorChanged: false, url: menuData.fullUrl),
                    ),
                  Positioned(
                    top: topOffset - fabHeartTopOffset,
                    left: leftOffset - fabHeartLeftOffset,
                    child: FavouriteWallpaperButton(wall: menuData.favouriteWall, trash: menuData.favouriteTrash),
                  ),
                  Positioned(
                    top: topOffset + fabWallTopOffset,
                    left: leftOffset + fabWallLeftOffset,
                    child: DownloadButton(
                      colorChanged: false,
                      link: menuData.fullUrl,
                      isPremiumContent: menuData.isPremiumContent,
                      contentId: menuData.contentId,
                      sourceContext: menuData.sourceContext,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
