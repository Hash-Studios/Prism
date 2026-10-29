import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

const Duration _thumbnailFade = Duration(milliseconds: 180);
const Duration _fullFade = Duration(milliseconds: 280);

/// A wallpaper on a large surface, drawn with [BoxFit.cover]. The thumbnail shows first; the full picture fades in
/// over it and, once shown, stays. A copy on the device wins over the network. The full picture gets one retry, then
/// the thumbnail stays.
///
/// Nothing is painted until a picture decodes, so whatever is under this (a grid tile's Hero) shows through.
class ProgressiveWallpaperImage extends StatefulWidget {
  const ProgressiveWallpaperImage({
    super.key,
    required this.display,
    this.decodeBox,
    this.errorBuilder,
    this.onPictureSize,
  });

  final WallpaperDisplaySource display;

  /// The box, in logical pixels, the decode is sized for. Defaults to the screen. It is fixed, not the live layout, so
  /// a Hero flight does not decode again on every frame.
  final Size? decodeBox;

  /// Shown when no picture can load. `retry` loads both pictures again.
  final Widget Function(BuildContext context, VoidCallback retry)? errorBuilder;

  /// Called after a frame with the pixel size of the full picture when it first paints. Its shape is the wallpaper's.
  /// The thumbnail is never reported: some sources crop it.
  final ValueChanged<Size>? onPictureSize;

  /// Replaces the on-device lookup in tests.
  @visibleForTesting
  static Future<File?> Function(WallpaperDisplaySource display)? offlineCopyOverride;

  @override
  State<ProgressiveWallpaperImage> createState() => _ProgressiveWallpaperImageState();
}

class _ProgressiveWallpaperImageState extends State<ProgressiveWallpaperImage> {
  /// What the full layer loads: a URL, an `assets/` path or a file. Null while the device is checked.
  String? _full;
  File? _fullFile;

  /// The full picture is on the device, so it shows without a fade.
  bool _instant = false;

