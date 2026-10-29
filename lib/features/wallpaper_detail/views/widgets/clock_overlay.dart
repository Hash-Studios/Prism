import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/features/wallpaper_detail/biz/top_third_text_color.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_scheme.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/spatial_tilt_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

export 'package:Prism/core/platform/wallpaper_service.dart' show WallpaperTarget;

enum ClockPreviewMode { lock, home }

/// Width of the decode used to pick the clock text colour.
const int _sampleWidth = 32;

/// What the Set screen shows and offers. [SetWallpaperFlow] builds it.
class SetScreenRequest {
  const SetScreenRequest({
    required this.url,
    this.thumbnailUrl,
    this.wallpaperId,
    this.wallpaperSource,
    this.tint,
    this.notes = const <String>[],
    this.onAdjust,
  });

  /// The wall to set. A Prism wall previews its display derivative, because its original may need the user's consent.
  final String url;
  final String? thumbnailUrl;
  final String? wallpaperId;
  final WallpaperSource? wallpaperSource;

  /// A colour variation the flow applies after consent. The preview shows it now.
  final Color? tint;

  /// Short warnings about this wall, for example low resolution.
  final List<String> notes;

  /// Opens the position studio. Null hides Adjust and More.
  final Future<StudioResult?> Function(BuildContext context)? onAdjust;
}

/// What the Set screen shows for [request]: a file on the device as is, a Prism wall's display derivative (never its
/// original), and otherwise the wall's own URL, or its thumbnail when there is none.
WallpaperDisplaySource setScreenDisplaySource(SetScreenRequest request) {
  final String thumbnail = request.thumbnailUrl?.trim() ?? '';
  final String url = request.url.trim();
  final bool local = url.startsWith('/') || url.startsWith('file:');
  final bool localThumbnail = thumbnail.startsWith('/') || thumbnail.startsWith('file:');
  final String id = request.wallpaperId ?? '';
  final WallpaperSource? source = request.wallpaperSource;
  if (local && (source == null || source == WallpaperSource.downloaded)) {
    return WallpaperDisplaySource(thumbnail: '', full: url);
  }
  if (url.isEmpty && localThumbnail && source == WallpaperSource.downloaded) {
    return WallpaperDisplaySource(thumbnail: '', full: thumbnail);
  }
  if (source == WallpaperSource.prism) {
    return WallpaperDisplaySource.forWall(id: id, source: WallpaperSource.prism, thumbnail: thumbnail, fullUrl: url);
  }
  final String full = isValidNetworkUrl(url) ? url : '';
  final String safeThumbnail = isValidNetworkUrl(thumbnail) ? thumbnail : '';
  return WallpaperDisplaySource(thumbnail: safeThumbnail, full: full);
}

/// Opens the Set screen over the current page. Returns what the user picked, or null when they closed it.
Future<SetWallpaperChoice?> showSetScreen(BuildContext context, SetScreenRequest request) {
  final WallpaperDisplaySource display = setScreenDisplaySource(request);
  final String link = display.bestLink;
  final SetScreenRequest safeRequest = SetScreenRequest(
    url: link,
    thumbnailUrl: display.thumbnail,
    wallpaperId: request.wallpaperId,
    wallpaperSource: request.wallpaperSource,
    tint: request.tint,
    notes: request.notes,
    onAdjust: request.onAdjust,
  );
  return Navigator.of(context, rootNavigator: true).push<SetWallpaperChoice>(
    _previewRoute<SetWallpaperChoice>(
      context,
      ClockOverlay(
        link: link,
        file: link.startsWith('/') || link.startsWith('file:'),
        wallpaperId: request.wallpaperId,
        wallpaperSource: request.wallpaperSource,
        thumbnailUrl: display.thumbnail,
        tint: request.tint,
        request: safeRequest,
      ),
    ),
  );
}

