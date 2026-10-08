import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Superscript ordinal suffix for a day of the month: 1ˢᵗ, 2ⁿᵈ, 3ʳᵈ, 4ᵗʰ, 11ᵗʰ.
String ordinalSuffix(int day) {
  if (day >= 11 && day <= 13) return 'ᵗʰ';
  return switch (day % 10) {
    1 => 'ˢᵗ',
    2 => 'ⁿᵈ',
    3 => 'ʳᵈ',
    _ => 'ᵗʰ',
  };
}

/// Time of day in the device 12 or 24 hour style.
String formatClockTime(DateTime time, {required bool use24Hour}) =>
    DateFormat(use24Hour ? 'HH:mm' : 'h:mm').format(time);

/// How big the layer is drawn compared with a full screen. A phone-shaped frame on a smaller area scales down.
double _layerScale(BuildContext context, BoxConstraints constraints) {
  final double screenWidth = MediaQuery.sizeOf(context).width;
  if (!constraints.hasBoundedWidth || screenWidth <= 0) return 1;
  return constraints.maxWidth / screenWidth;
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
    final String clock = formatClockTime(time, use24Hour: use24Hour);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scale = _layerScale(context, constraints);
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 24 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    DateFormat('EEEE d MMMM').format(time),
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
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: constraints.maxHeight.isFinite ? constraints.maxHeight / 3 : null,
            width: constraints.maxWidth,
            child: Center(
              child: Column(
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
                    "${DateFormat('EEEE').format(time)}, ${DateFormat('MMMM').format(time)} ${time.day}",
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
            ),
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
        final double iconWidth = constraints.maxWidth * 0.14;
        return Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: constraints.maxHeight.isFinite ? constraints.maxHeight / 3 : null,
                width: constraints.maxWidth,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        "${DateFormat('EEEE').format(time)},",
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
                        "${DateFormat('MMMM').format(time)} ${time.day}${ordinalSuffix(time.day)}",
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
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 100 * scale,
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
