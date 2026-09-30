import 'dart:async';
import 'dart:math' show max, min;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_panel.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_wallpaper_image.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

@RoutePage()
class WallpaperDetailScreen extends StatefulWidget {
  const WallpaperDetailScreen({
    super.key,
    this.entity,
    this.wallId,
    this.source,
    this.thumbnailUrl,
    this.analyticsSurface = AnalyticsSurfaceValue.wallpaperScreen,
    this.heroTag,
  }) : assert(entity != null || (wallId != null && source != null), 'Either entity or wallId+source must be provided');

  final FeedItemEntity? entity;
  final String? wallId;
  final WallpaperSource? source;
  final String? thumbnailUrl;
  final AnalyticsSurfaceValue analyticsSurface;

  /// Set when opened from a grid tile, so the tile image flies into this screen.
  final String? heroTag;

  @override
  State<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends State<WallpaperDetailScreen> {
  /// The Glint "love" moment plays once per app session, on the first favourite.
  static bool _favouriteGlintShown = false;

  final ShakeController _shake = ShakeController();
  final ValueNotifier<bool> _panelContentVisible = ValueNotifier<bool>(false);

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

    context.read<WallpaperDetailBloc>().add(const CycleAccentColor());
    _setStatusBarIconBrightness(state.accent ?? Colors.white);
    _trackAction(state, AnalyticsActionValue.paletteCycleTapped);

    if (!_accentToastShown) {
      toasts.success('Long press to reset');
      _accentToastShown = true;
    }
  }

  void _handleAccentLongPress(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const ResetAccentColor());
    _trackAction(state, AnalyticsActionValue.paletteResetLongPressed);
    HapticFeedback.vibrate();
    _shake.shake();
  }

  void _handleColorSelected(BuildContext context, WallpaperDetailLoaded state, Color color) {
    context.read<WallpaperDetailBloc>().add(SelectAccentColor(color: color));
    _setStatusBarIconBrightness(color);
  }

  void _handleColorReset(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const ResetAccentColor());
    _setStatusBarIconBrightness(state.accent ?? Colors.white);
  }

  void _handleColorCopy(Color color) {
    HapticFeedback.vibrate();
    Clipboard.setData(ClipboardData(text: '#${color.rgbHex.toUpperCase()}')).then((_) => toasts.color(color));
  }

  void _setStatusBarIconBrightness(Color color) {
    applyEdgeToEdgeOverlayStyle(
      statusBarIconBrightness: onColor(color) == Colors.black ? Brightness.dark : Brightness.light,
    );
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
    super.dispose();
  }

  void _loadWallpaper(BuildContext context) {
    final bloc = context.read<WallpaperDetailBloc>();
    final entity = widget.entity;
    if (entity != null) {
      bloc.add(LoadFromEntity(entity: entity));
    } else {
      bloc.add(LoadFromId(wallId: widget.wallId!, source: widget.source!, thumbnailUrl: widget.thumbnailUrl));
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
        if (state is WallpaperDetailLoaded && !_openRecorded) {
          _openRecorded = true;
          _recordTaste(TasteAction.open, state.entity);
        }
        if (state is WallpaperDetailLoaded && state.colors != null && state.accent != null) {
          _setStatusBarIconBrightness(state.accent!);
        }
      },
      child: BlocBuilder<WallpaperDetailBloc, WallpaperDetailState>(
        builder: (context, state) {
          return switch (state) {
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
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

    return Scaffold(
      backgroundColor: paletteLoading ? cs.surface : (state.accent ?? cs.surface),
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
            onResetColor: () => _handleColorReset(context, state),
            onSelectColor: (color) => _handleColorSelected(context, state, color),
            onCopyColor: _handleColorCopy,
            onDownloaded: () => _recordTaste(TasteAction.download, state.entity),
            onSet: () => _recordTaste(TasteAction.set, state.entity),
            onFavourited: () => _onFavourited(state.entity),
          ),
        ),
        body: _buildImageBody(context, paletteLoading, state),
      ),
    );
  }

  Widget _buildImageBody(BuildContext context, bool paletteLoading, WallpaperDetailLoaded state) {
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
                  HapticFeedback.vibrate();
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
                        tinted: state.colorChanged,
                        paletteLoading: paletteLoading,
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
              link: entity.fullUrl,
              file: false,
              accent: state.accent,
              colorChanged: state.colorChanged,
            );
          },
        ),
      ],
    );
  }
}