/// The Set screen: the wall full-bleed on a mock lock screen or home screen, where to set it, and one Set button.
///
/// With a [request] the screen belongs to [SetWallpaperFlow]: Set pops a [SetWallpaperChoice]. Without one it is a
/// preview, and a local [file] can still be set from here. On iOS, where apps cannot set a wallpaper, [saveAction]
/// builds Save to Photos instead.
/// The clock text is black or white, whichever reads on the top third. A tap hides the controls, so the whole mock
/// shows.
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
    this.saveAction,
    this.request,
    this.spatialMapUrl,
  });

  final String link;
  final bool file;
  final String? wallpaperId;
  final WallpaperSource? wallpaperSource;

  /// Shown while the full image loads.
  final String? thumbnailUrl;

  /// The colour variation the user picked. When set, the image is shown with this hue.
  final Color? tint;

  /// iOS only: builds Save to Photos with [label].
  final Widget Function(String label)? saveAction;

  /// Makes this the flow's Set screen.
  final SetScreenRequest? request;

  /// The wall's depth map. When set, a 3D toggle shows the wall with a tilt parallax.
  final String? spatialMapUrl;

  @override
  State<ClockOverlay> createState() => _ClockOverlayState();
}

class _ClockOverlayState extends State<ClockOverlay> {
  late WallpaperTarget _target = _initialTarget;
  late final WallpaperTarget _initialTarget = widget.request == null
      ? WallpaperTarget.home
      : SetWallpaperFlow.defaultTarget() ?? SetWallpaperFlow.lastTarget() ?? WallpaperTarget.home;
  late ClockPreviewMode _mode = hideSetWallpaperUi || _target == WallpaperTarget.lock
      ? ClockPreviewMode.lock
      : ClockPreviewMode.home;
  Color? _textColor;
  ColorScheme? _scheme;
  bool _schemeRead = false;
  PreviewIconStyle _iconStyle = _savedIconStyle();
  bool _controls = true;
  bool _spatial = false;

  /// Unknown capabilities count as supported, so the targets do not jump in once they load.
  aw.WallpaperCapabilities? _capabilities;
  late bool _remember = widget.request != null && SetWallpaperFlow.defaultTarget() != null;
  bool _busy = false;
  bool _completed = false;

  /// The wall as placed in the studio. The screen deletes it unless it hands it to the flow.
  PlacedWallpaper? _placed;
  bool _placedHandedOff = false;
  int _inputGeneration = 0;
  int _adjustGeneration = 0;
  ImageStream? _sampleStream;
  ImageStreamListener? _sampleListener;
  Future<File?>? _localFileFuture;
  File? _localFile;

  String get _link => _placed?.path ?? widget.link;
  bool get _file => _placed != null || (widget.file && _isLocalFileLink(_link));

  bool _isLocalFileLink(String link) {
    final Uri? uri = Uri.tryParse(link);
    return uri?.scheme == 'file' || uri?.scheme.isEmpty == true;
  }

  WallpaperDisplaySource get _displaySource {
    final String thumbnail = widget.thumbnailUrl?.trim() ?? '';
    if (_file) {
      return WallpaperDisplaySource(thumbnail: '', full: _link);
    }
    if (widget.wallpaperSource == WallpaperSource.prism) {
      return WallpaperDisplaySource.forWall(
        id: widget.wallpaperId ?? '',
        source: WallpaperSource.prism,
        thumbnail: thumbnail,
      );
    }
    if (isValidNetworkUrl(_link)) {
      return WallpaperDisplaySource(
        thumbnail: thumbnail,
        full: _link,
        id: widget.wallpaperId,
        source: widget.wallpaperSource,
      );
    }
    if (_link.startsWith('assets/')) return WallpaperDisplaySource(thumbnail: '', full: _link);
    return const WallpaperDisplaySource(thumbnail: '', full: '');
  }

  /// A placed wall was rendered from the tinted source, so it already has the hue.
  Color? get _tint => _placed == null ? widget.tint : null;

  ImageProvider? get _provider {
    if (_localFile != null) return FileImage(_localFile!);
    final String link = _displaySource.bestLink;
    if (link.isEmpty) return null;
    if (link.startsWith('assets/')) return AssetImage(link);
    if (isValidNetworkUrl(link)) return CachedNetworkImageProvider(link, cacheManager: _cache);
    final Uri? uri = Uri.tryParse(link);
    return FileImage(File(uri?.scheme == 'file' ? uri!.toFilePath() : link));
  }

  BaseCacheManager get _cache => PrismFullImageCache.instance;

  bool _supported(WallpaperTarget target) {
    final aw.WallpaperCapabilities? capabilities = _capabilities;
    return capabilities == null || isWallpaperTargetSupported(capabilities, target);
  }

