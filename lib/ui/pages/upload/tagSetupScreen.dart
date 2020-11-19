import 'dart:io';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:flutter/services.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

List<Widget> tempTags = [];
final TextEditingController searchController = TextEditingController();

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
  FocusNode textFocusNode;
  String defaultText;

  @override
  void initState() {
    super.initState();
    textFocusNode = FocusNode();
    defaultText = "Default";
    tempTags = [];
    tempTags = widget.arguments[2] as List<Widget> ?? [];
    image = widget.arguments[0] as File;
    displayHeightOfImage = widget.arguments[1].round() as int;
    _imageProcess();
  }

  @override
  void dispose() {
    textFocusNode.dispose();
    super.dispose();
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
          bottom: PreferredSize(
            preferredSize: const Size(double.infinity, 54),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.96,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(500),
                                color: Theme.of(context).hintColor),
                            child: TextField(
                              cursorColor: config.Colors().mainAccentColor(1),
                              style: Theme.of(context)
                                  .textTheme
                                  .headline5
                                  .copyWith(
                                      color: Theme.of(context).accentColor),
                              controller: searchController,
                              focusNode: textFocusNode,
                              decoration: InputDecoration(
                                contentPadding:
                                    const EdgeInsets.only(left: 30, top: 15),
                                border: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: "Search",
                                hintStyle: Theme.of(context)
                                    .textTheme
                                    .headline5
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                                suffixIcon: Icon(
                                  JamIcons.search,
                                  color: Theme.of(context).accentColor,
                                ),
                              ),
                              onSubmitted: (tex) {
                                setState(() {
                                  defaultText = tex;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: () {
                debugPrint(tempTags.length.toString());
                if (tempTags.isEmpty) {
                  toasts.error("Please add a tag to continue");
                } else {
                  // tags.add(value)
                  setState(() {
                    Navigator.pop(context, tempTags);
                  });
                }
              },
              child: Text(
                "Tag",
                style: TextStyle(
                  color: tempTags.isEmpty
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
                      tempTags.add(Tag(
                        xBound: double.parse(displayWidthOfImage.toString()),
                        yBound: double.parse(displayHeightOfImage.toString()),
                        widgetTag: WidgetTag(
                            positionX: details.globalPosition.dx - 80,
                            positionY: details.globalPosition.dy - 90,
                            name: defaultText,
                            link: "",
                            desc: "",
                            visible: true),
                      ));
                    });
                    textFocusNode.requestFocus();
                  },
                  onTap: () async {},
                  child: Image.file(image, fit: BoxFit.contain),
                ),
                for (var tag in tempTags) tag,
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
  final double xBound;
  final double yBound;
  final WidgetTag widgetTag;
  const Tag({
    @required this.xBound,
    @required this.yBound,
    @required this.widgetTag,
  });
  @override
  _TagState createState() => _TagState();
}

class _TagState extends State<Tag> {
  Color color;

  @override
  void initState() {
    color = Colors.black87;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.widgetTag.positionY,
      left: widget.widgetTag.positionX,
      child: GestureDetector(
        onLongPress: () {
          setState(() {
            widget.widgetTag.visible = false;
            widget.widgetTag.positionX = 10000;
            widget.widgetTag.positionY = 10000;
            color = Colors.transparent;
          });
          HapticFeedback.lightImpact();
        },
        onPanUpdate: (tapInfo) {
          setState(() {
            widget.widgetTag.positionX += tapInfo.delta.dx;
            widget.widgetTag.positionY += tapInfo.delta.dy;
            if (widget.widgetTag.positionX + 70 >= widget.xBound) {
              widget.widgetTag.positionX = widget.xBound - 70;
            }
            if (widget.widgetTag.positionY + 30 >= widget.yBound) {
              widget.widgetTag.positionY = widget.yBound - 30;
            }
            if (widget.widgetTag.positionX <= 0) {
              widget.widgetTag.positionX = 0;
            }
            if (widget.widgetTag.positionY <= 0) {
              widget.widgetTag.positionY = 0;
            }
          });
        },
        child: widget.widgetTag.visible
            ? Container(
                width: 70,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(widget.widgetTag.name),
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
  bool visible;
  WidgetTag(
      {@required this.link,
      @required this.name,
      @required this.desc,
      @required this.positionX,
      @required this.positionY,
      @required this.visible});
}
