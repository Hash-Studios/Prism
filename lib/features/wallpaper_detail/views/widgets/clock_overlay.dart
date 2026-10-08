import 'dart:io';

import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ClockPreviewMode { lock, home }

/// Full-screen preview of the wallpaper under a lock screen clock or a home screen dock.
/// The image is shown as it will be set: the palette accent only colours the text.
class ClockOverlay extends StatefulWidget {
  const ClockOverlay({required this.link, required this.file, required this.accent});

  final String link;
  final bool file;
  final Color? accent;

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

  /// Time of day in the device 12 or 24 hour style.
  @visibleForTesting
  static String formatTime(DateTime time, {required bool use24Hour}) =>
      DateFormat(use24Hour ? 'HH:mm' : 'h:mm').format(time);

  @override
  State<ClockOverlay> createState() => _ClockOverlayState();
}

class _ClockOverlayState extends State<ClockOverlay> {
  late ClockPreviewMode _mode = defaultTargetPlatform == TargetPlatform.iOS
      ? ClockPreviewMode.lock
      : ClockPreviewMode.home;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final size = MediaQuery.sizeOf(context);
    final bool use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final String time = ClockOverlay.formatTime(now, use24Hour: use24Hour);
    final Color textColor = widget.accent == null ? Theme.of(context).colorScheme.secondary : onColor(widget.accent!);
    final bool iosPreview = defaultTargetPlatform == TargetPlatform.iOS;
    final bool lock = _mode == ClockPreviewMode.lock;
    return Material(
      child: Stack(
        children: <Widget>[
          if (!widget.file)
            CachedNetworkImage(
              imageUrl: widget.link,
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                ),
              ),
            )
          else
            SizedBox(
              height: size.height,
              width: size.width,
              child: Image.file(File(widget.link), fit: BoxFit.cover),
            ),
          if (iosPreview)
            if (lock)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          DateFormat('EEEE d MMMM').format(now),
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'CupertinoSystemText',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'CupertinoSystemDisplay',
                            fontSize: 96,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              const SizedBox.shrink()
          else ...<Widget>[
            SizedBox(
              height: size.height / 3,
              width: size.width,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (lock) ...<Widget>[
                      Text(
                        time,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'Roboto',
                          fontSize: 72,
                          fontWeight: FontWeight.w200,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "${DateFormat('EEEE').format(now)}, ${DateFormat('MMMM').format(now)} ${now.day}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'Roboto',
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...<Widget>[
                      Text(
                        "${DateFormat('EEEE').format(now)},",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'Roboto',
                          fontSize: 25,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "${DateFormat('MMMM').format(now)} ${now.day}${ClockOverlay.ordinalSuffix(now.day)}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'Roboto',
                          fontSize: 25,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!lock)
              Positioned(
                bottom: 100,
                child: SizedBox(
                  width: size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Image.asset("assets/images/dialer.webp", width: size.width * 0.14),
                      Image.asset("assets/images/messages.webp", width: size.width * 0.14),
                      Image.asset("assets/images/prism.webp", width: size.width * 0.14),
                      Image.asset("assets/images/playstore.webp", width: size.width * 0.14),
                      Image.asset("assets/images/chrome.webp", width: size.width * 0.14),
                    ],
                  ),
                ),
              ),
          ],
          Semantics(
            button: true,
            label: 'Close preview',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: SizedBox(height: size.height, width: size.width),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SegmentedButton<ClockPreviewMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.7),
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                  segments: const <ButtonSegment<ClockPreviewMode>>[
                    ButtonSegment<ClockPreviewMode>(value: ClockPreviewMode.lock, label: Text('Lock')),
                    ButtonSegment<ClockPreviewMode>(value: ClockPreviewMode.home, label: Text('Home')),
                  ],
                  selected: <ClockPreviewMode>{_mode},
                  onSelectionChanged: (selection) => setState(() => _mode = selection.single),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