  List<WallpaperTarget> get _targets => <WallpaperTarget>[
    if (_supported(WallpaperTarget.home)) WallpaperTarget.home,
    if (_supported(WallpaperTarget.lock)) WallpaperTarget.lock,
    if (_supported(WallpaperTarget.both)) WallpaperTarget.both,
  ];

  bool get _canAdjust => widget.request?.onAdjust != null;

  bool get _canPair =>
      _canAdjust && _capabilities != null && _supported(WallpaperTarget.home) && _supported(WallpaperTarget.lock);

  @override
  void initState() {
    super.initState();
    _localFileFuture = _resolveLocalFile();
    unawaited(_sampleText());
    _readSchemeOnce();
    if (!hideSetWallpaperUi) unawaited(_readCapabilities());
  }

  Future<void> _readCapabilities() async {
    try {
      final aw.WallpaperCapabilities capabilities = await aw.AsyncWallpaper.getCapabilities();
      if (!mounted) return;
      setState(() {
        _capabilities = capabilities;
        if (!_targets.contains(_target)) {
          _target = _targets.firstOrNull ?? WallpaperTarget.home;
          _mode = _target == WallpaperTarget.lock ? ClockPreviewMode.lock : ClockPreviewMode.home;
        }
      });
      _readSchemeOnce();
    } catch (error, stackTrace) {
      logger.w('ClockOverlay: could not read capabilities', error: error, stackTrace: stackTrace);
    }
  }

