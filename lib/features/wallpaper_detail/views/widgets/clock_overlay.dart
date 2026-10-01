import 'dart:io';

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
    final Color textColor = accent == null ? Theme.of(context).colorScheme.secondary : onColor(accent!);
    final bool iosPreview = defaultTargetPlatform == TargetPlatform.iOS;
    return Material(
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
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: Image.file(
                File(link),
                color: colorChanged ? accent : null,
                colorBlendMode: colorChanged ? BlendMode.hue : null,
                fit: BoxFit.cover,
              ),
            ),
          if (iosPreview)
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
                        DateFormat('h:mm').format(now),
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
          else ...<Widget>[
            SizedBox(
              height: MediaQuery.of(context).size.height / 3,
              width: MediaQuery.of(context).size.width,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      "$day,",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: "Roboto",
                        fontSize: 25,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "$month ${now.day}${ClockOverlay.ordinalSuffix(now.day)} | 27°C",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: "Roboto",
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Image.asset("assets/images/dialer.webp", width: MediaQuery.of(context).size.width * 0.14),
                    Image.asset("assets/images/messages.webp", width: MediaQuery.of(context).size.width * 0.14),
                    Image.asset("assets/images/prism.webp", width: MediaQuery.of(context).size.width * 0.14),
                    Image.asset("assets/images/playstore.webp", width: MediaQuery.of(context).size.width * 0.14),
                    Image.asset("assets/images/chrome.webp", width: MediaQuery.of(context).size.width * 0.14),
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
              child: SizedBox(height: MediaQuery.of(context).size.height, width: MediaQuery.of(context).size.width),
            ),
          ),
        ],
      ),
    );
  }
}
