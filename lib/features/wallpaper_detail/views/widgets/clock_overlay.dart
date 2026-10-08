import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/features/wallpaper_detail/biz/top_third_text_color.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

enum ClockPreviewMode { lock, home }

/// Width of the decode used to pick the clock text colour.
const int _sampleWidth = 32;

/// Full-screen preview of the wallpaper under a lock screen clock or a home screen dock.
/// The image is shown as it will be set. The clock text is black or white, whichever reads on the top third.
class ClockOverlay extends StatefulWidget {
  const ClockOverlay({required this.link, required this.file, this.thumbnailUrl});

  final String link;
  final bool file;

  /// Shown while the full image loads.
  final String? thumbnailUrl;

  @override
  State<ClockOverlay> createState() => _ClockOverlayState();
}

class _ClockOverlayState extends State<ClockOverlay> {
  late ClockPreviewMode _mode = defaultTargetPlatform == TargetPlatform.iOS
      ? ClockPreviewMode.lock
      : ClockPreviewMode.home;
  Color? _textColor;
  ImageStream? _sampleStream;
  ImageStreamListener? _sampleListener;

  ImageProvider get _provider =>
      widget.file ? FileImage(File(widget.link)) : CachedNetworkImageProvider(widget.link, cacheManager: _cache);

  BaseCacheManager get _cache => PrismFullImageCache.instance;

  @override
  void initState() {
    super.initState();
    _sampleText();
  }

  void _sampleText() {
    final ImageStream stream = ResizeImage(_provider, width: _sampleWidth).resolve(ImageConfiguration.empty);
    final ImageStreamListener listener = ImageStreamListener(
      (info, _) {
        unawaited(_applySample(info.image));
        _stopSampling();
      },
      onError: (error, stackTrace) {
        logger.w('ClockOverlay: could not sample the image', error: error, stackTrace: stackTrace);
        _stopSampling();
      },
    );
    _sampleStream = stream;
    _sampleListener = listener;
    stream.addListener(listener);
  }

  Future<void> _applySample(ui.Image image) async {
    final Color color = await textColorForTopThird(image);
    if (mounted) setState(() => _textColor = color);
  }

  void _stopSampling() {
    final ImageStreamListener? listener = _sampleListener;
    if (listener != null) _sampleStream?.removeListener(listener);
    _sampleListener = null;
    _sampleStream = null;
  }

  @override
  void dispose() {
    _stopSampling();
    super.dispose();
  }

  Widget _image(BuildContext context, Size size) {
    final Color placeholder = Theme.of(context).primaryColor;
    final int cacheWidth = previewCacheWidth(size.width, MediaQuery.devicePixelRatioOf(context));
    Widget error() => ColoredBox(
      color: placeholder,
      child: Center(child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.secondary)),
    );
    if (widget.file) {
      return SizedBox.expand(
        child: Image.file(
          File(widget.link),
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          errorBuilder: (_, _, _) => error(),
        ),
      );
    }
    final String thumbnail = widget.thumbnailUrl?.trim() ?? '';
    return SizedBox.expand(
      child: CachedNetworkImage(
        cacheManager: _cache,
        imageUrl: widget.link,
        fit: BoxFit.cover,
        memCacheWidth: cacheWidth,
        placeholder: (_, _) => thumbnail.isEmpty
            ? ColoredBox(color: placeholder)
            : CachedNetworkImage(
                cacheManager: PrismImageCache.instance,
                imageUrl: thumbnail,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => ColoredBox(color: placeholder),
              ),
        errorWidget: (_, _, _) => error(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final Color textColor = _textColor ?? Theme.of(context).colorScheme.secondary;
    final bool lock = _mode == ClockPreviewMode.lock;
    return Material(
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: _image(context, size)),
          Positioned.fill(
            child: lock ? LockPreviewLayer(textColor: textColor) : HomePreviewLayer(textColor: textColor),
          ),
          Semantics(
            button: true,
            label: 'Close preview',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: SizedBox(height: size.height, width: size.width),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SegmentedButton<ClockPreviewMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.7),
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                  segments: const <ButtonSegment<ClockPreviewMode>>[
                    ButtonSegment<ClockPreviewMode>(value: ClockPreviewMode.lock, label: Text('Lock')),
                    ButtonSegment<ClockPreviewMode>(value: ClockPreviewMode.home, label: Text('Home')),
                  ],
                  selected: <ClockPreviewMode>{_mode},
                  onSelectionChanged: (selection) => setState(() => _mode = selection.single),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
