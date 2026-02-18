import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart' hide ImageSource;

@RoutePage()
class EditWallScreen extends StatefulWidget {
  final List? arguments;
  const EditWallScreen({this.arguments});
  @override
  _EditWallScreenState createState() => _EditWallScreenState();
}

class _EditWallScreenState extends State<EditWallScreen> {
  final GlobalKey<ExtendedImageEditorState> editorKey = GlobalKey<ExtendedImageEditorState>();
  final defaultColorMatrix = const <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
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

  File? image;
  @override
  void initState() {
    super.initState();
    image = widget.arguments![0] as File;
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
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text(
          "Edit Wallpaper",
          style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
        ),
        leading: IconButton(
          icon: Icon(JamIcons.close, color: Theme.of(context).colorScheme.secondary),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(JamIcons.history, color: Theme.of(context).colorScheme.secondary),
            onPressed: () {
              setState(() {
                sat = 1;
                bright = 0;
                con = 1;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.check, color: Theme.of(context).colorScheme.secondary),
            onPressed: () async {
              await crop();
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          AspectRatio(aspectRatio: 1, child: buildImage()),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(showValueIndicator: ShowValueIndicator.never),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Spacer(flex: 3),
                        Column(
                          children: <Widget>[
                            Icon(JamIcons.brush, color: Theme.of(context).colorScheme.secondary),
                            Text(
                              "Saturation",
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          children: <Widget>[
                            Icon(JamIcons.brightness, color: Theme.of(context).colorScheme.secondary),
                            Text(
                              "Brightness",
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          children: <Widget>[
                            Icon(JamIcons.background_color, color: Theme.of(context).colorScheme.secondary),
                            Text(
                              "Contrast",
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                            ),
                          ],
                        ),
                        const Spacer(flex: 3),
                      ],
                    ),
                  ),
                  SizedBox(
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
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Spacer(flex: 3),
                        Text(
                          sat.toStringAsFixed(2),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                        ),
                        const Spacer(flex: 2),
                        Text(
                          bright.toStringAsFixed(2),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                        ),
                        const Spacer(flex: 2),
                        Text(
                          con.toStringAsFixed(2),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
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
    );
  }

  Widget buildImage() {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(calculateContrastMatrix(con)),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(calculateSaturationMatrix(sat)),
        child: ExtendedImage(
          color: bright > 0 ? Colors.white.withValues(alpha: bright) : Colors.black.withValues(alpha: -bright),
          colorBlendMode: bright > 0 ? BlendMode.lighten : BlendMode.darken,
          image: ExtendedFileImageProvider(image!, cacheRawData: true),
          height: MediaQuery.of(context).size.width,
          width: MediaQuery.of(context).size.width,
          extendedImageEditorKey: editorKey,
          mode: ExtendedImageMode.editor,
          fit: BoxFit.contain,
          initEditorConfigHandler: (ExtendedImageState? state) {
            return EditorConfig(maxScale: 8.0, cropAspectRatio: cropRatio);
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
          icon: Icon(Icons.flip, color: Theme.of(context).colorScheme.secondary),
          label: 'Flip',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.rotate_left, color: Theme.of(context).colorScheme.secondary),
          label: 'Rotate Left',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.rotate_right, color: Theme.of(context).colorScheme.secondary),
          label: 'Rotate Right',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.crop, color: Theme.of(context).colorScheme.secondary),
          label: cropRatio == 1 / 2
              ? "9:18"
              : cropRatio == 9 / 16
              ? "9:16"
              : cropRatio == 9 / 21
              ? "9:21"
              : cropRatio == 9 / 19.5
              ? "9:19.5"
              : "9:18",
        ),
      ],
      onTap: (int index) {
        switch (index) {
          case 0:
            flip();
          case 1:
            rotate(false);
          case 2:
            rotate(true);
          case 3:
            changeCropRatio();
        }
      },
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Theme.of(context).primaryColor,
    );
  }

  Future<void> crop([bool test = false]) async {
    final ExtendedImageEditorState state = editorKey.currentState!;
    final Rect? rect = state.getCropRect();
    if (rect == null) {
      return;
    }
    final EditActionDetails? action = state.editAction;
    if (action == null) {
      return;
    }
    final double radian = action.rotateRadians;

    final bool flipHorizontal = action.flipY;
    final Uint8List img = state.rawImageData;

    final ImageEditorOption option = ImageEditorOption();

    option.addOption(ClipOption.fromRect(rect));
    option.addOption(FlipOption(horizontal: flipHorizontal));
    if (action.rotateRadians != 0) {
      option.addOption(RotateOption(radian.toInt()));
    }

    option.addOption(ColorOption.saturation(sat));
    option.addOption(ColorOption.brightness(bright + 1));
    option.addOption(ColorOption.contrast(con));

    option.outputFormat = const OutputFormat.jpeg(100);

    logger.d(const JsonEncoder.withIndent('  ').convert(option.toJson()));

    final DateTime start = DateTime.now();
    final Uint8List? result = await ImageEditor.editImage(image: img, imageEditorOption: option);
    if (result == null) {
      return;
    }

    logger.d('result.length = ${result.length}');

    final Duration diff = DateTime.now().difference(start);
    image!.writeAsBytesSync(result);
    logger.d('image_editor time : $diff');
    Future.delayed(Duration.zero).then((value) => context.router.replace(UploadWallRoute(arguments: [image, false])));
  }

  void flip() {
    editorKey.currentState!.flip();
  }

  void rotate(bool right) {
    editorKey.currentState!.rotate(degree: right ? 90 : -90);
  }

  Widget _buildSat() {
    return Slider(
      activeColor: Theme.of(context).colorScheme.secondary,
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
      activeColor: Theme.of(context).colorScheme.secondary,
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
      activeColor: Theme.of(context).colorScheme.secondary,
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
