import 'dart:io';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Hero tag for a wallpaper tile. It is unique per grid ([scope]), position and wallpaper, so the same wallpaper
/// shown twice never shares a tag.
String prismHeroTag(Object scope, int index, String id) => 'wall-${identityHashCode(scope)}-$index-$id';

/// Decode height, in physical pixels, for a grid tile that spans one of [crossAxisCount] equal columns of the screen
/// and has the given [aspectRatio] (width / height).
int gridTileDecodeHeight(BuildContext context, {required int crossAxisCount, double aspectRatio = 0.5}) {
  final double tileWidth = MediaQuery.sizeOf(context).width / crossAxisCount;
  return (tileWidth / aspectRatio * MediaQuery.devicePixelRatioOf(context)).round();
}

/// A grid image that fades in over the [PulseFill] skeleton. Fills its parent.
class PrismImageTile extends StatefulWidget {
  const PrismImageTile({
    super.key,
    required this.url,
    this.fallbackUrl,
    this.memCacheHeight,
    this.memCacheWidth,
    this.heroTag,
    this.borderRadius,
  });

  final String url;

  /// Tries the full wallpaper after a thumbnail failure, then offers retry if both fail.
  final String? fallbackUrl;
  final int? memCacheHeight;
  final int? memCacheWidth;
  final String? heroTag;
  final BorderRadius? borderRadius;

  @override
  State<PrismImageTile> createState() => _PrismImageTileState();
}

class _PrismImageTileState extends State<PrismImageTile> {
  int _attempt = 0;
  bool _retrying = false;
  bool _loadReported = false;
  final Stopwatch? _loadWatch = kReleaseMode ? null : (Stopwatch()..start());
  late Future<File?> _localFileFuture;

  @override
  void initState() {
    super.initState();
    _localFileFuture = _lookupLocalFile();
  }

