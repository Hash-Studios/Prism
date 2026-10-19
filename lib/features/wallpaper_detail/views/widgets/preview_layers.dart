import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// How big the layer is drawn compared with a full screen. A phone-shaped frame on a smaller area scales down.
double _layerScale(BuildContext context, BoxConstraints constraints) {
  final double screenWidth = MediaQuery.sizeOf(context).width;
  if (!constraints.hasBoundedWidth || screenWidth <= 0) return 1;
  return constraints.maxWidth / screenWidth;
}

/// Height of the status bar as the layer draws it. It scales with the frame, like the text.
double _statusBarInset(BuildContext context, double scale) => MediaQuery.viewPaddingOf(context).top * scale;

/// Centres [child] in the top third of the space below the status bar.
Widget _topThird(BoxConstraints constraints, double inset, Widget child) {
  return Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: EdgeInsets.only(top: inset),
      child: SizedBox(
        height: constraints.maxHeight.isFinite ? math.max(0.0, constraints.maxHeight - inset) / 3 : null,
        width: constraints.maxWidth,
        child: Center(child: child),
      ),
    ),
  );
}

/// The clock and date of a lock screen, drawn over a wallpaper. It fills the space it gets.
class LockPreviewLayer extends StatelessWidget {
  const LockPreviewLayer({super.key, required this.textColor, this.now});

  final Color textColor;

  /// The time to show. Defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final DateTime time = now ?? DateTime.now();
    final bool use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final String clock = DateFormat(use24Hour ? 'HH:mm' : 'h:mm', context.l10n.localeName).format(time);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scale = _layerScale(context, constraints);
        final double inset = _statusBarInset(context, scale);
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: inset + 24 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    DateFormat.MMMMEEEEd(context.l10n.localeName).format(time),
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    clock,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'CupertinoSystemDisplay',
                      fontSize: 96 * scale,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return _topThird(
          constraints,
          inset,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                clock,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Roboto',
                  fontSize: 72 * scale,
                  fontWeight: FontWeight.w200,
                ),
              ),
              SizedBox(height: 5 * scale),
              Text(
                DateFormat.MMMMEEEEd(context.l10n.localeName).format(time),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Roboto',
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The date and the dock of a home screen, drawn over a wallpaper. It fills the space it gets.
/// On iOS it draws nothing, because the app icons are not part of the preview.
class HomePreviewLayer extends StatelessWidget {
  const HomePreviewLayer({super.key, required this.textColor, this.now});

  final Color textColor;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) return const SizedBox.shrink();
    final DateTime time = now ?? DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scale = _layerScale(context, constraints);
        final double iconWidth = math.min(constraints.maxWidth * 0.14, 68.0);
        return Stack(
          children: <Widget>[
            _topThird(
              constraints,
              _statusBarInset(context, scale),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    DateFormat.EEEE(context.l10n.localeName).format(time),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'Roboto',
                      fontSize: 25 * scale,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  SizedBox(height: 5 * scale),
                  Text(
                    DateFormat.MMMMd(context.l10n.localeName).format(time),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'Roboto',
                      fontSize: 25 * scale,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: (MediaQuery.viewPaddingOf(context).bottom + 100) * scale,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Image.asset('assets/images/dialer.webp', width: iconWidth),
                  Image.asset('assets/images/messages.webp', width: iconWidth),
                  Image.asset('assets/images/prism.webp', width: iconWidth),
                  Image.asset('assets/images/playstore.webp', width: iconWidth),
                  Image.asset('assets/images/chrome.webp', width: iconWidth),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
