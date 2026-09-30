import 'dart:io';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClockOverlay extends StatelessWidget {
  final String link;
  final bool file;
  final Color? accent;
  final bool colorChanged;
  const ClockOverlay({required this.link, required this.file, required this.accent, required this.colorChanged});

  /// Superscript ordinal suffix for a day of the month: 1ˢᵗ, 2ⁿᵈ, 3ʳᵈ, 4ᵗʰ, 11ᵗʰ.
  @visibleForTesting
  static String ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'ᵗʰ';
    return switch (day % 10) {
      1 => 'ˢᵗ',
      2 => 'ⁿᵈ',
      3 => 'ʳᵈ',
      _ => 'ᵗʰ',
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = DateFormat('EEEE').format(now);
    final month = DateFormat('MMMM').format(now);
    final Color textColor = accent == null ? Colors.white : onColor(accent!);
    final bool iosPreview = defaultTargetPlatform == TargetPlatform.iOS;
    final Size screen = MediaQuery.sizeOf(context);
    final TextStyle base = PrismTextStyles.screenTitle(context).copyWith(color: textColor);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: <Widget>[
          if (!file)
            CachedNetworkImage(
              imageUrl: link,
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    colorFilter: colorChanged ? ColorFilter.mode(accent!, BlendMode.hue) : null,
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: screen.height,
              width: screen.width,
              child: Image.file(
                File(link),
                color: accent,
                colorBlendMode: colorChanged ? BlendMode.color : null,
                fit: BoxFit.cover,
              ),
            ),
          if (textColor == Colors.white)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0, 0.4, 0.8, 1],
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
                child: SizedBox(height: screen.height, width: screen.width),
              ),
            ),
          if (iosPreview)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: PrismSpace.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(DateFormat('EEEE d MMMM').format(now), style: base.copyWith(fontSize: 20)),
                      Text(DateFormat('h:mm').format(now), style: base.copyWith(fontSize: 96, height: 1.1)),
                    ],
                  ),
                ),
              ),
            )
          else ...<Widget>[
            SizedBox(
              height: screen.height / 3,
              width: screen.width,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('$day,', textAlign: TextAlign.center, style: base.copyWith(fontSize: 24)),
                    const SizedBox(height: PrismSpace.xxs),
                    Text(
                      '$month ${now.day}${ClockOverlay.ordinalSuffix(now.day)} | 27°C',
                      textAlign: TextAlign.center,
                      style: base.copyWith(fontSize: 24),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              child: SizedBox(
                width: screen.width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    for (final String icon in <String>['dialer', 'messages', 'prism', 'playstore', 'chrome'])
                      Image.asset('assets/images/$icon.webp', width: screen.width * 0.14),
                  ],
                ),
              ),
            ),
          ],
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: PrismSpace.md),
                child: ExcludeSemantics(
                  child: Text(
                    'Tap anywhere to close',
                    style: PrismTextStyles.caption(context).copyWith(color: textColor),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Close preview',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: SizedBox(height: screen.height, width: screen.width),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the lock screen preview over the current page.
Future<void> pushClockPreview(
  BuildContext context, {
  required String link,
  required bool file,
  Color? accent,
  bool colorChanged = false,
}) {
  return Navigator.push<void>(
    context,
    PageRouteBuilder<void>(
      transitionDuration: context.motion(PrismDurations.base),
      reverseTransitionDuration: context.motion(PrismDurations.fast),
      pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
        opacity: animation.drive(CurveTween(curve: PrismCurves.enter)),
        child: ClockOverlay(colorChanged: colorChanged, accent: accent, link: link, file: file),
      ),
      fullscreenDialog: true,
      opaque: false,
    ),
  );
}
