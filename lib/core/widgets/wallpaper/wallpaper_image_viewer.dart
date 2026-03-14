import 'dart:io';

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

typedef ColorChangedCallback = void Function(bool colorChanged);
typedef AccentChangedCallback = void Function();
typedef PanelOpenedCallback = void Function();

class WallpaperImageViewer extends StatelessWidget {
  const WallpaperImageViewer({
    super.key,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.accent,
    required this.colorChanged,
    required this.screenshotController,
    required this.panelController,
    required this.panelCollapsed,
    required this.panelClosed,
    required this.onAccentTap,
    required this.onAccentLongPress,
    required this.onPanelOpened,
    required this.onPanelClosed,
    required this.imageFile,
    required this.screenshotTaken,
    required this.offsetAnimation,
    required this.paletteLoading,
    required this.onBackTap,
    required this.onClockTap,
  });

  final String imageUrl;
  final String thumbnailUrl;
  final Color? accent;
  final bool colorChanged;
  final ScreenshotController screenshotController;
  final PanelController panelController;
  final bool panelCollapsed;
  final bool panelClosed;
  final AccentChangedCallback onAccentTap;
  final VoidCallback onAccentLongPress;
  final PanelOpenedCallback onPanelOpened;
  final VoidCallback onPanelClosed;
  final File? imageFile;
  final bool screenshotTaken;
  final Animation<double> offsetAnimation;
  final bool paletteLoading;
  final VoidCallback onBackTap;
  final VoidCallback onClockTap;

  String _resolveImageUrl() {
    if (screenshotTaken && imageFile != null) {
      return imageFile!.path;
    }
    final direct = thumbnailUrl.trim();
    if (_isResolvableImageInput(direct)) {
      return direct;
    }
    return imageUrl.trim();
  }

  bool _isResolvableImageInput(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('/')) return true;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolveImageUrl();
    final isFile = screenshotTaken && imageFile != null;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: offsetAnimation,
          builder: (context, child) {
            return GestureDetector(
              onPanUpdate: (details) {
                if (details.delta.dy < -10) {
                  panelController.open();
                }
              },
              onLongPress: onAccentLongPress,
              onTap: onAccentTap,
              child: isFile
                  ? Screenshot(
                      controller: screenshotController,
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          vertical: offsetAnimation.value * 1.25,
                          horizontal: offsetAnimation.value / 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(offsetAnimation.value),
                          image: DecorationImage(
                            colorFilter: colorChanged ? ColorFilter.mode(accent!, BlendMode.hue) : null,
                            image: FileImage(imageFile!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: resolvedUrl,
                      imageBuilder: (context, imageProvider) => Screenshot(
                        controller: screenshotController,
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            vertical: offsetAnimation.value * 1.25,
                            horizontal: offsetAnimation.value / 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(offsetAnimation.value),
                            image: DecorationImage(
                              colorFilter: colorChanged ? ColorFilter.mode(accent!, BlendMode.hue) : null,
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                        children: [
                          const SizedBox.expand(child: Text("")),
                          Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error),
                              value: downloadProgress.progress,
                            ),
                          ),
                        ],
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Icon(
                          JamIcons.close_circle_f,
                          color: paletteLoading
                              ? Theme.of(context).colorScheme.secondary
                              : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
            );
          },
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
            child: IconButton(
              onPressed: onBackTap,
              color: paletteLoading
                  ? Theme.of(context).colorScheme.secondary
                  : accent!.computeLuminance() > 0.5
                  ? Colors.black
                  : Colors.white,
              icon: const Icon(JamIcons.chevron_left),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
            child: IconButton(
              onPressed: onClockTap,
              color: paletteLoading
                  ? Theme.of(context).colorScheme.secondary
                  : accent!.computeLuminance() > 0.5
                  ? Colors.black
                  : Colors.white,
              icon: const Icon(JamIcons.clock),
            ),
          ),
        ),
      ],
    );
  }
}