  @override
  void didUpdateWidget(PrismImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.fallbackUrl != widget.fallbackUrl) {
      _attempt = 0;
      _retrying = false;
      _loadReported = false;
      _loadWatch
        ?..reset()
        ..start();
      _localFileFuture = _lookupLocalFile();
    }
  }

  Future<File?> _lookupLocalFile() async {
    final String url = _effectiveUrl;
    if (url.isEmpty) return null;
    if (_isLocalSource(url)) return File(_filePath(url));
    final String primary = widget.fallbackUrl?.trim().isNotEmpty == true ? widget.fallbackUrl!.trim() : url;
    final String source = _filePath(primary);
    try {
      final File localFile = File(source);
      if (await localFile.exists()) return localFile;
      return await OfflineAssetStore.instance.lookup(source);
    } catch (_) {
      return null;
    }
  }

  String _filePath(String source) {
    final Uri? uri = Uri.tryParse(source);
    return uri?.scheme == 'file' ? uri!.toFilePath() : source;
  }

  bool _isLocalSource(String source) {
    if (source.isEmpty) return false;
    final String scheme = Uri.tryParse(source)?.scheme.toLowerCase() ?? '';
    return scheme != 'http' && scheme != 'https';
  }

  String get _effectiveUrl => widget.url.trim().isNotEmpty ? widget.url.trim() : widget.fallbackUrl?.trim() ?? '';

  Future<void> _retry() async {
    PrismHaptics.tap();
    setState(() => _retrying = true);
    try {
      for (final url in {widget.url, widget.fallbackUrl}.whereType<String>().where((url) => url.isNotEmpty)) {
        await CachedNetworkImage.evictFromCache(url, cacheManager: PrismImageCache.instance);
      }
    } catch (error, stackTrace) {
      logger.w('Could not clear the wallpaper image cache for retry', error: error, stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _retrying = false;
          _attempt++;
          _localFileFuture = _lookupLocalFile();
        });
      }
    }
  }

  /// Decodes at the tile's own size so a grid does not hold full wallpapers in memory. A caller's width is used alone:
  /// a width and a height together decode to exactly that box and squash the image.
  int? _decodeHeight(BuildContext context, BoxConstraints constraints) =>
      widget.memCacheHeight ??
      (widget.memCacheWidth == null && constraints.hasBoundedHeight
          ? (constraints.maxHeight * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 4096)
          : null);

  Widget _image(BuildContext context, String url, {String? fallback}) => LayoutBuilder(
    builder: (context, constraints) => _network(context, url, _decodeHeight(context, constraints), fallback: fallback),
  );

  void _reportImage(String name, {required bool success}) {
    if (kReleaseMode || _loadReported) return;
    _loadReported = true;
    PerformanceProbe.emit(
      kind: 'image.thumb',
      name: name,
      durationMs: _loadWatch!.elapsedMilliseconds,
      success: success,
    );
  }

  Widget _network(BuildContext context, String url, int? decodeHeight, {String? fallback}) => CachedNetworkImage(
    key: ValueKey((url, _attempt)),
    imageUrl: url,
    cacheManager: PrismImageCache.instance,
    fit: BoxFit.cover,
    fadeInDuration: context.motion(PrismDurations.fast),
    fadeInCurve: PrismCurves.enter,
    fadeOutDuration: context.motion(PrismDurations.fast),
    memCacheHeight: decodeHeight,
    memCacheWidth: widget.memCacheWidth,
    imageBuilder: kReleaseMode
        ? null
        : (BuildContext context, ImageProvider imageProvider) {
            _reportImage('decoded', success: true);
            return Image(
              image: ResizeImage.resizeIfNeeded(widget.memCacheWidth, decodeHeight, imageProvider),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            );
          },
    placeholder: (_, _) => PulseFill(borderRadius: widget.borderRadius),
    errorWidget: (context, _, _) {
      _reportImage('error', success: false);
      return _offlineOrNetworkFallback(context, url: url, decodeHeight: decodeHeight, fallback: fallback);
    },
  );

  Widget _offlineOrNetworkFallback(
    BuildContext context, {
    required String url,
    required int? decodeHeight,
    String? fallback,
  }) => FutureBuilder<File?>(
    future: _localFileFuture,
    builder: (context, snapshot) {
      final File? localFile = snapshot.data;
      if (localFile != null) return _fileImage(localFile, decodeHeight);
      if (snapshot.connectionState != ConnectionState.done) return PulseFill(borderRadius: widget.borderRadius);
      if (fallback != null && fallback.isNotEmpty && fallback != url) {
        return _network(context, fallback, decodeHeight);
      }
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Align(
          alignment: AlignmentDirectional.bottomEnd,
          child: IconButton(
            tooltip: 'Retry image',
            onPressed: _retrying ? null : _retry,
            icon: const Icon(Icons.refresh_rounded),
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    },
  );

  Widget _fileImage(File file, int? decodeHeight) => Image.file(
    file,
    fit: BoxFit.cover,
    cacheHeight: decodeHeight,
    cacheWidth: widget.memCacheWidth,
    errorBuilder: (context, _, _) =>
        ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const SizedBox.expand()),
  );

  Widget _localImage(BuildContext context, String source) => LayoutBuilder(
    builder: (context, constraints) => _fileImage(File(_filePath(source)), _decodeHeight(context, constraints)),
  );

  Widget _retainedOrNetworkImage(BuildContext context, String url) => FutureBuilder<File?>(
    future: _localFileFuture,
    builder: (context, snapshot) {
      final File? localFile = snapshot.data;
      if (localFile != null) {
        return LayoutBuilder(
          builder: (context, constraints) => _fileImage(localFile, _decodeHeight(context, constraints)),
        );
      }
      return _image(context, url, fallback: widget.fallbackUrl);
    },
  );

  @override
  Widget build(BuildContext context) {
    final String url = _effectiveUrl;
    Widget tile;
    if (url.isEmpty) {
      tile = PulseFill(borderRadius: widget.borderRadius);
    } else if (_isLocalSource(url)) {
      tile = _localImage(context, url);
    } else {
      tile = _retainedOrNetworkImage(context, url);
    }
    tile = SizedBox.expand(child: tile);
    if (widget.borderRadius != null) tile = ClipRRect(borderRadius: widget.borderRadius!, child: tile);
    return widget.heroTag == null || context.reduceMotion ? tile : Hero(tag: widget.heroTag!, child: tile);
  }
}