  @override
  void didUpdateWidget(ClockOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link == widget.link &&
        oldWidget.file == widget.file &&
        oldWidget.wallpaperId == widget.wallpaperId &&
        oldWidget.wallpaperSource == widget.wallpaperSource &&
        oldWidget.thumbnailUrl == widget.thumbnailUrl &&
        oldWidget.tint == widget.tint) {
      return;
    }
    _adjustGeneration++;
    final PlacedWallpaper? placed = _placed;
    _placed = null;
    if (placed != null) unawaited(placed.discard());
    _reloadImage();
  }

  void _reloadImage() {
    _inputGeneration++;
    _stopSampling();
    _localFile = null;
    _localFileFuture = _resolveLocalFile();
    _textColor = null;
    _scheme = null;
    _schemeRead = false;
    unawaited(_sampleText());
    _readSchemeOnce();
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
    unawaited(_saveIconStyle(style));
  }

  Future<void> _saveIconStyle(PreviewIconStyle style) async {
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return;
      await getIt<SettingsLocalDataSource>().set(PersistenceKeys.previewIconStyle, style.name);
    } catch (error, stackTrace) {
      logger.w('ClockOverlay: could not save the icon style', error: error, stackTrace: stackTrace);
    }
  }

  /// Reads the wallpaper colours the first time a style needs them.
  void _readSchemeOnce() {
    if (_mode != ClockPreviewMode.home ||
        _schemeRead ||
        (_iconStyle != PreviewIconStyle.tinted && _iconStyle != PreviewIconStyle.themed)) {
      return;
    }
    _schemeRead = true;
    unawaited(_readScheme());
  }

  Future<void> _readScheme() async {
    final int generation = _inputGeneration;
    final File? local = await _localFileFuture;
    if (generation != _inputGeneration) return;
    _localFile ??= local;
    if (!mounted) return;
    final Color? tint = _tint;
    final ImageProvider? provider = _provider;
    if (tint == null && provider == null) return;
    final ColorScheme? scheme = tint != null
        ? ColorScheme.fromSeed(seedColor: tint, brightness: Brightness.dark)
        : await wallpaperScheme(provider!);
    if (generation != _inputGeneration) return;
    if (mounted) setState(() => _scheme = scheme);
  }

  Future<File?> _resolveLocalFile() async {
    if (_file) {
      final Uri? uri = Uri.tryParse(_link);
      return File(uri?.scheme == 'file' ? uri!.toFilePath() : _link);
    }
    if (_link.startsWith('assets/')) return null;
    if (widget.wallpaperSource == WallpaperSource.prism) {
      return wallpaperOfflineCopy(_displaySource);
    }
    if (!isValidNetworkUrl(_link)) return null;
    try {
      return await WallpaperService.resolveToLocalFile(
        _link,
        allowNetwork: false,
        wallpaperId: widget.wallpaperId,
        wallpaperSource: widget.wallpaperSource,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _sampleText() async {
    final int generation = _inputGeneration;
    final File? localFile = await _localFileFuture;
    if (generation != _inputGeneration) return;
    _localFile = localFile;
    if (!mounted) return;
    final ImageProvider? provider = _provider;
    if (provider == null) return;
    final ImageStream stream = ResizeImage(provider, width: _sampleWidth).resolve(ImageConfiguration.empty);
    final ImageStreamListener listener = ImageStreamListener(
      (info, _) {
        unawaited(_applySample(info.image, generation));
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

  Future<void> _applySample(ui.Image image, int generation) async {
    try {
      final Color color = await textColorForTopThird(image, tint: _tint);
      if (mounted && generation == _inputGeneration) setState(() => _textColor = color);
    } finally {
      image.dispose();
    }
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
    final PlacedWallpaper? placed = _placed;
    if (!_placedHandedOff && placed != null) unawaited(placed.discard());
    super.dispose();
  }

  Widget _tinted(Widget image) {
    final Color? tint = _tint;
    if (tint == null) return image;
    return ColorFiltered(colorFilter: ColorFilter.mode(tint, BlendMode.hue), child: image);
  }

  Widget _image(BuildContext context, Size size) {
    final Color placeholder = Theme.of(context).primaryColor;
    final WallpaperDisplaySource display = _displaySource;
    return ColoredBox(
      color: placeholder,
      child: _tinted(
        ProgressiveWallpaperImage(
          display: display,
          decodeBox: size,
          errorBuilder: (_, _) =>
              Center(child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.secondary)),
        ),
      ),
    );
  }

  void _pickTarget(WallpaperTarget target) {
    setState(() {
      _target = target;
      if (target == WallpaperTarget.home) _mode = ClockPreviewMode.home;
      if (target == WallpaperTarget.lock) _mode = ClockPreviewMode.lock;
    });
    _readSchemeOnce();
  }

  void _pickMode(ClockPreviewMode mode) {
    setState(() => _mode = mode);
    _readSchemeOnce();
  }

  bool get _targetChanged => _target != _initialTarget;

  /// Hands [choice] to the flow. A remembered choice becomes the saved default, and clearing the check forgets it.
  void _choose(SetWallpaperChoice choice) {
    if (_completed) return;
    _completed = true;
    if (choice.kind == SetChoiceKind.apply) {
      SetWallpaperFlow.saveDefaultTarget(_remember ? choice.target : null);
      SetWallpaperFlow.saveLastTarget(choice.target);
    }
    _placedHandedOff = choice.placed != null;
    Navigator.of(context).pop<SetWallpaperChoice>(choice);
  }

  void _close() {
    if (_completed) return;
    _completed = true;
    _adjustGeneration++;
    Navigator.of(context).pop();
  }

  void _handlePop(bool didPop) {
    if (!didPop || _completed) return;
    _completed = true;
    _adjustGeneration++;
  }

  void _set() => _choose(SetWallpaperChoice(_target, placed: _placed, targetChanged: _targetChanged));

  Future<void> _adjust() async {
    final Future<StudioResult?> Function(BuildContext context)? onAdjust = widget.request?.onAdjust;
    if (onAdjust == null || _busy) return;
    final int generation = _adjustGeneration;
    setState(() => _busy = true);
    final AppLocalizations l10n = context.l10n;
    StudioResult? result;
    try {
      result = await onAdjust(context);
    } catch (error, stackTrace) {
      logger.e('ClockOverlay: Adjust failed', error: error, stackTrace: stackTrace);
      toasts.error(l10n.coreWallpaperSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) {
      if (result is PlacedWallpaper) unawaited(result.discard());
      return;
    }
    if (_completed || generation != _adjustGeneration) {
      if (result is PlacedWallpaper) unawaited(result.discard());
      return;
    }
    switch (result) {
      case final PlacedWallpaper placed:
        final PlacedWallpaper? previous = _placed;
        setState(() => _placed = placed);
        if (previous != null) unawaited(previous.discard());
        _reloadImage();
      case SystemEditorRequested():
        _choose(SetWallpaperChoice(_target, useSystemCropper: true, targetChanged: _targetChanged));
      case null:
        break;
    }
  }

  /// Sets a local file from the plain preview, where no flow waits for a choice.
  Future<void> _setHere() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SetWallpaperFlow.run(
        context,
        url: widget.link,
        wallpaperId: widget.wallpaperId,
        wallpaperSource: WallpaperSource.downloaded,
        thumbnailUrl: widget.thumbnailUrl,
        target: _target,
        entryPoint: 'wallpaper_preview',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _setLabel(AppLocalizations l10n) => switch (_target) {
    WallpaperTarget.lock => l10n.wallpaperPreviewSetLock,
    WallpaperTarget.home => l10n.wallpaperPreviewSetHome,
    WallpaperTarget.both => l10n.wallpaperPreviewSetBoth,
  };

  /// The one filled button: Set on the chosen screen, or Save to Photos on iOS. Null when nothing can be set here.
  Widget? _primary(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (hideSetWallpaperUi) return widget.saveAction?.call(l10n.wallpaperSaveToPhotos);
    final VoidCallback? onSet = widget.request != null
        ? _set
        : widget.file
        ? _setHere
        : null;
    if (onSet == null) return null;
    return PrismButton(
      key: const ValueKey<String>('set-screen-set'),
      label: _setLabel(l10n),
      loading: _busy && widget.request == null,
      onPressed: _busy || _completed || ((widget.request != null || widget.file) && !_supported(_target))
          ? null
          : onSet,
      expand: true,
    );
  }

  Widget _choices(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (hideSetWallpaperUi) {
      return PrismSegmented<ClockPreviewMode>(
        values: ClockPreviewMode.values,
        selected: _mode,
        labelOf: (mode) => switch (mode) {
          ClockPreviewMode.lock => l10n.wallpaperPreviewLock,
          ClockPreviewMode.home => l10n.wallpaperPreviewHome,
        },
        onChanged: _pickMode,
      );
    }
    final List<WallpaperTarget> targets = _targets;
    if (targets.length < 2) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: l10n.setScreenTargetGroup,
      child: PrismSegmented<WallpaperTarget>(
        values: targets,
        selected: _target,
        labelOf: (target) => switch (target) {
          WallpaperTarget.home => l10n.setScreenTargetHome,
          WallpaperTarget.lock => l10n.setScreenTargetLock,
          WallpaperTarget.both => l10n.setScreenTargetBoth,
        },
        onChanged: _pickTarget,
      ),
    );
  }

  void _trackSpatial(SpatialTiltMode mode) =>
      analytics.track(SpatialPreviewOpenedEvent(wallId: widget.wallpaperId ?? '', tilt: mode.name));

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final ThemeData theme = Theme.of(context);
    final Color textColor = _textColor ?? theme.colorScheme.secondary;
    final bool lock = _mode == ClockPreviewMode.lock;
    final AppLocalizations l10n = context.l10n;
    final Duration fade = context.motion(PrismDurations.fast);
    final List<PreviewIconStyle> styles = PreviewIconStyle.forPlatform(defaultTargetPlatform);
    final Widget? primary = _primary(context);
    final List<String> notes = widget.request?.notes ?? const <String>[];
    final Widget layers = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        AnimatedSwitcher(
          duration: fade,
          switchInCurve: PrismCurves.enter,
          switchOutCurve: PrismCurves.enter.flipped,
          layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: <Widget>[...previous, ?current]),
          child: lock
              ? LockPreviewLayer(key: ValueKey<ClockPreviewMode>(_mode), textColor: textColor)
              : HomePreviewLayer(
                  key: ValueKey<ClockPreviewMode>(_mode),
                  textColor: textColor,
                  iconStyle: _iconStyle,
                  scheme: _scheme,
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
      ],
    );
    // A Scaffold, so the set result and its Undo show over the preview and not under it.
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              top: 0,
              width: size.width,
              height: size.height,
              child: _spatial && widget.spatialMapUrl != null && _provider != null
                  ? SpatialTiltView(
                      image: sizedWallpaperImage(_provider!, size, MediaQuery.devicePixelRatioOf(context), null),
                      mapUrl: widget.spatialMapUrl!,
                      tint: widget.tint,
                      onMode: _trackSpatial,
                      child: layers,
                    )
                  : Stack(fit: StackFit.expand, children: <Widget>[_image(context, size), layers]),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_controls,
                child: AnimatedOpacity(
                  opacity: _controls ? 1 : 0,
                  duration: fade,
                  curve: PrismCurves.enter,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(PrismSpace.sm, 0, PrismSpace.sm, PrismSpace.xs),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            AnimatedSwitcher(
                              duration: fade,
                              child: lock || styles.length < 2
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(bottom: PrismSpace.xs),
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
                            _EnterFromBelow(
                              child: _ControlCard(
                                children: <Widget>[
                                  if (notes.isNotEmpty) ...<Widget>[
                                    _NoteChips(notes: notes),
                                    const SizedBox(height: PrismSpace.sm),
                                  ],
                                  _choices(context),
                                  const SizedBox(height: PrismSpace.sm),
                                  Row(
                                    children: <Widget>[
                                      PrismIconButton(
                                        icon: Icons.close_rounded,
                                        tooltip: widget.request == null
                                            ? l10n.wallpaperClosePreview
                                            : l10n.setScreenClose,
                                        filled: true,
                                        size: 48,
                                        onPressed: _close,
                                      ),
                                      if (widget.spatialMapUrl != null) ...<Widget>[
                                        const SizedBox(width: PrismSpace.xs),
                                        _SpatialToggle(on: _spatial, onChanged: (on) => setState(() => _spatial = on)),
                                      ],
                                      if (primary != null) ...<Widget>[
                                        const SizedBox(width: PrismSpace.xs),
                                        Expanded(child: Center(child: primary)),
                                      ],
                                    ],
                                  ),
                                  if (widget.request != null && !hideSetWallpaperUi) ...<Widget>[
                                    const SizedBox(height: PrismSpace.xxs),
                                    _RememberCheck(
                                      value: _remember,
                                      onChanged: (value) => setState(() => _remember = value),
                                    ),
                                    if (_canAdjust)
                                      _QuietActions(
                                        busy: _busy,
                                        onAdjust: _adjust,
                                        onPair: _canPair
                                            ? () => _choose(SetWallpaperChoice.pair(targetChanged: _targetChanged))
                                            : null,
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The controls on one card in the theme's surface colour, so they read on any wall and follow the theme.
class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PrismGlass(
      borderRadius: PrismRadius.xl,
      thickness: 16,
      glassColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
      child: Padding(
        padding: const EdgeInsets.all(PrismSpace.sm),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Turns the tilt parallax on and off. As tall as the close button next to it.
class _SpatialToggle extends StatelessWidget {
  const _SpatialToggle({required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String tooltip = on ? context.l10n.wallpaperSpatialPreviewOff : context.l10n.wallpaperSpatialPreviewOn;
    final Color foreground = on ? scheme.onPrimary : scheme.onSurface;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: on,
        excludeSemantics: true,
        label: tooltip,
        onTap: () => onChanged(!on),
        child: PressScale(
          child: TextButton.icon(
            onPressed: () => onChanged(!on),
            style: TextButton.styleFrom(
              foregroundColor: foreground,
              backgroundColor: on ? scheme.primary : scheme.onSurface.withValues(alpha: 0.08),
              minimumSize: const Size(48, 48),
              fixedSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
              textStyle: PrismTextStyles.button,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.view_in_ar_rounded, size: 20),
            label: Text(context.l10n.wallpaperSpatialPreviewLabel),
          ),
        ),
      ),
    );
  }
}

/// Slides the controls up 16 px and fades them in once, when the screen opens.
class _EnterFromBelow extends StatelessWidget {
  const _EnterFromBelow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: context.motion(PrismDurations.base),
      curve: PrismCurves.enter,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - value)), child: child),
      ),
      child: child,
    );
  }
}

/// "Remember this choice": the check and its label are one 48 dp target.
class _RememberCheck extends StatelessWidget {
  const _RememberCheck({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MergeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.circular(PrismRadius.pill),
            onTap: () => onChanged(!value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Checkbox(
                    value: value,
                    onChanged: (checked) => onChanged(checked ?? false),
                    activeColor: scheme.primary,
                    checkColor: scheme.onPrimary,
                    side: BorderSide(color: scheme.onSurfaceVariant, width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  Flexible(
                    child: Text(
                      l10n.setScreenRemember,
                      style: PrismTextStyles.rowTitle(context).copyWith(color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: context.motion(PrismDurations.fast),
          switchInCurve: PrismCurves.enter,
          switchOutCurve: PrismCurves.enter.flipped,
          child: value
              ? Padding(
                  key: const ValueKey<bool>(true),
                  padding: const EdgeInsets.only(bottom: PrismSpace.xxs),
                  child: Text(
                    l10n.setScreenRememberHint,
                    textAlign: TextAlign.center,
                    style: PrismTextStyles.caption(context),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey<bool>(false)),
        ),
      ],
    );
  }
}

/// The quiet second row: Adjust, and More with the lock screen pair.
class _QuietActions extends StatelessWidget {
  const _QuietActions({required this.busy, required this.onAdjust, required this.onPair});

  final bool busy;
  final VoidCallback onAdjust;

  /// Null hides More, because it holds nothing else.
  final VoidCallback? onPair;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final VoidCallback? pair = onPair;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: PrismSpace.sm,
      children: <Widget>[
        _QuietButton(
          key: const ValueKey<String>('set-screen-adjust'),
          icon: Icons.tune_rounded,
          label: l10n.setScreenAdjust,
          loading: busy,
          onPressed: busy ? null : onAdjust,
        ),
        if (pair != null)
          PopupMenuButton<VoidCallback>(
            key: const ValueKey<String>('set-screen-more'),
            tooltip: l10n.setScreenMore,
            enabled: !busy,
            position: PopupMenuPosition.over,
            onSelected: (action) => action(),
            itemBuilder: (context) => <PopupMenuEntry<VoidCallback>>[
              PopupMenuItem<VoidCallback>(
                value: pair,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.wallpaper_rounded, size: 20),
                    const SizedBox(width: PrismSpace.sm),
                    Flexible(child: Text(l10n.setScreenPairLock)),
                  ],
                ),
              ),
            ],
            child: IgnorePointer(
              child: _QuietButton(
                icon: Icons.more_horiz_rounded,
                label: l10n.setScreenMore,
                onPressed: busy ? null : () {},
              ),
            ),
          ),
      ],
    );
  }
}

/// A text button with an icon, in the theme's text colour, at least 48 dp high.
class _QuietButton extends StatelessWidget {
  const _QuietButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
        textStyle: PrismTextStyles.button,
        shape: const StadiumBorder(),
      ),
      icon: loading
          ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onSurface))
          : Icon(icon, size: 20),
      label: Text(label),
    );
  }
}

/// Warnings about the wall, such as a low resolution.
class _NoteChips extends StatelessWidget {
  const _NoteChips({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: PrismSpace.xs,
      runSpacing: PrismSpace.xxs,
      children: <Widget>[
        for (final String note in notes)
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(PrismRadius.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.warning_amber_rounded, size: 16, color: PrismColors.warning),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(note, style: PrismTextStyles.caption(context).copyWith(color: scheme.onSurface)),
                  ),
                ],
              ),
            ),
          ),
      ],
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
    const double height = 48;
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
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final Widget constrainedPill = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: screenWidth > 32 ? screenWidth - 32 : double.infinity),
      child: pill,
    );
    if (groupLabel == null) return constrainedPill;
    return Semantics(container: true, label: groupLabel, child: constrainedPill);
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
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, softWrap: false)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Route<T> _previewRoute<T>(BuildContext context, Widget screen) => PageRouteBuilder<T>(
  transitionDuration: context.motion(PrismDurations.base),
  reverseTransitionDuration: context.motion(PrismDurations.fast),
  pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
    opacity: animation.drive(CurveTween(curve: PrismCurves.enter)),
    child: screen,
  ),
  fullscreenDialog: true,
  opaque: false,
);

/// Opens the phone preview over the current page, without the set flow. iOS passes [saveAction].
Future<void> pushClockPreview(
  BuildContext context, {
  required String link,
  required bool file,
  String? wallpaperId,
  WallpaperSource? wallpaperSource,
  String? thumbnailUrl,
  Color? tint,
  Widget Function(String label)? saveAction,
  String? spatialMapUrl,
}) {
  return Navigator.push<void>(
    context,
    _previewRoute<void>(
      context,
      ClockOverlay(
        link: link,
        file: file,
        wallpaperId: wallpaperId,
        wallpaperSource: wallpaperSource,
        thumbnailUrl: thumbnailUrl,
        tint: tint,
        saveAction: saveAction,
        spatialMapUrl: spatialMapUrl,
      ),
    ),
  );
}
