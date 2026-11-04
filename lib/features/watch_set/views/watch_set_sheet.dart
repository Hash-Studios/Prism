import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/watch_set/data/depth_subject_box.dart';
import 'package:Prism/features/watch_set/data/watch_image_renderer.dart';
import 'package:Prism/features/watch_set/data/watch_type_store.dart';
import 'package:Prism/features/watch_set/domain/entities/matching_set.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:Prism/features/watch_set/domain/smart_watch_crop.dart';
import 'package:Prism/features/watch_set/views/watch_crop_page.dart';
import 'package:Prism/features/watch_set/views/watch_guide.dart';
import 'package:Prism/features/watch_set/views/widgets/watch_previews.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The wall a watch set is made from, as the sheet needs it.
@immutable
class WatchSetWall {
  const WatchSetWall({
    required this.id,
    required this.source,
    required this.link,
    required this.previewUrl,
    required this.isPremium,
    this.pixelSize,
    this.desktop,
    this.depthMapUrl,
    this.title,
    this.creatorName,
  });

  final String id;
  final WallpaperSource source;

  /// The download link. For a protected Prism wall the gate swaps it for the granted original.
  final String link;

  /// A picture the user may already see: the display copy or the thumbnail. The crop is made on it.
  final String previewUrl;
  final bool isPremium;
  final Size? pixelSize;
  final WallDesktopVariant? desktop;

  /// The Spatial Scenes depth map, when the wall has one. It gives the subject box of the smart crop.
  final String? depthMapUrl;
  final String? title;
  final String? creatorName;
}

/// Max side the preview decodes at. The crop is scaled to the full file on save.
const int _previewDecodeSide = 1600;

Future<void> showWatchSetSheet(BuildContext context, WatchSetWall wall) =>
    showPrismSheet<void>(context, builder: (_) => WatchSetSheet(wall: wall));

enum _Step { pick, set, guide }

class WatchSetSheet extends StatefulWidget {
  const WatchSetSheet({super.key, required this.wall});

  final WatchSetWall wall;

  @override
  State<WatchSetSheet> createState() => _WatchSetSheetState();
}

