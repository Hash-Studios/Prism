import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_batch.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/edit_adjustments_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
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
  EditCropRatio cropRatio = EditCropRatio.r9x18;
  bool _transformed = false;
  bool _saving = false;

  List<double> calculateContrastMatrix(double contrast) {
    final m = List<double>.from(defaultColorMatrix);
    m[0] = contrast;
    m[6] = contrast;
    m[12] = contrast;
    return m;
  }

  bool get _dirty => sat != 1 || bright != 0 || con != 1 || _transformed || cropRatio != EditCropRatio.r9x18;

  void _resetAdjustments() {
    PrismHaptics.tap();
    setState(() {
      sat = 1;
      bright = 0;
      con = 1;
    });
  }

  Future<void> _confirmDiscard() async {
    final bool discard = await showPrismConfirm(
      context,
      title: context.l10n.wallpaperUploadDiscardEditsTitle,
      message: context.l10n.wallpaperUploadDiscardEditsBody,
      confirmLabel: context.l10n.wallpaperDiscard,
      destructive: true,
    );
    if (discard && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmDiscard();
      },
      child: PrismPage(
        title: widget.batch?.isMulti == true
            ? context.l10n.wallpaperUploadEditBatch(widget.batch!.position, widget.batch!.total)
            : context.l10n.wallpaperEditTitle,
        onBack: () => Navigator.maybePop(context),
        actions: <Widget>[
          PrismIconButton(
            icon: Icons.restart_alt_rounded,
            tooltip: context.l10n.wallpaperUploadResetAdjustments,
            onPressed: _resetAdjustments,
          ),
        ],
        bottomBar: PrismButton(
          label: context.l10n.wallpaperSave,
          expand: true,
          loading: _saving,
          onPressed: _saving ? null : crop,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
                child: LayoutBuilder(
                  builder: (context, box) => ClipRRect(
                    borderRadius: BorderRadius.circular(PrismRadius.md),
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: buildImage(box.biggest),
                    ),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.42),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.md, PrismSpace.page, PrismSpace.md),
                child: EditAdjustmentsCard(
                  cropRatio: cropRatio,
                  onCropRatio: (EditCropRatio ratio) => setState(() => cropRatio = ratio),
                  onFlip: flip,
                  onRotate: rotate,
                  saturation: sat,
                  brightness: bright,
                  contrast: con,
                  onSaturation: (double value) => setState(() => sat = value),
                  onBrightness: (double value) => setState(() => bright = value),
                  onContrast: (double value) => setState(() => con = value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildImage(Size size) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(calculateContrastMatrix(con)),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(calculateSaturationMatrix(sat)),
        child: ExtendedImage(
          color: bright > 0 ? Colors.white.withValues(alpha: bright) : Colors.black.withValues(alpha: -bright),
          colorBlendMode: bright > 0 ? BlendMode.lighten : BlendMode.darken,
          image: ExtendedFileImageProvider(widget.image, cacheRawData: true),
          height: size.height,
          width: size.width,
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

  Future<void> crop() async {
    final ExtendedImageEditorState? state = editorKey.currentState;
    final Rect? rect = state?.getCropRect();
    final EditActionDetails? action = state?.editAction;
    if (state == null || rect == null || action == null) {
      toasts.error(context.l10n.wallpaperUploadEditSaveError);
      return;
    }
    setState(() => _saving = true);

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

    try {
      final Uint8List? result = await ImageEditor.editImage(image: img, imageEditorOption: option);
      if (!mounted) return;
      if (result == null) {
        toasts.error(context.l10n.wallpaperUploadEditSaveError);
        return;
      }

      widget.image.writeAsBytesSync(result);
      await context.router.replace(UploadWallRoute(image: widget.image, batch: widget.batch));
    } catch (_) {
      if (mounted) toasts.error(context.l10n.wallpaperUploadEditSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void flip() {
    PrismHaptics.tap();
    editorKey.currentState!.flip();
    setState(() => _transformed = true);
  }

  void rotate(bool right) {
    PrismHaptics.tap();
    editorKey.currentState!.rotate(degree: right ? 90 : -90);
    setState(() => _transformed = true);
  }
}
