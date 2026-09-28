import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClockOverlay extends StatefulWidget {
  final String? link;
  final bool file;
  final Color? accent;
  final bool colorChanged;
  const ClockOverlay({required this.link, required this.file, required this.accent, required this.colorChanged});
  @override
  _ClockOverlayState createState() => _ClockOverlayState();
}

class _ClockOverlayState extends State<ClockOverlay> {
  @override
  Widget build(BuildContext context) {
    final day = DateFormat('EEEE').format(DateTime.now());
    final month = DateFormat('MMMM').format(DateTime.now());
    final dayNo = DateFormat('d').format(DateTime.now());
    final suffix = dayNo[dayNo.length - 1] == "1"
        ? "ˢᵗ"
        : dayNo[dayNo.length - 1] == "2"
        ? "ⁿᵈ"
        : dayNo[dayNo.length - 1] == "3"
        ? "ʳᵈ"
        : "ᵗʰ";
    final Color textColor = widget.accent == null
        ? Theme.of(context).colorScheme.secondary
        : widget.accent!.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    final bool iosPreview = defaultTargetPlatform == TargetPlatform.iOS;
    return Material(
      child: Stack(
        children: <Widget>[
          if (!widget.file)
            CachedNetworkImage(
              imageUrl: widget.link!,
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    colorFilter: widget.colorChanged ? ColorFilter.mode(widget.accent!, BlendMode.hue) : null,
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
                File(widget.link!),
                color: widget.accent,
                colorBlendMode: widget.colorChanged ? BlendMode.color : null,
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
                        DateFormat('EEEE d MMMM').format(DateTime.now()),
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'CupertinoSystemText',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm').format(DateTime.now()),
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
                      "$month $dayNo$suffix | 27°C",
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
