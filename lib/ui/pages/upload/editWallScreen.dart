import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:image_editor/image_editor.dart' hide ImageSource;

class EditWallScreen extends StatefulWidget {
  final List arguments;
  const EditWallScreen({this.arguments});
  @override
  _EditWallScreenState createState() => _EditWallScreenState();
}

class _EditWallScreenState extends State<EditWallScreen> {
  final GlobalKey<ExtendedImageEditorState> editorKey =
      GlobalKey<ExtendedImageEditorState>();
  final defaultColorMatrix = const <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0
  ];
  List<double> calculateSaturationMatrix(double saturation) {
    final m = List<double>.from(defaultColorMatrix);
    final invSat = 1 - saturation;
    final R = 0.213 * invSat;
    final G = 0.715 * invSat;
    final B = 0.072 * invSat;

    m[0] = R + saturation;
    m[1] = G;
    m[2] = B;
    m[5] = R;
    m[6] = G + saturation;
    m[7] = B;
    m[10] = R;
    m[11] = G;
    m[12] = B + saturation;

    return m;
  }

  double sat = 1;
  double bright = 0;
  double con = 1;
  double cropRatio = 1 / 2;

  List<double> calculateContrastMatrix(double contrast) {
    final m = List<double>.from(defaultColorMatrix);
    m[0] = contrast;
    m[6] = contrast;
    m[12] = contrast;
    return m;
  }

  File image;
  @override
  void initState() {
    super.initState();
    image = widget.arguments[0] as File;
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  void changeCropRatio() {
    setState(() {
      if (cropRatio == 1 / 2) {
        cropRatio = 9 / 16;
      } else if (cropRatio == 9 / 16) {
        cropRatio = 9 / 21;
      } else if (cropRatio == 9 / 21) {
        cropRatio = 9 / 19.5;
      } else if (cropRatio == 9 / 19.5) {
        cropRatio = 1 / 2;
      } else {
        cropRatio = 1 / 2;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
            title: Text(
              "Edit Wallpaper",
              style: Theme.of(context)
                  .textTheme
                  .headline3
                  .copyWith(color: Theme.of(context).accentColor),
            ),
            leading: IconButton(
                icon:
                    Icon(JamIcons.close, color: Theme.of(context).accentColor),
                onPressed: () {
                  navStack.removeLast();
                  debugPrint(navStack.toString());
                  Navigator.pop(context);
                }),
            actions: <Widget>[
              IconButton(
                icon: Icon(JamIcons.history,
                    color: Theme.of(context).accentColor),
                onPressed: () {
                  setState(() {
                    sat = 1;
                    bright = 0;
                    con = 1;
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.check, color: Theme.of(context).accentColor),
                onPressed: () async {
                  await crop();
                },
              ),
            ]),
        body: Column(
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: buildImage(),
            ),
            Expanded(
              child: SliderTheme(
                data: const SliderThemeData(
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Spacer(flex: 3),
                          Column(
                            children: <Widget>[
                              Icon(
                                JamIcons.brush,
                                color: Theme.of(context).accentColor,
                              ),
                              Text(
                                "Saturation",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              )
                            ],
                          ),
                          const Spacer(),
                          Column(
                            children: <Widget>[
                              Icon(
                                JamIcons.brightness,
                                color: Theme.of(context).accentColor,
                              ),
                              Text(
                                "Brightness",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              )
                            ],
                          ),
                          const Spacer(),
                          Column(
                            children: <Widget>[
                              Icon(
                                JamIcons.background_color,
                                color: Theme.of(context).accentColor,
                              ),
                              Text(
                                "Contrast",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              )
                            ],
                          ),
                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.6,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Spacer(flex: 3),
                          _buildSat(),
                          const Spacer(),
                          _buildBrightness(),
                          const Spacer(),
                          _buildCon(),
                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Spacer(flex: 3),
                          Text(
                            sat.toStringAsFixed(2),
                            style: Theme.of(context)
                                .textTheme
                                .bodyText2
                                .copyWith(color: Theme.of(context).accentColor),
                          ),
                          const Spacer(flex: 2),
                          Text(
                            bright.toStringAsFixed(2),
                            style: Theme.of(context)
                                .textTheme
                                .bodyText2
                                .copyWith(color: Theme.of(context).accentColor),
                          ),
                          const Spacer(flex: 2),
                          Text(
                            con.toStringAsFixed(2),
                            style: Theme.of(context)
                                .textTheme
                                .bodyText2
                                .copyWith(color: Theme.of(context).accentColor),
                          ),
                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildFunctions(),
      ),
    );
  }

  Widget buildImage() {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(calculateContrastMatrix(con)),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(calculateSaturationMatrix(sat)),
        child: ExtendedImage(
          color: bright > 0
              ? Colors.white.withOpacity(bright)
              : Colors.black.withOpacity(-bright),
          colorBlendMode: bright > 0 ? BlendMode.lighten : BlendMode.darken,
          image: ExtendedFileImageProvider(image),
          height: MediaQuery.of(context).size.width,
          width: MediaQuery.of(context).size.width,
          extendedImageEditorKey: editorKey,
          mode: ExtendedImageMode.editor,
          fit: BoxFit.contain,
          initEditorConfigHandler: (ExtendedImageState state) {
            return EditorConfig(
              maxScale: 8.0,
              cropAspectRatio: cropRatio,
            );
          },
        ),
      ),
    );
  }

  Widget _buildFunctions() {
    return BottomNavigationBar(
      backgroundColor: Theme.of(context).primaryColor,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(
            Icons.flip,
            color: Theme.of(context).accentColor,
          ),
          title: Text(
            'Flip',
            style: Theme.of(context).textTheme.bodyText2.copyWith(
                  color: Theme.of(context).accentColor,
                ),
          ),
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.rotate_left,
            color: Theme.of(context).accentColor,
          ),
          title: Text(
            'Rotate Left',
            style: Theme.of(context).textTheme.bodyText2.copyWith(
                  color: Theme.of(context).accentColor,
                ),
          ),
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.rotate_right,
            color: Theme.of(context).accentColor,
          ),
          title: Text(
            'Rotate Right',
            style: Theme.of(context).textTheme.bodyText2.copyWith(
                  color: Theme.of(context).accentColor,
                ),
          ),
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.crop,
            color: Theme.of(context).accentColor,
          ),
          title: Text(
            cropRatio == 1 / 2
                ? "9:18"
                : cropRatio == 9 / 16
                    ? "9:16"
                    : cropRatio == 9 / 21
                        ? "9:21"
                        : cropRatio == 9 / 19.5
                            ? "9:19.5"
                            : "9:18",
            style: Theme.of(context).textTheme.bodyText2.copyWith(
                  color: Theme.of(context).accentColor,
                ),
          ),
        ),
      ],
      onTap: (int index) {
        switch (index) {
          case 0:
            flip();
            break;
          case 1:
            rotate(false);
            break;
          case 2:
            rotate(true);
            break;
          case 3:
            changeCropRatio();
            break;
        }
      },
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Theme.of(context).primaryColor,
    );
  }

  Future<void> crop([bool test = false]) async {
    final ExtendedImageEditorState state = editorKey.currentState;
    final Rect rect = state.getCropRect();
    final EditActionDetails action = state.editAction;
    final double radian = action.rotateAngle;

    final bool flipHorizontal = action.flipY;
    final bool flipVertical = action.flipX;
    final Uint8List img = state.rawImageData;

    final ImageEditorOption option = ImageEditorOption();

    option.addOption(ClipOption.fromRect(rect));
    option.addOption(
        FlipOption(horizontal: flipHorizontal, vertical: flipVertical));
    if (action.hasRotateAngle) {
      option.addOption(RotateOption(radian.toInt()));
    }

    option.addOption(ColorOption.saturation(sat));
    option.addOption(ColorOption.brightness(bright + 1));
    option.addOption(ColorOption.contrast(con));

    option.outputFormat = const OutputFormat.jpeg(100);

    debugPrint(const JsonEncoder.withIndent('  ').convert(option.toJson()));

    final DateTime start = DateTime.now();
    final Uint8List result = await ImageEditor.editImage(
      image: img,
      imageEditorOption: option,
    );

    debugPrint('result.length = ${result.length}');

    final Duration diff = DateTime.now().difference(start);
    image.writeAsBytesSync(result);
    debugPrint('image_editor time : $diff');
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    Future.delayed(const Duration()).then((value) =>
        Navigator.pushReplacementNamed(context, uploadWallRoute,
            arguments: [image]));
  }

  void flip() {
    editorKey.currentState.flip();
  }

  void rotate(bool right) {
    editorKey.currentState.rotate(right: right);
  }

  Widget _buildSat() {
    return Slider(
      activeColor: Theme.of(context).accentColor,
      inactiveColor: Theme.of(context).hintColor,
      label: 'sat : ${sat.toStringAsFixed(2)}',
      onChanged: (double value) {
        setState(() {
          sat = value;
        });
      },
      divisions: 50,
      value: sat,
      max: 2,
    );
  }

  Widget _buildBrightness() {
    return Slider(
      activeColor: Theme.of(context).accentColor,
      inactiveColor: Theme.of(context).hintColor,
      label: bright.toStringAsFixed(2),
      onChanged: (double value) {
        setState(() {
          bright = value;
        });
      },
      divisions: 50,
      value: bright,
      min: -1,
    );
  }

  Widget _buildCon() {
    return Slider(
      activeColor: Theme.of(context).accentColor,
      inactiveColor: Theme.of(context).hintColor,
      label: 'con : ${con.toStringAsFixed(2)}',
      onChanged: (double value) {
        setState(() {
          con = value;
        });
      },
      divisions: 50,
      value: con,
      max: 4,
    );
  }
}
