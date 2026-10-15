import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min;
import 'dart:ui' show lerpDouble;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/biz/similar_wallpapers_loader.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_panel.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_wallpaper_image.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

@RoutePage()
class WallpaperDetailScreen extends StatefulWidget implements AutoRouteWrapper {
  const WallpaperDetailScreen({
    super.key,
    this.entity,
    this.wallId,
    this.source,
    this.thumbnailUrl,
    this.analyticsSurface = AnalyticsSurfaceValue.wallpaperScreen,
    this.heroTag,
    this.localFile,
  }) : assert(entity != null || (wallId != null && source != null), 'Either entity or wallId+source must be provided');

  final FeedItemEntity? entity;
  final String? wallId;
  final WallpaperSource? source;
  final String? thumbnailUrl;
  final AnalyticsSurfaceValue analyticsSurface;

  /// Set when opened from a grid tile, so the tile image flies into this screen.
  final String? heroTag;

  /// Set when opened from Downloads: shown instead of the network image, and the fallback if loading fails.
  final File? localFile;

  // One bloc per route: a shared bloc showed the last wallpaper while the new one loaded.
  @override
  Widget wrappedRoute(BuildContext context) => BlocProvider<WallpaperDetailBloc>(
    key: ValueKey<(WallpaperSource, String)>((entity?.source ?? source!, entity?.id ?? wallId!)),
    create: (_) => getIt<WallpaperDetailBloc>(),
    child: this,
  );

