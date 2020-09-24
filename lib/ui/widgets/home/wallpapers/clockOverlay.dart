import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ClockOverlay extends StatefulWidget {
  final String link;
  final bool file;
  final Color accent;
  final bool colorChanged;
  ClockOverlay({
    @required this.link,
    @required this.file,
    @required this.accent,
    @required this.colorChanged,
  });
  @override
  _ClockOverlayState createState() => _ClockOverlayState();
}

class _ClockOverlayState extends State<ClockOverlay> {
  @override
  Widget build(BuildContext context) {
    var day = DateFormat('EEEE').format(DateTime.now());
    var month = DateFormat('MMMM').format(DateTime.now());
    var dayNo = DateFormat('d').format(DateTime.now());
    var suffix = dayNo[dayNo.length - 1] == 1
        ? "ˢᵗ"
        : dayNo[dayNo.length - 1] == 2
            ? "ⁿᵈ"
            : dayNo[dayNo.length - 1] == 3 ? "ʳᵈ" : "ᵗʰ";
    return Material(
      child: Stack(
        children: <Widget>[
          !widget.file
              ? CachedNetworkImage(
                  imageUrl: widget.link,
                  imageBuilder: (context, imageProvider) => Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        colorFilter: widget.colorChanged
                            ? ColorFilter.mode(widget.accent, BlendMode.hue)
                            : null,
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              : Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: Image.file(
                    File(widget.link),
                    color: widget.accent,
                    colorBlendMode:
                        widget.colorChanged ? BlendMode.color : null,
                    fit: BoxFit.cover,
                  ),
                ),
          SizedBox(
            height: MediaQuery.of(context).size.height / 3,
            width: MediaQuery.of(context).size.width,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    "$day,",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.accent == null
                          ? Theme.of(context).accentColor
                          : widget.accent.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                      fontFamily: "Roboto",
                      fontSize: 25,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Text(
                    "$month $dayNo$suffix | 27°C",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.accent == null
                          ? Theme.of(context).accentColor
                          : widget.accent.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
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
            child: Container(
              width: MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    "assets/images/dialer.png",
                    width: MediaQuery.of(context).size.width * 0.14,
                  ),
                  Image.asset(
                    "assets/images/messages.png",
                    width: MediaQuery.of(context).size.width * 0.14,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 1.0),
                    child: Image.asset(
                      "assets/images/prism.png",
                      width: MediaQuery.of(context).size.width * 0.14,
                    ),
                  ),
                  Image.asset(
                    "assets/images/playstore.png",
                    width: MediaQuery.of(context).size.width * 0.14,
                  ),
                  Image.asset(
                    "assets/images/chrome.png",
                    width: MediaQuery.of(context).size.width * 0.14,
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: Text(""),
            ),
            onTap: () => {Navigator.pop(context)},
          )
        ],
      ),
    );
  }
}
