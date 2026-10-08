import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_batch.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart' hide ImageSource;

@RoutePage()
class EditWallScreen extends StatefulWidget {
  const EditWallScreen({super.key, required this.image, this.batch});

  final File image;

  /// Set when this image is one of several picked together.
  final UploadBatch? batch;

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
  _CropRatio cropRatio = _CropRatio.r9x18;

  List<double> calculateContrastMatrix(double contrast) {
    final m = List<double>.from(defaultColorMatrix);
    m[0] = contrast;
    m[6] = contrast;
    m[12] = contrast;
    return m;
  }

  void changeCropRatio() {
    setState(() {
      cropRatio = cropRatio.next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text(
          widget.batch?.isMulti == true
              ? 'Edit wallpaper ${widget.batch!.position} of ${widget.batch!.total}'
              : "Edit Wallpaper",
          style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
        ),
        leading: IconButton(
          tooltip: 'Close',
          icon: Icon(JamIcons.close, color: Theme.of(context).colorScheme.secondary),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reset adjustments',
            icon: Icon(JamIcons.history, color: Theme.of(context).colorScheme.secondary),
            onPressed: () {
              PrismHaptics.tap();
              setState(() {
                sat = 1;
                bright = 0;
                con = 1;
              });
            },
          ),
          IconButton(
            tooltip: 'Done',
            icon: Icon(Icons.check, color: Theme.of(context).colorScheme.secondary),
            onPressed: () async {
              PrismHaptics.tap();
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
                        _buildSlider(
                          label: 'Saturation',
                          value: sat,
                          min: 0,
                          max: 2,
                          onChanged: (value) => setState(() => sat = value),
                        ),
                        const Spacer(),
                        _buildSlider(
                          label: 'Brightness',
                          value: bright,
                          min: -1,
                          max: 1,
                          onChanged: (value) => setState(() => bright = value),
                        ),
                        const Spacer(),
                        _buildSlider(
                          label: 'Contrast',
                          value: con,
                          min: 0,
                          max: 4,
                          onChanged: (value) => setState(() => con = value),
                        ),
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
          image: ExtendedFileImageProvider(widget.image, cacheRawData: true),
          height: MediaQuery.of(context).size.width,
          width: MediaQuery.of(context).size.width,
          extendedImageEditorKey: editorKey,
          mode: ExtendedImageMode.editor,
          fit: BoxFit.contain,
          initEditorConfigHandler: (ExtendedImageState? state) {
            return EditorConfig(maxScale: 8.0, cropAspectRatio: cropRatio.ratio);
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
          label: cropRatio.label,
        ),
      ],
      onTap: (int index) {
        PrismHaptics.tap();
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

  Future<void> crop() async {
    final ExtendedImageEditorState state = editorKey.currentState!;
    final Rect? rect = state.getCropRect();
    if (rect == null) {
      return;
    }
    final EditActionDetails? action = state.editAction;
    if (action == null) {
      return;
    }

    final bool flipHorizontal = action.flipY;
    final Uint8List img = state.rawImageData;

    final ImageEditorOption option = ImageEditorOption();

    option.addOption(ClipOption.fromRect(rect));
    option.addOption(FlipOption(horizontal: flipHorizontal));
    if (action.rotateRadians != 0) {
      option.addOption(RotateOption(action.rotateDegrees.round()));
    }

    option.addOption(ColorOption.saturation(sat));
    option.addOption(ColorOption.brightness(bright + 1));
    option.addOption(ColorOption.contrast(con));

    option.outputFormat = const OutputFormat.jpeg(100);

    final Uint8List? result = await ImageEditor.editImage(image: img, imageEditorOption: option);
    if (!mounted) return;
    if (result == null) {
      return;
    }

    widget.image.writeAsBytesSync(result);
    await context.router.replace(UploadWallRoute(image: widget.image, batch: widget.batch));
  }

  void flip() {
    editorKey.currentState!.flip();
  }

  void rotate(bool right) {
    editorKey.currentState!.rotate(degree: right ? 90 : -90);
  }

  // Each slider gets its own semantics container: without one, popping this screen on iOS left the engine's
  // accessibility root empty (zero size, no children), so VoiceOver saw nothing in the app until a restart.
  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Semantics(
      container: true,
      child: Slider(
        activeColor: Theme.of(context).colorScheme.secondary,
        inactiveColor: Theme.of(context).hintColor,
        label: '$label ${value.toStringAsFixed(2)}',
        onChanged: onChanged,
        onChangeEnd: (_) => PrismHaptics.selection(),
        divisions: 50,
        value: value,
        min: min,
        max: max,
      ),
    );
  }
}

enum _CropRatio {
  r9x18(1 / 2, '9:18'),
  r9x16(9 / 16, '9:16'),
  r9x21(9 / 21, '9:21'),
  r9x195(9 / 19.5, '9:19.5');

  const _CropRatio(this.ratio, this.label);

  final double ratio;
  final String label;

  _CropRatio get next => _CropRatio.values[(index + 1) % _CropRatio.values.length];
}
