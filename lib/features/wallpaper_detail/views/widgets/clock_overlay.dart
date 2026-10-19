import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/features/wallpaper_detail/biz/top_third_text_color.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

enum ClockPreviewMode {
  lock('Lock'),
  home('Home');

  const ClockPreviewMode(this.label);

  final String label;
}

/// Width of the decode used to pick the clock text colour.
const int _sampleWidth = 32;

/// Full-screen preview of the wallpaper under a lock screen clock or a home screen dock.
/// The image is shown as it will be set. The clock text is black or white, whichever reads on the top third.
@RoutePage(name: 'ClockPreviewRoute')
class ClockOverlay extends StatefulWidget {
  const ClockOverlay({
    super.key,
    required this.link,
    required this.file,
    this.wallpaperId,
    this.wallpaperSource,
    this.thumbnailUrl,
    this.tint,
  });

  final String link;
  final bool file;
  final String? wallpaperId;
  final WallpaperSource? wallpaperSource;

  /// Shown while the full image loads.
  final String? thumbnailUrl;

  /// The colour variation the user picked. When set, the image is shown with this hue.
  final Color? tint;

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
  Future<File?>? _localFileFuture;
  File? _localFile;

  ImageProvider get _provider => _localFile != null
      ? FileImage(_localFile!)
      : widget.link.startsWith('assets/')
      ? AssetImage(widget.link)
      : CachedNetworkImageProvider(widget.link, cacheManager: _cache);

  BaseCacheManager get _cache => PrismFullImageCache.instance;

  @override
  void initState() {
    super.initState();
    _localFileFuture = _resolveLocalFile();
    unawaited(_sampleText());
  }