  @override
  State<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends State<WallpaperDetailScreen> {
  /// The Glint "love" moment plays once per app session, on the first favourite.
  static bool _favouriteGlintShown = false;

  /// Gap between the Live chip and the top edge of the panel.
  static const double _chipGap = PrismSpace.sm;

  final ShakeController _shake = ShakeController();
  final SimilarWallpapersLoader _similarLoader = SimilarWallpapersLoader.fromGetIt();
  final ValueNotifier<bool> _panelContentVisible = ValueNotifier<bool>(false);

  /// 0 when the panel is collapsed, 1 when open. The Live chip rides on the top edge of the panel.
  final ValueNotifier<double> _panelPosition = ValueNotifier<double>(0);

  PanelController panelController = PanelController();
  bool _accentToastShown = false;
  bool _openRecorded = false;

  void _recordTaste(TasteAction action, FeedItemEntity entity) {
    final TasteSignal signal = entity.when(
      prism: (_, w) => TasteSignal.forWallpaper(action, w.core, tags: w.tags, collections: w.collections),
      wallhaven: (_, w) => TasteSignal.forWallpaper(action, w.core, tags: w.tags),
      pexels: (_, w) => TasteSignal.forWallpaper(action, w.core),
    );
    unawaited(getIt<TasteSignalStore>().record(signal));
  }

  void _onFavourited(FeedItemEntity entity) {
    _recordTaste(TasteAction.favourite, entity);
    if (_favouriteGlintShown || !mounted) return;
    _favouriteGlintShown = true;
    showGlintToast(context, mood: GlintMood.love);
  }

  String _getSourceContext(WallpaperDetailState? blocState) {
    final source = blocState is WallpaperDetailLoaded ? blocState.entity.source : widget.source;
    return '${source?.wireValue ?? 'unknown'}_wallpaper_screen';
  }

  void _trackAction(WallpaperDetailState? blocState, AnalyticsActionValue action) {
    final itemId = blocState is WallpaperDetailLoaded ? blocState.entity.id : null;
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: widget.analyticsSurface,
          action: action,
          sourceContext: _getSourceContext(blocState),
          itemType: ItemTypeValue.wallpaper,
          itemId: itemId,
        ),
      ),
    );
  }

  void _handlePanelOpened(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const OnPanelOpened());
    _trackAction(state, AnalyticsActionValue.panelOpened);
  }

  void _handlePanelClosed(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const OnPanelClosed());
    _trackAction(state, AnalyticsActionValue.panelClosed);
  }

  void _handlePanelSlide(double position) {
    _panelPosition.value = position;
    final bool visible = position > 0.12;
    if (_panelContentVisible.value != visible) _panelContentVisible.value = visible;
  }

  void _movePanel(double position) {
    panelController.animatePanelToPosition(
      position,
      duration: context.motion(PrismDurations.slow),
      curve: PrismCurves.sheet,
    );
  }

  void _togglePanel(WallpaperDetailLoaded state) {
    if (state.panelScrollInProgress) return;
    _trackAction(state, AnalyticsActionValue.panelCollapseTapped);
    _movePanel(panelController.isPanelOpen ? 0 : 1);
  }

  void _handleAccentTap(BuildContext context, WallpaperDetailLoaded state) {
    final colors = state.colors;
    final accent = state.accent;

    if (colors == null || colors.isEmpty || !colors.contains(accent)) return;

    PrismHaptics.selection();
    context.read<WallpaperDetailBloc>().add(const CycleAccentColor());
    _trackAction(state, AnalyticsActionValue.paletteCycleTapped);

    if (!_accentToastShown) {
      toasts.success('Long press to reset', haptic: false);
      _accentToastShown = true;
    }
  }

  void _handleAccentLongPress(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const ResetAccentColor());
    _trackAction(state, AnalyticsActionValue.paletteResetLongPressed);
    PrismHaptics.impact();
    _shake.shake();
  }

  void _handleColorSelected(BuildContext context, WallpaperDetailLoaded state, Color color) {
    context.read<WallpaperDetailBloc>().add(SelectAccentColor(color: color));
  }

  void _handleColorReset(BuildContext context) {
    context.read<WallpaperDetailBloc>().add(const ResetAccentColor());
  }

  void _handleColorCopy(Color color) {
    PrismHaptics.impact();
    Clipboard.setData(ClipboardData(text: '#${color.rgbHex.toUpperCase()}')).then((_) => toasts.color(color));
  }

  void _onWallpaperSet(FeedItemEntity entity) {
    _recordTaste(TasteAction.set, entity);
    if (entity.source == WallpaperSource.prism) {
      unawaited(getIt<RecordWallpaperActionUseCase>()(entity.id, WallpaperAction.set));
    }
  }

  /// "Match accent" on the success snackbar: sets Prism's accent to the first palette colour of this wallpaper.
  VoidCallback? _matchAccentAction(BuildContext context, WallpaperDetailLoaded state) {
    final Color? color = state.colors?.firstOrNull;
    if (color == null) return null;
    final ThemeBloc? themeBloc = _themeBloc(context);
    if (themeBloc == null) return null;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return () {
      themeBloc.add(
        dark
            ? ThemeEvent.darkAccentChanged(accentColorValue: color.toARGB32())
            : ThemeEvent.lightAccentChanged(accentColorValue: color.toARGB32()),
      );
      unawaited(analytics.track(const AccentMatchedFromWallEvent()));
    };
  }

  ThemeBloc? _themeBloc(BuildContext context) {
    try {
      return context.read<ThemeBloc>();
    } catch (_) {
      return null;
    }
  }

  /// Opens Make it live. The first palette colour seeds its gradients, so they follow this wallpaper.
  void _openMakeItLive(BuildContext context, WallpaperDetailLoaded state) {
    context.router.push(LiveWallpaperRoute(imageUrl: state.entity.fullUrl, accentSeed: state.colors?.firstOrNull));
  }

  @override
  void initState() {
    super.initState();
    _loadWallpaper(context);
  }

  @override
  void dispose() {
    _shake.dispose();
    _panelContentVisible.dispose();
    _panelPosition.dispose();
    super.dispose();
  }

  void _loadWallpaper(BuildContext context) {
    final bloc = context.read<WallpaperDetailBloc>();
    final entity = widget.entity;
    if (entity != null) {
      bloc.add(LoadFromEntity(entity: entity, localFilePath: widget.localFile?.path));
    } else {
      bloc.add(
        LoadFromId(
          wallId: widget.wallId!,
          source: widget.source!,
          thumbnailUrl: widget.thumbnailUrl,
          localFilePath: widget.localFile?.path,
        ),
      );
    }
  }

  double _topOverlayPadding(BuildContext context) {
    final inset = app_state.notchSize ?? MediaQuery.paddingOf(context).top;
    return inset + PrismSpace.xs;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WallpaperDetailBloc, WallpaperDetailState>(
      listener: (context, state) {
        if (state is WallpaperDetailError &&
            widget.localFile?.existsSync() == true &&
            ModalRoute.of(context)?.isCurrent == true) {
          context.router.replace(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: widget.localFile!));
          return;
        }
        if (state is WallpaperDetailLoaded && !_openRecorded) {
          _openRecorded = true;
          _recordTaste(TasteAction.open, state.entity);
        }
      },
      child: BlocBuilder<WallpaperDetailBloc, WallpaperDetailState>(
        builder: (context, state) {
          final entity = widget.entity;
          return switch (state) {
            // Build the entity on the first frame too, so the hero flight shows the tapped wallpaper.
            WallpaperDetailInitial() when entity != null => _buildLoadedState(
              context,
              WallpaperDetailLoaded(entity: entity),
            ),
            WallpaperDetailInitial() || WallpaperDetailLoading() => _buildLoadingState(state),
            WallpaperDetailLoaded() => _buildLoadedState(context, state),
            WallpaperDetailError() => _buildErrorState(state),
          };
        },
      ),
    );
  }

  /// Back and clock preview, floating over the wallpaper.
  Widget _chrome(BuildContext context, {required VoidCallback onBack, VoidCallback? onClock}) {
    final double top = _topOverlayPadding(context);
    return Stack(
      children: <Widget>[
        Positioned(
          top: top,
          left: PrismSpace.md,
          child: PrismIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onImage: true, onPressed: onBack),
        ),
        if (onClock != null)
          Positioned(
            top: top,
            right: PrismSpace.md,
            child: PrismIconButton(
              icon: Icons.schedule_rounded,
              tooltip: 'Clock preview',
              onImage: true,
              onPressed: onClock,
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState(WallpaperDetailState state) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String thumbnailUrl = normalizeWallpaperThumbnailUrl(
      (state is WallpaperDetailLoading ? state.thumbnailUrl : widget.thumbnailUrl) ?? '',
    );
    void back() => Navigator.pop(context);
    final File? localFile = widget.localFile;
    if (localFile != null) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.file(
              localFile,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const GlintState(kind: GlintStateKind.error, title: 'Downloaded wallpaper is unavailable'),
            ),
            const Align(alignment: Alignment.bottomCenter, child: DetailPanelSkeleton()),
            _chrome(context, onBack: back),
          ],
        ),
      );
    }
    if (thumbnailUrl.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const GlintState(kind: GlintStateKind.loading, title: 'Loading wallpaper'),
            _chromeOnSurface(onBack: back),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _withHero(
            CachedNetworkImage(
              cacheManager: PrismImageCache.instance,
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              fadeInDuration: context.motion(PrismDurations.fast),
              fadeOutDuration: context.motion(PrismDurations.fast),
              width: double.infinity,
              height: double.infinity,
              placeholder: (ctx, _) => ColoredBox(color: cs.surfaceContainerHigh),
              errorWidget: (ctx, _, _) => ColoredBox(color: cs.surfaceContainerHigh),
            ),
          ),
          const Align(alignment: Alignment.bottomCenter, child: DetailPanelSkeleton()),
          _chrome(context, onBack: back),
        ],
      ),
    );
  }

  /// Back button for states that have no wallpaper behind them.
  Widget _chromeOnSurface({required VoidCallback onBack}) {
    return Positioned(
      top: _topOverlayPadding(context),
      left: PrismSpace.md,
      child: PrismIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', filled: true, onPressed: onBack),
    );
  }

  Widget _withHero(Widget child) => widget.heroTag == null
      ? child
      : HeroMode(
          enabled: !context.reduceMotion,
          child: Hero(tag: widget.heroTag!, child: child),
        );

  Widget _buildErrorState(WallpaperDetailError state) {
    final message = state.message.trim();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String thumbnailUrl = normalizeWallpaperThumbnailUrl(state.thumbnailUrl ?? '');
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (thumbnailUrl.isNotEmpty)
            CachedNetworkImage(
              cacheManager: PrismImageCache.instance,
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (ctx, _) => ColoredBox(color: cs.surfaceContainerHigh),
              errorWidget: (ctx, _, _) => ColoredBox(color: cs.surfaceContainerHigh),
            ),
          ColoredBox(color: cs.surface.withValues(alpha: thumbnailUrl.isEmpty ? 1 : 0.8)),
          GlintState(
            kind: GlintStateKind.error,
            title: "Couldn't load this wallpaper",
            body: message.isEmpty ? 'Check your connection and try again.' : message,
            actionLabel: 'Try again',
            onAction: () => _loadWallpaper(context),
          ),
          _chromeOnSurface(onBack: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, WallpaperDetailLoaded state) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool paletteLoading = state.paletteLoading;
    final double minHeight = DetailPanel.collapsedHeight(context);
    final double maxHeight = max(minHeight + 240, min(MediaQuery.sizeOf(context).height * 0.66, 560));
    final Color backgroundColor = paletteLoading ? cs.surface : (state.accent ?? cs.surface);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Per route, so a covered detail screen cannot change the status bar of the one on top.
      value: edgeToEdgeOverlayStyle(
        statusBarIconBrightness: onColor(backgroundColor) == Colors.black ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SlidingUpPanel(
          onPanelOpened: () => _handlePanelOpened(context, state),
          onPanelClosed: () => _handlePanelClosed(context, state),
          onPanelSlide: _handlePanelSlide,
          // No backdropEnabled: its invisible backdrop covered Back and Clock while the panel was open.
          renderPanelSheet: false,
          boxShadow: const [],
          minHeight: minHeight,
          parallaxEnabled: true,
          parallaxOffset: 0,
          color: Colors.transparent,
          maxHeight: maxHeight,
          controller: panelController,
          panel: SizedBox(
            height: maxHeight,
            child: DetailPanel(
              state: state,
              sourceContext: _getSourceContext(state),
              contentVisible: _panelContentVisible,
              onToggle: () => _togglePanel(state),
              onScrollStart: () => context.read<WallpaperDetailBloc>().add(const OnPanelScrollStart()),
              onScrollEnd: () => Future<void>.delayed(context.motion(PrismDurations.base), () {
                if (!context.mounted) return;
                context.read<WallpaperDetailBloc>().add(const OnPanelScrollEnd());
              }),
              onResetColor: () => _handleColorReset(context),
              onSelectColor: (color) => _handleColorSelected(context, state, color),
              onCopyColor: _handleColorCopy,
              onDownloaded: () => _recordTaste(TasteAction.download, state.entity),
              onSet: () => _onWallpaperSet(state.entity),
              onFavourited: () => _onFavourited(state.entity),
              localFile: widget.localFile,
              onMatchAccent: _matchAccentAction(context, state),
              onTagTap: (tag) => openTagSearch(context, tag),
              onMakeItLive: () => _openMakeItLive(context, state),
              similarLoader: _similarLoader.load,
              onOpenSimilar: (item) =>
                  context.router.push(WallpaperDetailRoute(entity: item, thumbnailUrl: item.thumbnailUrl)),
            ),
          ),
          body: _buildImageBody(context, paletteLoading, state, minHeight: minHeight, maxHeight: maxHeight),
        ),
      ),
    );
  }

  Widget _buildImageBody(
    BuildContext context,
    bool paletteLoading,
    WallpaperDetailLoaded state, {
    required double minHeight,
    required double maxHeight,
  }) {
    final entity = state.entity;
    return Stack(
      children: [
        ShakeOnce(
          controller: _shake,
          distance: 48,
          builder: (context, t, _) {
            return Semantics(
              label: 'Wallpaper',
              hint: 'Tap to cycle accent color. Long press to reset. Swipe up for details.',
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (details.delta.dy < -10) _movePanel(1);
                },
                onLongPress: () => _handleAccentLongPress(context, state),
                onTap: () {
                  if (!paletteLoading) _handleAccentTap(context, state);
                  _shake.shake();
                },
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: t * 1.25, horizontal: t / 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(t),
                    child: _withHero(
                      DetailWallpaperImage(
                        entity: entity,
                        accent: state.accent,
                        tint: state.tint,
                        paletteLoading: paletteLoading,
                        localFile: widget.localFile,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        _chrome(
          context,
          onBack: () {
            _trackAction(state, AnalyticsActionValue.backTapped);
            Navigator.pop(context);
          },
          onClock: () {
            _trackAction(state, AnalyticsActionValue.clockOverlayOpened);
            pushClockPreview(
              context,
              link: widget.localFile?.path ?? entity.fullUrl,
              file: widget.localFile != null,
              thumbnailUrl: entity.thumbnailUrl,
              tint: state.tint,
            );
          },
        ),
        if (!hideSetWallpaperUi && entity.fullUrl.trim().isNotEmpty)
          ValueListenableBuilder<double>(
            valueListenable: _panelPosition,
            child: MakeItLiveChip(onPressed: () => _openMakeItLive(context, state)),
            builder: (BuildContext context, double position, Widget? chip) => Positioned(
              left: PrismSpace.page,
              bottom:
                  lerpDouble(minHeight, maxHeight, position)! +
                  _chipGap -
                  (MakeItLiveChip.hitSize - MakeItLiveChip.pillHeight) / 2,
              child: IgnorePointer(
                ignoring: position > 0,
                child: Opacity(opacity: (1 - position * 2).clamp(0.0, 1.0), child: chip),
              ),
            ),
          ),
      ],
    );
  }
}
