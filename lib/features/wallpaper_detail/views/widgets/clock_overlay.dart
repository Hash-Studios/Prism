import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/features/wallpaper_detail/biz/top_third_text_color.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_scheme.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

enum ClockPreviewMode { lock, home }

/// Width of the decode used to pick the clock text colour.
const int _sampleWidth = 32;

/// Full-screen preview of the wallpaper on a mock lock screen or home screen, with a button to set it.
/// The image is shown as it will be set. The clock text is black or white, whichever reads on the top third.
/// A tap hides the controls, so the whole mock shows.
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
    this.setAction,
  });

  final String link;
  final bool file;
  final String? wallpaperId;
  final WallpaperSource? wallpaperSource;

  /// Shown while the full image loads.
  final String? thumbnailUrl;

  /// The colour variation the user picked. When set, the image is shown with this hue.
  final Color? tint;

  /// Builds the main button for [target] with [label]. On iOS the target is ignored and the label says Save to Photos.
  /// Null sets a local [link] file with a plain set button on Android. Otherwise there is no button.
  final Widget Function(WallpaperTarget target, String label)? setAction;

  @override
  State<ClockOverlay> createState() => _ClockOverlayState();
}

class _ClockOverlayState extends State<ClockOverlay> {
  late ClockPreviewMode _mode = defaultTargetPlatform == TargetPlatform.iOS
      ? ClockPreviewMode.lock
      : ClockPreviewMode.home;
  Color? _textColor;
  ColorScheme? _scheme;
  bool _schemeRead = false;
  PreviewIconStyle _iconStyle = _savedIconStyle();
  bool _controls = true;
  bool _both = false;
  bool _canSetBoth = false;
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
    _readSchemeOnce();
    if (!hideSetWallpaperUi) {
      unawaited(
        SetWallpaperFlow.supportsTarget(WallpaperTarget.both).then((supported) {
          if (mounted) setState(() => _canSetBoth = supported);
        }),
      );
    }
  }

  static PreviewIconStyle _savedIconStyle() {
    final List<PreviewIconStyle> offered = PreviewIconStyle.forPlatform(defaultTargetPlatform);
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return offered.first;
      final String saved = getIt<SettingsLocalDataSource>().get<String>(
        PersistenceKeys.previewIconStyle,
        defaultValue: '',
      );
      return offered.firstWhere((style) => style.name == saved, orElse: () => offered.first);
    } catch (error) {
      logger.w('ClockOverlay: could not read the icon style', error: error);
      return offered.first;
    }
  }

  void _pickIconStyle(PreviewIconStyle style) {
    setState(() => _iconStyle = style);
    _readSchemeOnce();
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return;
      unawaited(getIt<SettingsLocalDataSource>().set(PersistenceKeys.previewIconStyle, style.name));
    } catch (error) {
      logger.w('ClockOverlay: could not save the icon style', error: error);
    }
  }

  /// Reads the wallpaper colours the first time a style needs them.
  void _readSchemeOnce() {
    if (_schemeRead || (_iconStyle != PreviewIconStyle.tinted && _iconStyle != PreviewIconStyle.themed)) return;
    _schemeRead = true;
    unawaited(_readScheme());
  }

  Future<void> _readScheme() async {
    final File? local = await _localFileFuture;
    _localFile ??= local;
    if (!mounted) return;
    final Color? tint = widget.tint;
    final ColorScheme? scheme = tint != null
        ? ColorScheme.fromSeed(seedColor: tint, brightness: Brightness.dark)
        : await wallpaperScheme(_provider);
    if (mounted) setState(() => _scheme = scheme);
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

  WallpaperTarget get _target => _both
      ? WallpaperTarget.both
      : _mode == ClockPreviewMode.lock
      ? WallpaperTarget.lock
      : WallpaperTarget.home;

  Widget? _action(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (hideSetWallpaperUi) return widget.setAction?.call(WallpaperTarget.both, l10n.wallpaperSaveToPhotos);
    final WallpaperTarget target = _target;
    final String label = switch (target) {
      WallpaperTarget.lock => l10n.wallpaperPreviewSetLock,
      WallpaperTarget.home => l10n.wallpaperPreviewSetHome,
      WallpaperTarget.both => l10n.wallpaperPreviewSetBoth,
    };
    final setAction = widget.setAction;
    if (setAction != null) return setAction(target, label);
    // A linked Prism wall previews its thumbnail, so only a local file is safe to set from here.
    if (!widget.file) return null;
    return SetWallpaperButton(
      url: widget.link,
      wallpaperId: widget.wallpaperId,
      wallpaperSource: WallpaperSource.downloaded,
      thumbnailUrl: widget.thumbnailUrl,
      entryPoint: 'wallpaper_preview',
      target: target,
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final Color textColor = _textColor ?? Theme.of(context).colorScheme.secondary;
    final bool lock = _mode == ClockPreviewMode.lock;
    final AppLocalizations l10n = context.l10n;
    final Duration fade = context.motion(const Duration(milliseconds: 160));
    final List<PreviewIconStyle> styles = PreviewIconStyle.forPlatform(defaultTargetPlatform);
    final Widget? action = _action(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: <Widget>[
          Positioned(left: 0, top: 0, width: size.width, height: size.height, child: _image(context, size)),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: fade,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut.flipped,
              layoutBuilder: (current, previous) =>
                  Stack(fit: StackFit.expand, children: <Widget>[...previous, ?current]),
              child: lock
                  ? LockPreviewLayer(key: ValueKey<ClockPreviewMode>(_mode), textColor: textColor)
                  : HomePreviewLayer(
                      key: ValueKey<ClockPreviewMode>(_mode),
                      textColor: textColor,
                      iconStyle: _iconStyle,
                      scheme: _scheme,
                    ),
            ),
          ),
          Semantics(
            button: true,
            label: _controls ? l10n.wallpaperHidePreviewControls : l10n.wallpaperShowPreviewControls,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _controls = !_controls),
              child: SizedBox(height: size.height, width: size.width),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_controls,
              child: AnimatedOpacity(
                opacity: _controls ? 1 : 0,
                duration: fade,
                curve: Curves.easeOut,
                child: SafeArea(
                  child: Stack(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              AnimatedSwitcher(
                                duration: fade,
                                child: lock || styles.length < 2
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _GlassSegments<PreviewIconStyle>(
                                          values: styles,
                                          selected: _iconStyle,
                                          label: (style) => switch (style) {
                                            PreviewIconStyle.standard => l10n.wallpaperPreviewIconDefault,
                                            PreviewIconStyle.dark => l10n.wallpaperPreviewIconDark,
                                            PreviewIconStyle.clear => l10n.wallpaperPreviewIconClear,
                                            PreviewIconStyle.tinted => l10n.wallpaperPreviewIconTinted,
                                            PreviewIconStyle.themed => l10n.wallpaperPreviewIconThemed,
                                          },
                                          groupLabel: l10n.wallpaperPreviewIconStyle,
                                          onChanged: _pickIconStyle,
                                          compact: true,
                                        ),
                                      ),
                              ),
                              _GlassSegments<ClockPreviewMode>(
                                values: ClockPreviewMode.values,
                                selected: _mode,
                                label: (mode) => switch (mode) {
                                  ClockPreviewMode.lock => l10n.wallpaperPreviewLock,
                                  ClockPreviewMode.home => l10n.wallpaperPreviewHome,
                                },
                                onChanged: (mode) => setState(() => _mode = mode),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  PrismIconButton(
                                    icon: Icons.close_rounded,
                                    tooltip: l10n.wallpaperClosePreview,
                                    onImage: true,
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  if (action != null) ...<Widget>[
                                    const SizedBox(width: 8),
                                    action,
                                    if (_canSetBoth) ...<Widget>[
                                      const SizedBox(width: 8),
                                      _BothToggle(selected: _both, onChanged: (both) => setState(() => _both = both)),
                                    ],
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Choices as a glass pill. The selected segment is marked by a solid light indicator that slides across.
/// Every segment is as wide as the widest label, never under the minimum, so large text grows the pill.
class _GlassSegments<T> extends StatelessWidget {
  const _GlassSegments({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.groupLabel,
    this.compact = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  /// Read by screen readers before the choices.
  final String? groupLabel;

  /// A smaller, quieter pill for a secondary choice.
  final bool compact;

  static const double _inset = 4;
  static const Curve _slide = Cubic(0.23, 1, 0.32, 1);
  static const Duration _slideDuration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final Duration duration = context.motion(_slideDuration);
    final double height = compact ? 36 : 48;
    final int index = values.indexOf(selected);
    final Widget pill = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: PrismGlass(
        borderRadius: height / 2,
        thickness: 16,
        glassColor: Theme.of(context).colorScheme.scrim.withValues(alpha: compact ? 0.45 : 0.6),
        child: SizedBox(
          height: height,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double segment = constraints.maxWidth / values.length;
                    return Stack(
                      children: <Widget>[
                        AnimatedPositionedDirectional(
                          duration: duration,
                          curve: _slide,
                          start: segment * index + _inset,
                          top: _inset,
                          bottom: _inset,
                          width: segment - 2 * _inset,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: PrismColors.onPrimary.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(height / 2 - _inset),
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
                    for (final T value in values)
                      Expanded(
                        child: _Segment(
                          label: label(value),
                          selected: value == selected,
                          duration: duration,
                          curve: _slide,
                          minWidth: compact ? 64 : 84,
                          style: compact ? PrismTextStyles.caption(context) : PrismTextStyles.rowTitle(context),
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
    if (groupLabel == null) return pill;
    return Semantics(container: true, label: groupLabel, child: pill);
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.duration,
    required this.curve,
    required this.minWidth,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Duration duration;
  final Curve curve;
  final double minWidth;
  final TextStyle style;
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
          constraints: BoxConstraints(minWidth: minWidth),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: PressScale(
                child: AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: curve,
                  style: style.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.black87 : PrismColors.onPrimary.withValues(alpha: 0.88),
                  ),
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

/// Adds the other screen to the set button: Lock or Home becomes Both.
class _BothToggle extends StatelessWidget {
  const _BothToggle({required this.selected, required this.onChanged});

  final bool selected;
  final ValueChanged<bool> onChanged;

  static const double _height = 40;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? Colors.black87 : PrismColors.onPrimary;
    return Semantics(
      button: true,
      toggled: selected,
      excludeSemantics: true,
      label: context.l10n.wallpaperPreviewSetBoth,
      onTap: () => onChanged(!selected),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!selected),
        child: PressScale(
          child: PrismGlass(
            borderRadius: _height / 2,
            thickness: 16,
            glassColor: selected
                ? PrismColors.onPrimary.withValues(alpha: 0.92)
                : Theme.of(context).colorScheme.scrim.withValues(alpha: 0.6),
            child: SizedBox(
              height: _height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.layers_rounded, size: 18, color: foreground),
                    const SizedBox(width: 6),
                    Text(context.l10n.coreBoth, style: PrismTextStyles.rowTitle(context).copyWith(color: foreground)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the phone preview over the current page.
Future<void> pushClockPreview(
  BuildContext context, {
  required String link,
  required bool file,
  String? wallpaperId,
  WallpaperSource? wallpaperSource,
  String? thumbnailUrl,
  Color? tint,
  Widget Function(WallpaperTarget target, String label)? setAction,
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
          setAction: setAction,
        ),
      ),
      fullscreenDialog: true,
      opaque: false,
    ),
  );
}