  Future<File?> _resolveLocalFile() async {
    if (widget.file) return File(widget.link);
    if (widget.link.startsWith('assets/')) return null;
    try {
      return await WallpaperService.resolveToLocalFile(
        widget.link,
        allowNetwork: false,
        wallpaperId: widget.wallpaperId,
        wallpaperSource: widget.wallpaperSource,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _sampleText() async {
    _localFile = await _localFileFuture;
    if (!mounted) return;
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
    final Color color = await textColorForTopThird(image, tint: widget.tint);
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

  Widget _tinted(Widget image) {
    final Color? tint = widget.tint;
    if (tint == null) return image;
    return ColorFiltered(colorFilter: ColorFilter.mode(tint, BlendMode.hue), child: image);
  }

  Widget _tintedPhoto(BuildContext context, ImageProvider provider) => _tinted(
    SizedBox.expand(
      child: Image(image: provider, fit: BoxFit.cover),
    ),
  );

  ImageWidgetBuilder? get _tintedBuilder => widget.tint == null ? null : _tintedPhoto;

  Widget _image(BuildContext context, Size size) {
    final Color placeholder = Theme.of(context).primaryColor;
    final int cacheWidth = previewCacheWidth(size.width, MediaQuery.devicePixelRatioOf(context));
    Widget error() => ColoredBox(
      color: placeholder,
      child: Center(child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.secondary)),
    );
    if (widget.file || (!isValidNetworkUrl(widget.link) && !widget.link.startsWith('assets/'))) {
      final Uri? uri = Uri.tryParse(widget.link);
      final String path = uri?.scheme == 'file' ? uri!.toFilePath() : widget.link;
      return SizedBox.expand(
        child: _tinted(
          Image.file(
            _localFile ?? File(path),
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            errorBuilder: (_, _, _) => error(),
          ),
        ),
      );
    }
    if (widget.link.startsWith('assets/')) {
      return SizedBox.expand(
        child: _tinted(
          Image.asset(widget.link, fit: BoxFit.cover, cacheWidth: cacheWidth, errorBuilder: (_, _, _) => error()),
        ),
      );
    }
    final String thumbnail = widget.thumbnailUrl?.trim() ?? '';
    return SizedBox.expand(
      child: FutureBuilder<File?>(
        future: _localFileFuture,
        builder: (BuildContext context, AsyncSnapshot<File?> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return ColoredBox(color: placeholder);
          final File? local = snapshot.data;
          if (local != null) {
            _localFile = local;
            return _tinted(
              Image.file(local, fit: BoxFit.cover, cacheWidth: cacheWidth, errorBuilder: (_, _, _) => error()),
            );
          }
          return CachedNetworkImage(
            cacheManager: _cache,
            imageUrl: widget.link,
            fit: BoxFit.cover,
            memCacheWidth: cacheWidth,
            imageBuilder: _tintedBuilder,
            placeholder: (_, _) => thumbnail.isEmpty
                ? ColoredBox(color: placeholder)
                : CachedNetworkImage(
                    cacheManager: PrismImageCache.instance,
                    imageUrl: thumbnail,
                    fit: BoxFit.cover,
                    imageBuilder: _tintedBuilder,
                    errorWidget: (_, _, _) => ColoredBox(color: placeholder),
                  ),
            errorWidget: (_, _, _) => error(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final Color textColor = _textColor ?? Theme.of(context).colorScheme.secondary;
    final bool lock = _mode == ClockPreviewMode.lock;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: <Widget>[
          Positioned(left: 0, top: 0, width: size.width, height: size.height, child: _image(context, size)),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: context.motion(const Duration(milliseconds: 160)),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut.flipped,
              layoutBuilder: (current, previous) =>
                  Stack(fit: StackFit.expand, children: <Widget>[...previous, ?current]),
              child: lock
                  ? LockPreviewLayer(key: ValueKey<ClockPreviewMode>(_mode), textColor: textColor)
                  : HomePreviewLayer(key: ValueKey<ClockPreviewMode>(_mode), textColor: textColor),
            ),
          ),
          Semantics(
            button: true,
            label: context.l10n.wallpaperClosePreview,
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
                child: _ModeToggle(mode: _mode, onChanged: (mode) => setState(() => _mode = mode)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lock and Home as a glass pill. The selected segment is marked by a solid light indicator that slides across.
/// Both segments are as wide as the wider label, never under 84, so large text grows the pill instead of clipping.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final ClockPreviewMode mode;
  final ValueChanged<ClockPreviewMode> onChanged;

  static const double _height = 48;
  static const double _minSegmentWidth = 84;
  static const double _inset = 4;
  static const Curve _slide = Cubic(0.23, 1, 0.32, 1);
  static const Duration _slideDuration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final Duration duration = context.motion(_slideDuration);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: PrismGlass(
        borderRadius: _height / 2,
        thickness: 16,
        glassColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.6),
        child: SizedBox(
          height: _height,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double segment = constraints.maxWidth / ClockPreviewMode.values.length;
                    return Stack(
                      children: <Widget>[
                        AnimatedPositionedDirectional(
                          duration: duration,
                          curve: _slide,
                          start: segment * mode.index + _inset,
                          top: _inset,
                          bottom: _inset,
                          width: segment - 2 * _inset,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: PrismColors.onPrimary.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(_height / 2 - _inset),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              IntrinsicWidth(
                child: Row(
                  children: <Widget>[
                    for (final ClockPreviewMode value in ClockPreviewMode.values)
                      Expanded(
                        child: _Segment(
                          label: value.label,
                          selected: value == mode,
                          duration: duration,
                          curve: _slide,
                          onTap: () => onChanged(value),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.duration,
    required this.curve,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Duration duration;
  final Curve curve;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _ModeToggle._minSegmentWidth),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PressScale(
                child: AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: curve,
                  style: PrismTextStyles.rowTitle(
                    context,
                  ).copyWith(color: selected ? Colors.black87 : PrismColors.onPrimary.withValues(alpha: 0.88)),
                  child: Text(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the lock screen preview over the current page.
Future<void> pushClockPreview(
  BuildContext context, {
  required String link,
  required bool file,
  String? wallpaperId,
  WallpaperSource? wallpaperSource,
  String? thumbnailUrl,
  Color? tint,
}) {
  return Navigator.push<void>(
    context,
    PageRouteBuilder<void>(
      transitionDuration: context.motion(PrismDurations.base),
      reverseTransitionDuration: context.motion(PrismDurations.fast),
      pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
        opacity: animation.drive(CurveTween(curve: PrismCurves.enter)),
        child: ClockOverlay(
          link: link,
          file: file,
          wallpaperId: wallpaperId,
          wallpaperSource: wallpaperSource,
          thumbnailUrl: thumbnailUrl,
          tint: tint,
        ),
      ),
      fullscreenDialog: true,
      opaque: false,
    ),
  );
}