  /// The full picture has painted. From here the thumbnail is gone for this wall.
  bool _shown = false;
  ui.Image? _lastPaintedImage;
  ImageProvider? _lastPaintedProvider;
  bool _failed = false;
  int _attempt = 0;
  int _generation = 0;
  int _retries = 0;
  Size? _reportedSize;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ProgressiveWallpaperImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.display == widget.display) return;
    final WallpaperDisplaySource before = oldWidget.display;
    final WallpaperDisplaySource now = widget.display;
    final bool sameWall = now.id != null && before.id == now.id && before.source == now.source;
    if (!sameWall || now.withheld) {
      _shown = false;
      _clearPaintedImages();
      _reportedSize = null;
    }
    _failed = false;
    _attempt = 0;
    _resolve();
  }

  @override
  void dispose() {
    ++_generation;
    _full = null;
    _fullFile = null;
    _clearPaintedImages();
    super.dispose();
  }

  void _clearPaintedImages() {
    final ui.Image? image = _lastPaintedImage;
    _lastPaintedImage = null;
    _lastPaintedProvider = null;
    image?.dispose();
  }

  RawImage? _rawImage(Widget child) {
    if (child is RawImage) return child;
    if (child is Semantics && child.child != null) return _rawImage(child.child!);
    return null;
  }

  void _markShown(int generation, ImageProvider provider, Widget child) {
    if (!mounted || generation != _generation) return;
    final RawImage? rawImage = _rawImage(child);
    if (rawImage?.image == null) return;
    final bool changed = provider != _lastPaintedProvider;
    if (changed) {
      _lastPaintedImage?.dispose();
      _lastPaintedImage = rawImage!.image!.clone();
    }
    _lastPaintedProvider = provider;
    if (!_shown || changed) setState(() => _shown = true);
  }

  void _resolve() {
    final int generation = ++_generation;
    final String full = widget.display.full;
    if (full.isEmpty) {
      _full = full;
      _fullFile = null;
      _instant = true;
      if (widget.display.source == WallpaperSource.prism && !widget.display.withheld) {
        unawaited(
          _onDevice(full).then((File? file) {
            if (!mounted || generation != _generation || file == null) return;
            setState(() => _fullFile = file);
          }),
        );
      }
      return;
    }
    if (!isValidNetworkUrl(full)) {
      _full = full;
      _fullFile = null;
      _instant = true;
      return;
    }
    // A wall that already shows its full picture keeps it until the new one is ready.
    if (!_shown) _full = null;
    unawaited(
      _onDevice(full).then((File? file) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _fullFile = file;
          _instant = file != null;
          _full = full;
        });
      }),
    );
  }

  Future<File?> _onDevice(String full) async {
    final File? offline = await (ProgressiveWallpaperImage.offlineCopyOverride ?? wallpaperOfflineCopy)(widget.display);
    if (offline != null) return offline;
    if (!isValidNetworkUrl(full)) return null;
    try {
      return (await PrismFullImageCache.instance.getFileFromCache(full))?.file;
    } catch (_) {
      return null;
    }
  }

  /// The thumbnail remains visible until the full image has actually painted, even when both links are the same.
  String get _thumbnail => isValidNetworkUrl(widget.display.thumbnail) ? widget.display.thumbnail : '';

  void _onFullError(Object error, int attempt, int generation) {
    if (!mounted || generation != _generation || attempt != _attempt || _failed) return;
    final String full = widget.display.full;
    if (_attempt == 0) {
      _evict(full, () => PrismFullImageCache.instance);
      setState(() {
        _attempt++;
        _instant = false;
        _fullFile = null;
      });
      return;
    }
    setState(() {
      _failed = true;
    });
    unawaited(
      MonitoringRuntime.reporter.addBreadcrumb(
        message: 'Full wallpaper image failed, kept the thumbnail',
        category: 'wallpaper.image',
        severity: ErrorSeverity.warning,
        data: <String, Object?>{
          'source': widget.display.source?.name,
          'id': widget.display.id,
          'host': Uri.tryParse(full)?.host,
          'error': error.runtimeType.toString(),
        },
      ),
    );
  }

  /// Caches are passed as getters: a local file or asset must not open the disk cache.
  void _evict(String url, BaseCacheManager Function() cache) {
    if (!isValidNetworkUrl(url)) return;
    unawaited(CachedNetworkImage.evictFromCache(url, cacheManager: cache()).catchError((Object _) => false));
  }

  void _retry() {
    if (!mounted) return;
    _evict(widget.display.thumbnail, () => PrismImageCache.instance);
    _evict(widget.display.full, () => PrismFullImageCache.instance);
    _clearPaintedImages();
    setState(() {
      _failed = false;
      _shown = false;
      _attempt = 0;
      _retries++;
      _reportedSize = null;
      _resolve();
    });
  }

  ImageProvider? _provider(String link, BaseCacheManager Function() cache, File? file) {
    if (file != null) return FileImage(file);
    if (link.isEmpty) return null;
    if (link.startsWith('assets/')) return AssetImage(link);
    if (isValidNetworkUrl(link)) return CachedNetworkImageProvider(link, cacheManager: cache());
    final Uri? uri = Uri.tryParse(link);
    return FileImage(File(uri?.scheme == 'file' ? uri!.toFilePath() : link));
  }

  Widget _fadeIn(Widget child, Duration duration, {VoidCallback? onEnd}) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: duration,
    curve: PrismCurves.enter,
    onEnd: onEnd,
    builder: (_, double opacity, Widget? child) => Opacity(opacity: opacity, child: child),
    child: child,
  );

  Widget _thumbnailFrame(BuildContext context, Widget child, int? frame, bool sync) {
    if (frame == null) return const SizedBox.expand();
    final Duration fade = context.motion(_thumbnailFade);
    return sync || fade == Duration.zero ? child : _fadeIn(child, fade);
  }

  void _reportSize(Widget child) {
    final ValueChanged<Size>? report = widget.onPictureSize;
    final ui.Image? image = _rawImage(child)?.image;
    if (report == null || image == null) return;
    final Size size = Size(image.width.toDouble(), image.height.toDouble());
    if (size == _reportedSize) return;
    _reportedSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) report(size);
    });
  }

  Widget _fullFrame(BuildContext context, Widget child, int? frame, bool sync, int generation, ImageProvider image) {
    if (frame != null) _reportSize(child);
    if (_shown && image == _lastPaintedProvider) return child;
    if (frame == null) return const SizedBox.expand();
    final Duration fade = context.motion(_fullFade);
    if (sync || _instant || fade == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markShown(generation, image, child));
      return child;
    }
    return _fadeIn(child, fade, onEnd: () => _markShown(generation, image, child));
  }

  @override
  Widget build(BuildContext context) {
    final Size box = widget.decodeBox ?? MediaQuery.sizeOf(context);
    final double ratio = MediaQuery.devicePixelRatioOf(context);
    ImageProvider? sized(ImageProvider? provider) =>
        provider == null ? null : sizedWallpaperImage(provider, box, ratio, widget.display.pixelSize);

    final String? full = _full;
    final int generation = _generation;
    final ImageProvider? fullImage = _failed || full == null
        ? null
        : sized(_provider(full, () => PrismFullImageCache.instance, _fullFile));
    final ui.Image? fullFallback = _shown ? _lastPaintedImage : null;
    final ImageProvider? thumbnail = _shown ? null : sized(_provider(_thumbnail, () => PrismImageCache.instance, null));
    final bool fullMissing = _failed || widget.display.full.isEmpty;
    final Widget error = widget.errorBuilder?.call(context, _retry) ?? const SizedBox.expand();

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (fullFallback != null)
          RawImage(key: const ValueKey<String>('last-full'), image: fullFallback, fit: BoxFit.cover),
        if (thumbnail != null)
          Image(
            key: ValueKey<(String, int)>(('thumbnail', _retries)),
            image: thumbnail,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: _thumbnailFrame,
            errorBuilder: (_, _, _) => fullMissing ? error : const SizedBox.expand(),
          )
        else if (fullImage == null && fullFallback == null && fullMissing)
          error,
        if (fullImage != null)
          Image(
            key: ValueKey<(String, int, int, int)>(('full', _retries, _attempt, _generation)),
            image: fullImage,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) =>
                _fullFrame(context, child, frame, sync, generation, fullImage),
            errorBuilder: (_, Object error, _) {
              final int attempt = _attempt;
              WidgetsBinding.instance.addPostFrameCallback((_) => _onFullError(error, attempt, generation));
              return const SizedBox.expand();
            },
          ),
      ],
    );
  }
}
