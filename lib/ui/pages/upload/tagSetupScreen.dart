import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;
import 'package:flutter/services.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

List<Widget> tags = [];

class TagSetupScreen extends StatefulWidget {
  final List arguments;
  const TagSetupScreen({this.arguments});
  @override
  _TagSetupScreenState createState() => _TagSetupScreenState();
}

class _TagSetupScreenState extends State<TagSetupScreen> {
  File image;
  int heightOfImage;
  int widthOfImage;
  int displayHeightOfImage;
  int displayWidthOfImage;
  double scale;

  @override
  void initState() {
    super.initState();
    tags = [];
    tags = widget.arguments[2] as List<Widget> ?? [];
    image = widget.arguments[0] as File;
    displayHeightOfImage = widget.arguments[1].round() as int;
    _imageProcess();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  Future<void> _imageProcess() async {
    final imgList = image.readAsBytesSync();
    final decodedImage = await decodeImageFromList(imgList);
    setState(() {
      heightOfImage = decodedImage.height;
      widthOfImage = decodedImage.width;
      scale = displayHeightOfImage / heightOfImage;
      displayWidthOfImage = (scale * widthOfImage).round();
    });

    debugPrint(decodedImage.width.toString());
    debugPrint(decodedImage.height.toString());
    debugPrint(displayWidthOfImage.toString());
    debugPrint(displayHeightOfImage.toString());
    debugPrint(scale.toString());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          title: Text(
            "Tag Widgets",
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
          actions: [
            TextButton(
              onPressed: () {
                print(tags.length);
                if (tags.isEmpty) {
                  toasts.error("Please add a tag to continue");
                } else {
                  setState(() {
                    Navigator.pop(context, tags);
                  });
                }
              },
              child: Text(
                "Tag",
                style: TextStyle(
                  color: tags.isEmpty
                      ? Theme.of(context).hintColor
                      : config.Colors().accentColor(1),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        body: Column(children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTapUp: (details) {
                    debugPrint(details.globalPosition.dx.toString());
                    debugPrint(details.globalPosition.dy.toString());
                    setState(() {
                      tags.add(Tag(
                        x: details.globalPosition.dx - 80,
                        y: details.globalPosition.dy - 90,
                        xBound: double.parse(displayWidthOfImage.toString()),
                        yBound: double.parse(displayHeightOfImage.toString()),
                      ));
                    });
                  },
                  onTap: () async {},
                  child: Image.file(image, fit: BoxFit.contain),
                ),
                for (var tag in tags) tag,
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.2,
            child: Center(
              child: scale == null
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          config.Colors().mainAccentColor(1)),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Tap the setup to add widgets and icon packs.\nDrag to move or long press the tag to delete.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w100,
                          color: Theme.of(context).accentColor.withOpacity(0.7),
                        ),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

class Tag extends StatefulWidget {
  final double x;
  final double y;
  final double xBound;
  final double yBound;
  const Tag({
    @required this.x,
    @required this.y,
    @required this.xBound,
    @required this.yBound,
  });
  @override
  _TagState createState() => _TagState();
}

class _TagState extends State<Tag> {
  bool visibility = true;
  Color color;
  WidgetTag _widgetTag;

  @override
  void initState() {
    color = Colors.black87;
    super.initState();
    setState(() {
      _widgetTag.positionX = widget.x;
      _widgetTag.positionY = widget.y;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _widgetTag.positionY,
      left: _widgetTag.positionX,
      child: GestureDetector(
        onLongPress: () {
          setState(() {
            visibility = false;
            _widgetTag.positionX = 10000;
            _widgetTag.positionY = 10000;
            color = Colors.transparent;
          });
          HapticFeedback.lightImpact();
        },
        onPanUpdate: (tapInfo) {
          setState(() {
            _widgetTag.positionX += tapInfo.delta.dx;
            _widgetTag.positionY += tapInfo.delta.dy;
            if (_widgetTag.positionX + 70 >= widget.xBound) {
              _widgetTag.positionX = widget.xBound - 70;
            }
            if (_widgetTag.positionY + 30 >= widget.yBound) {
              _widgetTag.positionY = widget.yBound - 30;
            }
            if (_widgetTag.positionX <= 0) {
              _widgetTag.positionX = 0;
            }
            if (_widgetTag.positionY <= 0) {
              _widgetTag.positionY = 0;
            }
          });
        },
        child: visibility
            ? Container(
                width: 70,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text("Hello KWGT"),
              )
            : Container(),
      ),
    );
  }
}

class WidgetTag {
  String link;
  String name;
  String desc;
  double positionX;
  double positionY;
  WidgetTag({
    @required this.link,
    @required this.name,
    @required this.desc,
    @required this.positionX,
    @required this.positionY,
  });
}