class _WatchSetSheetState extends State<WatchSetSheet> {
  late _Step _step;
  WatchFormat? _format;
  ui.Image? _image;
  bool _imageFailed = false;
  bool _saving = false;
  PixelRect? _subject;
  bool _subjectLoaded = false;
  MatchingSet? _set;
  CropSpec? _smart;
  String? _shareCopy;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _format = rememberedWatchFormat();
    _step = _format == null ? _Step.pick : _Step.set;
    _loadImage();
  }

  @override
  void dispose() {
    _stopListening();
    _image?.dispose();
    final String? copy = _shareCopy;
    if (copy != null) unawaited(deleteWatchImage(copy));
    super.dispose();
  }

  ImageProvider get _provider {
    final String url = widget.wall.previewUrl;
    final ImageProvider base = isValidNetworkUrl(url)
        ? CachedNetworkImageProvider(url, cacheManager: PrismImageCache.instance)
        : FileImage(File(url));
    return ResizeImage(base, width: _previewDecodeSide, height: _previewDecodeSide, policy: ResizeImagePolicy.fit);
  }

  void _stopListening() {
    final ImageStreamListener? listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _retry() {
    setState(() => _imageFailed = false);
    _loadImage();
  }

  void _loadImage() {
    _stopListening();
    final ImageStream stream = _provider.resolve(ImageConfiguration.empty);
    final ImageStreamListener listener = ImageStreamListener(
      (ImageInfo info, _) {
        _stopListening();
        if (!mounted) {
          info.dispose();
          return;
        }
        setState(() {
          _image?.dispose();
          _image = info.image.clone();
        });
        info.dispose();
        unawaited(_loadSubject());
      },
      onError: (Object error, StackTrace? stackTrace) {
        _stopListening();
        logger.w('Watch set preview did not load', error: error, stackTrace: stackTrace);
        if (mounted) setState(() => _imageFailed = true);
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  Future<void> _loadSubject() async {
    final ui.Image? image = _image;
    final String? map = widget.wall.depthMapUrl;
    if (image == null) return;
    if (map != null && !_subjectLoaded) {
      _subject = await loadDepthSubjectBox(map, sourceWidth: image.width, sourceHeight: image.height);
    }
    _subjectLoaded = true;
    if (mounted) setState(_resetCrop);
  }

  void _resetCrop() {
    final ui.Image? image = _image;
    final WatchFormat? format = _format;
    if (image == null || format == null || !_subjectLoaded) return;
    final CropSpec smart = smartWatchCrop(
      sourceWidth: image.width,
      sourceHeight: image.height,
      format: format,
      subject: _subject,
    );
    _smart = smart;
    _set = MatchingSet(watch: format, watchCrop: smart, desktop: widget.wall.desktop);
  }

  void _pick(WatchFormat format) {
    PrismHaptics.selection();
    unawaited(rememberWatchFormat(format));
    setState(() {
      _format = format;
      _step = _Step.set;
      _resetCrop();
    });
  }

  Future<void> _adjust() async {
    final MatchingSet? set = _set;
    final ui.Image? image = _image;
    final CropSpec? smart = _smart;
    if (set == null || image == null || smart == null) return;
    final CropSpec? kept = await Navigator.of(context).push<CropSpec>(
      MaterialPageRoute<CropSpec>(
        builder: (_) => WatchCropPage(image: image, initial: set.watchCrop, smart: smart, format: set.watch),
      ),
    );
    if (kept == null || !mounted || _set?.watch != set.watch) return;
    if (kept != smart) analytics.track(WatchCropAdjustedEvent(watchType: set.watch));
    setState(() => _set = set.copyWith(watchCrop: kept));
  }

  void _openGuide(WatchGuideSourceValue source) {
    final WatchFormat? format = _format;
    if (format == null) return;
    analytics.track(WatchGuideOpenedEvent(watchType: format, source: source));
    setState(() => _step = _Step.guide);
  }

  void _onSaved(
    MatchingSet set,
    AppLocalizations l10n, {
    required bool desktopSaved,
    required Map<String, String> files,
  }) {
    analytics.track(WatchSetSavedEvent(watchType: set.watch, withDesktop: desktopSaved));
    if (set.withDesktop && !desktopSaved) {
      toasts.error(l10n.watchSetDesktopNotSaved);
    } else {
      toasts.success(l10n.watchSetSaved);
    }
    if (!mounted) return;
    final String? watchFile = files[set.watchKey];
    if (watchFile != null) {
      try {
        final String copy = '${File(watchFile).parent.path}/share_${DateTime.now().microsecondsSinceEpoch}.png';
        File(watchFile).copySync(copy);
        final String? previous = _shareCopy;
        if (previous != null) unawaited(deleteWatchImage(previous));
        _shareCopy = copy;
      } catch (error, stackTrace) {
        logger.w('Could not keep the watch image to share', error: error, stackTrace: stackTrace);
      }
    }
    _openGuide(WatchGuideSourceValue.afterSave);
  }

  Future<void> _share() async {
    final String? copy = _shareCopy;
    if (copy == null) return;
    PrismHaptics.tap();
    try {
      await ShareService.shareFile(file: File(copy), text: '', context: context);
    } catch (error, stackTrace) {
      logger.w('Could not share the watch image', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final WatchFormat? format = _format;
    return switch (_step) {
      _Step.pick => _WatchPicker(selected: format, onPicked: _pick),
      _Step.guide when format != null => WatchGuide(
        format: format,
        onShare: _shareCopy == null || !hideSetWallpaperUi ? null : _share,
      ),
      _ => _buildSet(context),
    };
  }

  Widget _buildSet(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final WatchSetWall wall = widget.wall;
    final MatchingSet? set = _set;
    final WallDesktopVariant? desktop = wall.desktop;
    return PrismSheetBody(
      title: l10n.watchSetSheetTitle,
      message: desktop == null ? l10n.watchSetSheetMessage : l10n.watchSetSheetMessageDesktop,
      actions: <Widget>[
        if (set == null)
          PrismButton(
            label: l10n.watchSetSave,
            loading: !_imageFailed,
            expand: true,
            onPressed: _imageFailed ? _retry : null,
          )
        else ...<Widget>[
          DownloadButton(
            key: ValueKey<String>('watch-set-save-${set.watchKey}'),
            primary: true,
            expand: true,
            label: l10n.watchSetSave,
            link: wall.link,
            contentId: wall.id,
            wallpaperSource: wall.source,
            isPremiumContent: wall.isPremium,
            wallpaperTitle: wall.title,
            creatorName: wall.creatorName,
            sourceContext: 'watch_set',
            set: DownloadSet(
              key: set.watchKey,
              desktop: desktop,
              onBusyChanged: (bool saving) {
                if (mounted) setState(() => _saving = saving);
              },
              prepare: (String phoneSource) async => <String, String>{
                set.watchKey: await renderWatchImage(
                  source: phoneSource,
                  crop: set.watchCrop,
                  format: set.watch,
                  wallpaperId: wall.id,
                  wallpaperSource: wall.source,
                ),
              },
              onSaved: ({required bool desktopSaved, required Map<String, String> files}) =>
                  _onSaved(set, l10n, desktopSaved: desktopSaved, files: files),
            ),
          ),
          PrismButton(
            label: l10n.watchSetAdjustCrop,
            icon: Icons.crop_rounded,
            variant: PrismButtonVariant.tonal,
            expand: true,
            maxLines: 3,
            onPressed: _saving ? null : _adjust,
          ),
          PrismButton(
            label: l10n.watchSetHowTo,
            variant: PrismButtonVariant.ghost,
            expand: true,
            maxLines: 3,
            onPressed: _saving ? null : () => _openGuide(WatchGuideSourceValue.sheet),
          ),
        ],
      ],
      child: _imageFailed
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: PrismSpace.md),
              child: Text(l10n.watchSetPreviewFailed, style: PrismTextStyles.body(context)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SetPreview(wall: wall, image: _image, set: set),
                if (_format case final WatchFormat format)
                  PrismGroup(
                    children: <Widget>[
                      PrismRow(
                        key: const ValueKey<String>('watch-set-change'),
                        icon: Icons.watch_rounded,
                        title: watchFormatLabel(l10n, format),
                        subtitle: l10n.watchSetChangeWatch,
                        onTap: _saving ? null : () => setState(() => _step = _Step.pick),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _SetPreview extends StatelessWidget {
  const _SetPreview({required this.wall, required this.image, required this.set});

  final WatchSetWall wall;
  final ui.Image? image;
  final MatchingSet? set;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ui.Image? image = this.image;
    final MatchingSet? set = this.set;
    final WallDesktopVariant? desktop = wall.desktop;
    final Size? phonePixels = wall.pixelSize;
    final Widget placeholder = ColoredBox(color: scheme.surfaceContainer);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PrismSpace.md),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: PrismSpace.lg,
        runSpacing: PrismSpace.lg,
        children: <Widget>[
          SetItemTile(
            name: l10n.watchSetItemPhone,
            size: phonePixels == null
                ? l10n.watchSetItemFullSize
                : l10n.wallpaperCropSize(phonePixels.width.round(), phonePixels.height.round()),
            preview: DeviceFramePreview(
              width: 76,
              aspectRatio: 9 / 19.5,
              radius: 12,
              semanticLabel: l10n.watchSetPhonePreviewSemantic,
              child: image == null ? placeholder : RawImage(image: image, fit: BoxFit.cover),
            ),
          ),
          SetItemTile(
            name: l10n.watchSetItemWatch,
            size: set == null ? '' : l10n.wallpaperCropSize(set.watch.width, set.watch.height),
            preview: image == null || set == null
                ? const PrismBone(width: 96, height: 112, radius: PrismRadius.lg)
                : WatchFacePreview(
                    image: image,
                    crop: set.watchCrop,
                    format: set.watch,
                    width: 96,
                    semanticLabel: l10n.watchSetWatchPreviewSemantic(watchFormatLabel(l10n, set.watch)),
                  ),
          ),
          if (desktop != null)
            SetItemTile(
              name: l10n.watchSetItemDesktop,
              size: l10n.wallpaperCropSize(desktop.width, desktop.height),
              preview: DeviceFramePreview(
                width: 152,
                aspectRatio: 16 / 10,
                radius: 6,
                semanticLabel: l10n.watchSetDesktopPreviewSemantic,
                child: CachedNetworkImage(
                  imageUrl: desktop.thumbnailUrl,
                  cacheManager: PrismImageCache.instance,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => placeholder,
                  errorWidget: (_, _, _) => placeholder,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String watchFormatLabel(AppLocalizations l10n, WatchFormat format) => switch (format) {
  WatchFormat.apple40 => l10n.watchFormatApple40,
  WatchFormat.apple44 => l10n.watchFormatApple44,
  WatchFormat.apple41 => l10n.watchFormatApple41,
  WatchFormat.apple45 => l10n.watchFormatApple45,
  WatchFormat.apple42 => l10n.watchFormatApple42,
  WatchFormat.apple46 => l10n.watchFormatApple46,
  WatchFormat.appleUltra => l10n.watchFormatAppleUltra,
  WatchFormat.appleUltra3 => l10n.watchFormatAppleUltra3,
  WatchFormat.pixelWatch => l10n.watchFormatPixelWatch,
  WatchFormat.galaxySmall => l10n.watchFormatGalaxySmall,
  WatchFormat.galaxyLarge => l10n.watchFormatGalaxyLarge,
};

/// The watch list, with this phone's platform first.
class _WatchPicker extends StatelessWidget {
  const _WatchPicker({required this.selected, required this.onPicked});

  final WatchFormat? selected;
  final ValueChanged<WatchFormat> onPicked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<WatchPlatform> order = hideSetWallpaperUi
        ? const <WatchPlatform>[WatchPlatform.appleWatch, WatchPlatform.wearOs]
        : const <WatchPlatform>[WatchPlatform.wearOs, WatchPlatform.appleWatch];
    return PrismSheetBody(
      title: l10n.watchSetPickerTitle,
      message: l10n.watchSetPickerMessage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final WatchPlatform platform in order) ...<Widget>[
            PrismSectionHeader(
              title: platform == WatchPlatform.appleWatch ? l10n.watchSetPlatformApple : l10n.watchSetPlatformWearOs,
              small: true,
            ),
            PrismGroup(
              children: <Widget>[
                for (final WatchFormat format in WatchFormat.values.where((f) => f.platform == platform))
                  Semantics(
                    selected: format == selected,
                    child: PrismRow(
                      key: ValueKey<String>('watch-format-${format.id}'),
                      title: watchFormatLabel(l10n, format),
                      subtitle: l10n.wallpaperCropSize(format.width, format.height),
                      icon: format.shape == WatchShape.round ? Icons.circle_outlined : Icons.watch_rounded,
                      trailing: format == selected ? Icon(Icons.check_rounded, color: scheme.primary) : null,
                      showChevron: false,
                      onTap: () => onPicked(format),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: PrismSpace.xs),
              child: Text(
                platform == WatchPlatform.appleWatch ? l10n.watchSetPickerHintApple : l10n.watchSetPickerHintWearOs,
                style: PrismTextStyles.body(context).copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
