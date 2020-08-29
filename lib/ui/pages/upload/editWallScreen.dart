import 'dart:io';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:extended_image/extended_image.dart';
import 'package:image_editor/image_editor.dart' hide ImageSource;

class EditWallScreen extends StatefulWidget {
  final List arguments;
  EditWallScreen({this.arguments});
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
    image = widget.arguments[0];
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    return true;
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
              style: TextStyle(color: Theme.of(context).accentColor),
            ),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.settings_backup_restore),
                onPressed: () {
                  setState(() {
                    sat = 1;
                    bright = 0;
                    con = 1;
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.check),
                onPressed: () async {
                  await crop();
                },
              ),
            ]),
        body: Container(
          child: Column(
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Spacer(flex: 3),
                      _buildSat(),
                      Spacer(flex: 1),
                      _buildBrightness(),
                      Spacer(flex: 1),
                      _buildCon(),
                      Spacer(flex: 3),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
              cropRectPadding: const EdgeInsets.all(20.0),
              hitTestSize: 20.0,
              cropAspectRatio: 1 / 2,
            );
          },
        ),
      ),
    );
  }

  Widget _buildFunctions() {
    return BottomNavigationBar(
      backgroundColor: Theme.of(context).primaryColor,
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(
            Icons.flip,
            color: Theme.of(context).accentColor,
          ),
          title: Text(
            'Flip',
            style: TextStyle(
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
            'Rotate left',
            style: TextStyle(
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
            'Rotate right',
            style: TextStyle(
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
        }
      },
      currentIndex: 0,
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

    print(const JsonEncoder.withIndent('  ').convert(option.toJson()));

    final DateTime start = DateTime.now();
    final Uint8List result = await ImageEditor.editImage(
      image: img,
      imageEditorOption: option,
    );

    print('result.length = ${result.length}');

    final Duration diff = DateTime.now().difference(start);
    image.writeAsBytesSync(result);
    print('image_editor time : $diff');
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    Future.delayed(Duration(seconds: 0)).then((value) =>
        Navigator.pushReplacementNamed(context, UploadWallRoute,
            arguments: [image]));
  }

  void flip() {
    editorKey.currentState.flip();
  }

  void rotate(bool right) {
    editorKey.currentState.rotate(right: right);
  }

  Widget _buildSat() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.03,
        ),
        Column(
          children: <Widget>[
            Icon(
              JamIcons.brush,
              color: Theme.of(context).accentColor,
            ),
            Text(
              "Saturation",
              style: TextStyle(color: Theme.of(context).accentColor),
            )
          ],
        ),
        Container(
          width: MediaQuery.of(context).size.width * 0.7,
          child: Slider(
            label: 'sat : ${sat.toStringAsFixed(2)}',
            onChanged: (double value) {
              setState(() {
                sat = value;
              });
            },
            divisions: 50,
            value: sat,
            min: 0,
            max: 2,
          ),
        ),
        Text(sat.toStringAsFixed(2)),
      ],
    );
  }

  Widget _buildBrightness() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.03,
        ),
        Column(
          children: <Widget>[
            Icon(
              JamIcons.brightness,
              color: Theme.of(context).accentColor,
            ),
            Text(
              "Brightness",
              style: TextStyle(color: Theme.of(context).accentColor),
            )
          ],
        ),
        Container(
          width: MediaQuery.of(context).size.width * 0.7,
          child: Slider(
            label: '${bright.toStringAsFixed(2)}',
            onChanged: (double value) {
              setState(() {
                bright = value;
              });
            },
            divisions: 50,
            value: bright,
            min: -1,
            max: 1,
          ),
        ),
        Text(bright.toStringAsFixed(2)),
      ],
    );
  }

  Widget _buildCon() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.03,
        ),
        Column(
          children: <Widget>[
            Icon(
              JamIcons.background_color,
              color: Theme.of(context).accentColor,
            ),
            Text(
              "Contrast",
              style: TextStyle(color: Theme.of(context).accentColor),
            )
          ],
        ),
        Container(
          width: MediaQuery.of(context).size.width * 0.7,
          child: Slider(
            label: 'con : ${con.toStringAsFixed(2)}',
            onChanged: (double value) {
              setState(() {
                con = value;
              });
            },
            divisions: 50,
            value: con,
            min: 0,
            max: 4,
          ),
        ),
        Text(con.toStringAsFixed(2)),
      ],
    );
  }
}
