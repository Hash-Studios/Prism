import 'dart:ui' as ui;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/crop_frame_view.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The editor's crop frame on the watch aspect, with the watch screen drawn in it. Pops with the kept crop.
class WatchCropPage extends StatefulWidget {
  const WatchCropPage({
    super.key,
    required this.image,
    required this.initial,
    required this.smart,
    required this.format,
  });

  final ui.Image image;
  final CropSpec initial;

  /// What Reset goes back to.
  final CropSpec smart;
  final WatchFormat format;

  @override
  State<WatchCropPage> createState() => _WatchCropPageState();
}

class _WatchCropPageState extends State<WatchCropPage> {
  late CropSpec _crop = widget.initial;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final WatchMask mask = WatchMask(widget.format.shape);
    return PrismPage(
      title: l10n.watchCropTitle,
      actions: <Widget>[
        PrismButton(
          label: l10n.watchCropReset,
          variant: PrismButtonVariant.ghost,
          size: PrismButtonSize.compact,
          onPressed: _crop == widget.smart
              ? null
              : () {
                  PrismHaptics.selection();
                  setState(() => _crop = widget.smart);
                },
        ),
      ],
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.xs, PrismSpace.md, PrismSpace.md),
        child: PrismButton(
          key: const ValueKey<String>('watch-crop-done'),
          label: l10n.watchCropDone,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_crop),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ColoredBox(
              color: Colors.black,
              child: CropFrameView(
                spec: _crop,
                image: RawImage(image: widget.image, fit: BoxFit.fill),
                window: mask.outline,
                onChanged: (CropSpec next) => setState(() => _crop = next),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.sm, PrismSpace.md, 0),
            child: Column(
              children: <Widget>[
                Text(
                  l10n.wallpaperCropSize(widget.format.width, widget.format.height),
                  style: PrismTextStyles.rowTitle(context),
                  textAlign: TextAlign.center,
                ),
                Text(
                  l10n.watchCropHint,
                  style: PrismTextStyles.body(context).copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
