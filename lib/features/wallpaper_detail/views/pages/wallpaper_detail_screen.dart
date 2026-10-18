import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min, pi;
import 'dart:ui' show lerpDouble;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/format_utils.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart' show PrismGroup;
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/biz/block_wall_creator.dart';
import 'package:Prism/features/wallpaper_detail/biz/similar_wallpapers_loader.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/data/wallpaper_tint_renderer.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/boost_wall_row.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/similar_wallpapers_strip.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_tag_chips.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

@visibleForTesting
bool shouldRecordWallpaperSetStats(FeedItemEntity entity) =>
    entity.source == WallpaperSource.prism && !BundledWallpapers.isStarter(entity);

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
    this.requestId,
  }) : assert(entity != null || (wallId != null && source != null), 'Either entity or wallId+source must be provided');

  final FeedItemEntity? entity;
  final String? wallId;
  final WallpaperSource? source;
  final String? thumbnailUrl;
  final AnalyticsSurfaceValue analyticsSurface;
  final String? requestId;

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
  static const double _sheetHPad = 24.0;

  /// The glass floats this far from the left, right and bottom (the safe area comes on top of the bottom inset).
  static const double _panelInset = 10.0;

  /// Concentric with the 46 px Set pill, which sits 16 px inside the glass corner.
  static const double _panelRadius = 40.0;
  static const double _panelMaxFraction = 0.55;

  /// Glass tint as a share of the theme primary colour, closed and open. The default is 0.2. The dock holds icon
  /// buttons and the open panel holds text, so both need more to stay readable over a bright wallpaper. A light
  /// theme paints dark icons on a pale tint, so it needs the most.
  static const ({double dock, double open}) _glassAlphaLight = (dock: 0.55, open: 0.7);
  static const ({double dock, double open}) _glassAlphaDark = (dock: 0.5, open: 0.6);

  /// Text and icons in the panel that sit one step below the title.
  static const double _secondaryAlpha = 0.85;

  /// The glass is lifted off the wallpaper by a soft shadow. It is drawn outside the glass only, so it never darkens
  /// what the glass blurs.
  static const BoxShadow _shadowLight = BoxShadow(color: Color(0x24000000), blurRadius: 24, offset: Offset(0, 8));
  static const BoxShadow _shadowDark = BoxShadow(color: Color(0x59000000), blurRadius: 28, offset: Offset(0, 10));

  /// Panel content fades out over this height above the action bar, instead of ending in a hard edge.
  static const double _contentFade = 24.0;

  /// Gap between the Live chip and the top edge of the glass.
  static const double _chipGap = 12.0;
  static const double _chromePad = 8.0;
  static const double _handleHeight = 36.0;
  static const double _handleHitWidth = 96.0;
  static const double _handleHitHeight = 48.0;

  /// "Set N times" shows from this count, so a small number never reads as a poor wallpaper.
  static const int _minSetCountShown = 5;

  final ShakeController _shake = ShakeController();
  final SimilarWallpapersLoader _similarLoader = SimilarWallpapersLoader.fromGetIt();

  PanelController panelController = PanelController();

  /// 0 when the panel is collapsed, 1 when open. The collapsed panel sits under the action bar, so its content fades.
  final ValueNotifier<double> _panelPosition = ValueNotifier<double>(0);
  bool _accentToastShown = false;
  bool _openRecorded = false;
  String? _offlinePreviewKey;
  Future<File?>? _offlinePreviewFuture;

  void _recordTaste(TasteAction action, FeedItemEntity entity) {
    final TasteSignal signal = entity.when(
      prism: (_, w) => TasteSignal.forWallpaper(action, w.core, tags: w.tags, collections: w.collections),
      wallhaven: (_, w) => TasteSignal.forWallpaper(action, w.core, tags: w.tags),
      pexels: (_, w) => TasteSignal.forWallpaper(action, w.core),
    );
    unawaited(getIt<TasteSignalStore>().record(signal));
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
          requestId: widget.requestId,
          provider: blocState is WallpaperDetailLoaded ? blocState.entity.source.name : widget.source?.name,
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

  void _handleColorSelected(BuildContext context, Color color) {
    context.read<WallpaperDetailBloc>().add(SelectAccentColor(color: color));
  }

  @override
  void initState() {
    super.initState();
    _loadWallpaper(context);
  }

  @override
  void dispose() {
    _shake.dispose();
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
    return inset + _chromePad;
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

  Widget _buildLoadingState(WallpaperDetailState state) {
    final File? localFile = widget.localFile;
    if (localFile != null) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              localFile,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const GlintState(kind: GlintStateKind.error, title: 'Downloaded wallpaper is unavailable'),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(JamIcons.chevron_left),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final String thumbnailUrl = normalizeWallpaperThumbnailUrl(
      (state is WallpaperDetailLoading ? state.thumbnailUrl : widget.thumbnailUrl) ?? '',
    );
    if (thumbnailUrl.isEmpty) {
      return const Scaffold(
        body: GlintState(kind: GlintStateKind.loading, title: 'Loading wallpaper'),
      );
    }
    return Scaffold(
      body: _withHero(
        CachedNetworkImage(
          cacheManager: PrismImageCache.instance,
          imageUrl: thumbnailUrl,
          fit: BoxFit.cover,
          fadeInDuration: context.motion(const Duration(milliseconds: 180)),
          fadeOutDuration: context.motion(const Duration(milliseconds: 180)),
          width: double.infinity,
          height: double.infinity,
          placeholder: (ctx, _) => Container(color: Theme.of(ctx).primaryColor),
          errorWidget: (ctx, _, _) => Container(color: Theme.of(ctx).primaryColor),
        ),
      ),
    );
  }

  Widget _withHero(Widget child) => widget.heroTag == null
      ? child
      : HeroMode(
          enabled: !context.reduceMotion,
          child: Hero(tag: widget.heroTag!, child: child),
        );

  Widget _buildErrorState(WallpaperDetailError state) {
    final theme = Theme.of(context);
    final thumbnailUrl = normalizeWallpaperThumbnailUrl(state.thumbnailUrl ?? '');
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl.isNotEmpty)
            CachedNetworkImage(
              cacheManager: PrismImageCache.instance,
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (ctx, _) => Container(color: theme.primaryColor),
              errorWidget: (ctx, _, _) => Container(color: theme.primaryColor),
            ),
          Container(color: theme.primaryColor.withValues(alpha: thumbnailUrl.isEmpty ? 1 : 0.8)),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: GlintState(
                    kind: GlintStateKind.error,
                    title: "Couldn't load this wallpaper",
                    body: state.message,
                    actionLabel: 'Try again',
                    onAction: () => _loadWallpaper(context),
                  ),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go back')),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, WallpaperDetailLoaded state) {
    final paletteLoading = state.paletteLoading;
    final backgroundColor = paletteLoading
        ? Theme.of(context).primaryColor
        : state.accent ?? Theme.of(context).scaffoldBackgroundColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: edgeToEdgeOverlayStyle(
        statusBarIconBrightness: onColor(backgroundColor) == Colors.black ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(backgroundColor: backgroundColor, body: _buildPanelStack(context, state, paletteLoading)),
    );
  }

  _PanelGeometry _panelGeometry(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double side = max(0.0, (MediaQuery.sizeOf(context).width - PrismLayout.panelWidth) / 2);
    return _PanelGeometry(
      collapsed: _handleHeight + WallpaperActionBar.height,
      open: MediaQuery.sizeOf(context).height * _panelMaxFraction,
      left: max(safe.left + _panelInset, side),
      right: max(safe.right + _panelInset, side),
      bottom: safe.bottom + _panelInset,
    );
  }

  Widget _buildPanelStack(BuildContext context, WallpaperDetailLoaded state, bool paletteLoading) {
    final _PanelGeometry geometry = _panelGeometry(context);
    final Widget panel = SlidingUpPanel(
      onPanelOpened: () => _handlePanelOpened(context, state),
      onPanelClosed: () => _handlePanelClosed(context, state),
      onPanelSlide: (double position) => _panelPosition.value = position,
      // No backdropEnabled: its invisible backdrop covered Back and Clock while the panel was open.
      borderRadius: BorderRadius.circular(_panelRadius),
      boxShadow: const [],
      margin: EdgeInsets.fromLTRB(geometry.left, 0, geometry.right, geometry.bottom),
      minHeight: geometry.collapsed,
      parallaxEnabled: true,
      parallaxOffset: 0,
      color: Colors.transparent,
      maxHeight: geometry.open,
      controller: panelController,
      panel: _buildInfoPanel(context, state, geometry),
      body: _buildImageBody(context, paletteLoading, state, geometry),
    );
    return Stack(
      children: [
        Positioned.fill(child: panel),
        Positioned(
          left: geometry.left,
          right: geometry.right,
          bottom: geometry.bottom,
          child: _buildActionBar(context, state),
        ),
      ],
    );
  }

  /// The panel child is laid out at its open height and the sliding panel clips it to the visible height, so the
  /// glass is drawn here at the visible height itself. Its rounded bottom then shows in every position.
  Widget _buildInfoPanel(BuildContext context, WallpaperDetailLoaded state, _PanelGeometry geometry) {
    final entity = state.entity;
    final ThemeData theme = Theme.of(context);
    final ({double dock, double open}) alphas = theme.brightness == Brightness.light
        ? _glassAlphaLight
        : _glassAlphaDark;

    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _panelPosition,
          builder: (BuildContext context, double position, Widget? _) => Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: geometry.heightAt(position),
            child: PrismGlass(
              borderRadius: _panelRadius,
              glassColor: theme.primaryColor.withValues(alpha: lerpDouble(alphas.dock, alphas.open, position)),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _panelPosition,
          builder: (BuildContext context, double position, Widget? content) => ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) => _fadeAboveActionBar(bounds, geometry.heightAt(position)),
            child: content,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: _handleHeight),
              _fadeWithPanel(_buildColorBar(context, state)),
              Expanded(
                flex: 8,
                child: _fadeWithPanel(
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollStartNotification) {
                          context.read<WallpaperDetailBloc>().add(const OnPanelScrollStart());
                        } else if (notification is ScrollEndNotification) {
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (!context.mounted) return;
                            context.read<WallpaperDetailBloc>().add(const OnPanelScrollEnd());
                          });
                        }
                        return false;
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_buildMetadataRow(context, entity, state), ..._buildPanelExtras(context, state)],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: WallpaperActionBar.height),
            ],
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, height: _handleHitHeight, child: _buildCollapseHandle(context, state)),
      ],
    );
  }

  /// Opaque down to [_contentFade] above the action bar, clear at the action bar. [glassHeight] is the visible height.
  Shader _fadeAboveActionBar(Rect bounds, double glassHeight) {
    final double edge = glassHeight - WallpaperActionBar.height;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Colors.black, Colors.black, Colors.transparent, Colors.transparent],
      stops: [0, (edge - _contentFade) / bounds.height, edge / bounds.height, 1],
    ).createShader(bounds);
  }

  Widget _fadeWithPanel(Widget child) => ValueListenableBuilder<double>(
    valueListenable: _panelPosition,
    child: child,
    builder: (BuildContext context, double position, Widget? child) => IgnorePointer(
      ignoring: position == 0,
      child: Opacity(opacity: position, child: child),
    ),
  );

  /// One chevron that turns over as the panel opens. Its touch target is wider and taller than the glyph and reaches
  /// down over the top of the action bar, whose buttons are above it and keep their own taps.
  Widget _buildCollapseHandle(BuildContext context, WallpaperDetailLoaded state) {
    final isCollapsed = state.panelCollapsed;
    return Center(
      child: Semantics(
        // Its own node: the faded panel content drops out of semantics, and this label must not merge into the panel.
        container: true,
        button: true,
        label: isCollapsed ? 'Expand wallpaper details' : 'Collapse wallpaper details',
        child: GestureDetector(
          onTap: () {
            if (state.panelScrollInProgress) return;
            _trackAction(state, AnalyticsActionValue.panelCollapseTapped);
            if (panelController.isPanelOpen) {
              panelController.close();
            } else {
              panelController.open();
            }
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: _handleHitWidth,
            height: _handleHitHeight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: _handleHitHeight - _handleHeight),
              child: Center(
                child: ValueListenableBuilder<double>(
                  valueListenable: _panelPosition,
                  builder: (BuildContext context, double position, Widget? icon) =>
                      Transform.rotate(angle: pi * position, child: icon),
                  child: Icon(
                    JamIcons.chevron_up,
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorBar(BuildContext context, WallpaperDetailLoaded state) {
    final String fullUrl = state.entity.fullUrl.trim();
    if (widget.localFile != null || !isValidNetworkUrl(fullUrl)) {
      return _buildColorBarWithImage(context, state, localFile: widget.localFile);
    }

    return FutureBuilder<File?>(
      future: _offlinePreviewFor(state.entity),
      builder: (BuildContext context, AsyncSnapshot<File?> snapshot) {
        final bool pending = snapshot.connectionState != ConnectionState.done;
        final File? retained = snapshot.data;
        return _buildColorBarWithImage(
          context,
          state,
          localFile: !pending && retained != null && retained.existsSync() ? retained : null,
          withholdThumbnail: pending,
        );
      },
    );
  }

  Widget _buildColorBarWithImage(
    BuildContext context,
    WallpaperDetailLoaded state, {
    required File? localFile,
    bool withholdThumbnail = false,
  }) {
    final colors = state.colors;
    final thumbnailUrl = withholdThumbnail ? '' : state.entity.thumbnailUrl.trim();

    // Build the default (no-filter) swatch + one swatch per palette color.
    final swatches = <Widget>[
      _buildColorSwatch(
        context: context,
        thumbnailUrl: thumbnailUrl,
        localFile: localFile,
        color: null,
        isSelected: !state.colorChanged,
        onTap: () {
          context.read<WallpaperDetailBloc>().add(const ResetAccentColor());
        },
        onLongPress: null,
      ),
      for (final color in colors ?? const <Color>[])
        _buildColorSwatch(
          context: context,
          thumbnailUrl: thumbnailUrl,
          localFile: localFile,
          color: color,
          isSelected: state.colorChanged && color == state.accent,
          onTap: () => _handleColorSelected(context, color),
          onLongPress: () {
            PrismHaptics.impact();
            Clipboard.setData(ClipboardData(text: '#${color.rgbHex.toUpperCase()}')).then((_) => toasts.color(color));
          },
        ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(_sheetHPad, _handleHitHeight - _handleHeight, _sheetHPad, 8),
      height: 88,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(children: swatches.map((s) => Expanded(child: s)).toList()),
      ),
    );
  }

  Widget _buildColorSwatch({
    required BuildContext context,
    required String thumbnailUrl,
    required File? localFile,
    required Color? color,
    required bool isSelected,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
  }) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final label = color == null ? 'Original wallpaper colors' : 'Accent color';
    final placeholder = color ?? secondary.withValues(alpha: 0.1);
    final hint = color == null ? null : 'Long press to copy hex color';
    final BlendMode? blendMode = color == null ? null : BlendMode.hue;
    return Semantics(
      button: onTap != null,
      selected: isSelected,
      label: label,
      hint: hint,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                PrismHaptics.selection();
                onTap();
              },
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (localFile != null)
              Image.file(
                localFile,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                color: color,
                colorBlendMode: blendMode,
                errorBuilder: (_, _, _) => ColoredBox(color: placeholder),
              )
            else if (thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                cacheManager: PrismImageCache.instance,
                imageUrl: thumbnailUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 240,
                color: color,
                colorBlendMode: blendMode,
                placeholder: (_, u) => ColoredBox(color: placeholder),
                errorWidget: (_, u, e) => ColoredBox(color: placeholder),
              )
            else
              ColoredBox(color: placeholder),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 8,
                width: double.infinity,
                child: ColoredBox(color: color ?? secondary),
              ),
            ),
            AnimatedOpacity(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(JamIcons.check, size: 14, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, FeedItemEntity entity, WallpaperDetailLoaded state) {
    return entity.when(
      prism: (_, wallpaper) => _buildPrismMetadata(context, wallpaper, state),
      wallhaven: (_, wallpaper) => _buildWallhavenMetadata(context, wallpaper),
      pexels: (_, wallpaper) => _buildPexelsMetadata(context, wallpaper),
    );
  }

  Widget _metadataShell({required List<Widget> left, required List<Widget> right}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_sheetHPad, 4, _sheetHPad, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 5,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: left),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 4,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: right),
          ),
        ],
      ),
    );
  }

  Widget _buildPrismMetadata(BuildContext context, PrismWallpaper wallpaper, WallpaperDetailLoaded state) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final divider = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Container(height: 16, color: secondary.withValues(alpha: 0.4), width: 1),
    );
    final TextStyle dimmedHeadline = Theme.of(
      context,
    ).textTheme.headlineSmall!.copyWith(color: secondary.withValues(alpha: _secondaryAlpha));
    final collections = wallpaper.collections;
    final category = wallpaper.core.category;
    final resolution = wallpaper.core.resolution;
    final sizeBytes = wallpaper.core.sizeBytes;
    final createdAt = wallpaper.core.createdAt;
    return _metadataShell(
      left: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LayoutBuilder(
            builder: (context, constraints) => Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Text(
                    wallpaperTitle(state.entity),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: secondary),
                  ),
                ),
                if (state.views != null) ...[
                  divider,
                  Text("${state.views} views", style: dimmedHeadline),
                ] else if (state.viewsLoading) ...[
                  divider,
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(secondary)),
                  ),
                ],
                if (state.setCount case final int sets when sets >= _minSetCountShown) ...[
                  divider,
                  Text('Set $sets times', style: dimmedHeadline),
                ],
              ],
            ),
          ),
        ),
        if (collections != null && collections.isNotEmpty) ...[
          _buildInfoRow(context, JamIcons.folder, collections.take(2).join(', ')),
          const SizedBox(height: 4),
        ],
        if (category != null) ...[_buildInfoRow(context, JamIcons.unordered_list, category), const SizedBox(height: 4)],
        if (resolution != null) ...[_buildInfoRow(context, JamIcons.set_square, resolution), const SizedBox(height: 4)],
        if (sizeBytes != null) _buildInfoRow(context, JamIcons.save, formatMegabytes(sizeBytes)),
      ],
      right: [
        _buildPrismAuthorRow(context, wallpaper),
        if (createdAt != null) ...[
          const SizedBox(height: 4),
          _buildInfoRow(context, JamIcons.calendar, _formatDate(createdAt), reversed: true),
        ],
        const SizedBox(height: 4),
        _buildInfoRow(context, JamIcons.database, 'Prism', reversed: true),
      ],
    );
  }

  Widget _buildWallhavenMetadata(BuildContext context, WallhavenWallpaper wallpaper) {
    final views = wallpaper.views;
    final favourites = wallpaper.core.favourites;
    final sizeBytes = wallpaper.sizeBytes ?? wallpaper.core.sizeBytes;
    final author = wallpaper.core.authorName;
    final category = wallpaper.core.category;
    final resolution = wallpaper.core.resolution;
    return _metadataShell(
      left: [
        _buildInfoTitle(context, wallpaper.id.toUpperCase()),
        if (views != null) ...[const SizedBox(height: 4), _buildInfoRow(context, JamIcons.eye, views.toString())],
        if (favourites != null) ...[
          const SizedBox(height: 4),
          _buildInfoRow(context, JamIcons.heart_f, favourites.toString()),
        ],
        if (sizeBytes != null) ...[
          const SizedBox(height: 4),
          _buildInfoRow(context, JamIcons.save, formatMegabytes(sizeBytes)),
        ],
      ],
      right: [
        if (author != null && author.isNotEmpty) ...[
          _buildAuthorLink(context, author, Uri.https('wallhaven.cc', '/user/${Uri.encodeComponent(author)}')),
          const SizedBox(height: 4),
        ],
        if (category != null) ...[
          _buildInfoRow(context, JamIcons.unordered_list, category, reversed: true),
          const SizedBox(height: 4),
        ],
        if (resolution != null) ...[
          _buildInfoRow(context, JamIcons.set_square, resolution, reversed: true),
          const SizedBox(height: 4),
        ],
        _buildInfoRow(context, JamIcons.database, 'Wallhaven', reversed: true),
      ],
    );
  }

  Widget _buildPexelsMetadata(BuildContext context, PexelsWallpaper wallpaper) {
    final width = wallpaper.core.width;
    final height = wallpaper.core.height;
    final photographer = wallpaper.photographer;
    final photographerUrl = wallpaper.photographerUrl?.trim() ?? '';
    return _metadataShell(
      left: [
        _buildInfoTitle(context, wallpaper.id),
        if (width != null && height != null) ...[
          const SizedBox(height: 4),
          _buildInfoRow(context, JamIcons.set_square, "${width}x$height"),
        ],
      ],
      right: [
        if (photographer != null && photographer.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildAuthorLink(
              context,
              photographer,
              photographerUrl.isEmpty ? null : Uri.tryParse(photographerUrl),
            ),
          ),
          const SizedBox(height: 4),
        ],
        _buildInfoRow(context, JamIcons.database, 'Pexels', reversed: true),
      ],
    );
  }

  Widget _buildPrismAuthorRow(BuildContext context, PrismWallpaper wallpaper) {
    final String nameTrimmed = wallpaper.core.authorName?.trim() ?? '';
    final String photoTrimmed = wallpaper.core.authorPhoto?.trim() ?? '';
    final String emailTrimmed = wallpaper.core.authorEmail?.trim() ?? '';
    final bool hasName = nameTrimmed.isNotEmpty;
    final bool hasPhoto = photoTrimmed.isNotEmpty;

    final String? displayLabel = hasName
        ? nameTrimmed
        : emailTrimmed.isNotEmpty
        ? emailTrimmed
        : null;

    if (displayLabel == null && !hasPhoto) {
      return const SizedBox.shrink();
    }

    final String initialChar = displayLabel != null && displayLabel.isNotEmpty
        ? displayLabel.characters.first.toUpperCase()
        : '?';

    final Color secondary = Theme.of(context).colorScheme.secondary;
    final Widget avatar = CircleAvatar(
      radius: 13,
      backgroundColor: secondary.withValues(alpha: 0.15),
      child: hasPhoto
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoTrimmed,
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Text(
                  initialChar,
                  style: TextStyle(color: secondary, fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ),
            )
          : Text(
              initialChar,
              style: TextStyle(color: secondary, fontWeight: FontWeight.w600, fontSize: 11),
            ),
    );

    // Prefer email; fall back to name as username (getUserProfile handles both).
    final String profileIdentifier = emailTrimmed.isNotEmpty ? emailTrimmed : nameTrimmed;
    Widget tappable(Widget child) => profileIdentifier.isEmpty
        ? child
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                PrismHaptics.tap();
                context.router.push(ProfileRoute(profileIdentifier: profileIdentifier));
              },
              borderRadius: BorderRadius.circular(8),
              child: child,
            ),
          );

    if (displayLabel == null) {
      return tappable(Padding(padding: const EdgeInsets.only(bottom: 4), child: avatar));
    }

    return tappable(
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayLabel,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: secondary),
              ),
            ),
            const SizedBox(width: 10),
            avatar,
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorLink(BuildContext context, String text, Uri? uri) {
    final style = Theme.of(context).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? min(constraints.maxWidth, 200.0) : 200.0;
        final label = Text(text, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: style);
        return SizedBox(
          width: maxW,
          child: Align(
            alignment: Alignment.centerRight,
            child: uri == null
                ? label
                : InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!ok && context.mounted) {
                        toasts.error('Could not open profile');
                      }
                    },
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: label),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text, {bool reversed = false}) {
    final iconWidget = Icon(
      icon,
      size: 20,
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: _secondaryAlpha),
    );
    final textWidget = Flexible(
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
    const spacer = SizedBox(width: 10);
    if (reversed) {
      return Row(mainAxisSize: MainAxisSize.min, children: [textWidget, spacer, iconWidget]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [iconWidget, spacer, textWidget]);
  }

  String? _shareContextLine(FeedItemEntity entity) {
    final String? name = entity.wallpaperCore.authorName?.trim();
    return name == null || name.isEmpty || name.contains('@') ? null : 'by $name';
  }

  static String _tintKey(Color tint) => 'tint-${tint.rgbHex}';

  static final RegExp _savedTintKey = RegExp(r'_(tint-[0-9a-f]{6})(?: \(\d+\))?$');

  /// The colour key in the name of a tinted wallpaper saved from this screen, so a reopened file is that variation.
  static String? _savedTintKeyOf(String path) => _savedTintKey.firstMatch(downloadBaseName(path))?.group(1);

  Widget _buildActionBar(BuildContext context, WallpaperDetailLoaded state) {
    final entity = state.entity;
    final url = entity.fullUrl;
    final String previewTitle = wallpaperPreviewTitle(entity);
    final File? localFile = widget.localFile;
    final String source = localFile?.path ?? url;
    final Future<String> Function()? localSource = localFile == null ? null : () async => localFile.path;
    final Color? tint = state.tint;
    final double deviceLongSidePx = _screenPixels(context).longestSide;
    Future<String> Function()? prepareSource;
    DownloadVariant? variant;
    if (tint != null) {
      prepareSource = () => renderTintedWallpaper(
        source: source,
        tint: tint,
        deviceLongSidePx: deviceLongSidePx,
        wallpaperId: entity.id,
        wallpaperSource: entity.source,
      );
      variant = DownloadVariant(key: _tintKey(tint), prepare: prepareSource);
    } else if (localFile != null) {
      final String? savedKey = _savedTintKeyOf(localFile.path);
      if (savedKey != null) variant = DownloadVariant(key: savedKey, prepare: () async => localFile.path);
    }
    // The round icon buttons press-scale themselves. Only the labelled pill needs the wrapper.
    Widget downloadButton({String? label}) {
      final Widget button = DownloadButton(
        label: label,
        link: url,
        variant: variant,
        isPremiumContent: isPremiumFeedItem(entity, app_state.premiumCollections),
        contentId: entity.id,
        wallpaperSource: entity.source,
        sourceContext: _getSourceContext(state),
        requestId: widget.requestId,
        onDownloaded: () {
          _recordTaste(TasteAction.download, entity);
        },
      );
      return label == null ? button : PressScale(child: button);
    }

    final primary = hideSetWallpaperUi
        ? WallpaperBarAction(
            label: 'Save to Photos',
            child: downloadButton(label: 'Save'),
          )
        : WallpaperBarAction(
            label: 'Set as wallpaper',
            child: PressScale(
              child: SetWallpaperButton(
                label: 'Set',
                url: source,
                wallpaperId: entity.id,
                wallpaperSource: entity.source,
                prepareSource: prepareSource,
                thumbnailUrl: entity.thumbnailUrl,
                promptNotificationPermissionOnSuccess: true,
                entryPoint: 'wallpaper_detail',
                requestId: widget.requestId,
                notes: wallpaperResolutionNotes(entity.wallpaperCore, _screenPixels(context)),
                onMatchAccent: _matchAccentAction(context, state),
                onSet: () => _onWallpaperSet(entity),
              ),
            ),
          );
    return WallpaperActionBar(
      primary: primary,
      actions: [
        if (!hideSetWallpaperUi) WallpaperBarAction(label: 'Download', child: downloadButton()),
        WallpaperBarAction(
          label: 'Favourite',
          child: PressScale(
            child: FavouriteWallpaperButton(
              wall: FavouriteWallEntity.fromFeedItem(entity),
              trash: false,
              onFavourited: () => _recordTaste(TasteAction.favourite, entity),
            ),
          ),
        ),
        WallpaperBarAction(
          label: 'Share',
          child: ShareButton(
            id: entity.id,
            source: entity.source,
            url: entity.fullUrl,
            thumbUrl: entity.thumbnailUrl,
            contextLine: _shareContextLine(entity),
            createLink: (id, source, url, thumbUrl) =>
                createDynamicLink(id, source, url, thumbUrl, title: previewTitle, core: entity.wallpaperCore),
          ),
        ),
        WallpaperBarAction(
          label: 'Edit',
          child: EditButton(
            url: entity.fullUrl,
            wallpaperId: entity.id,
            wallpaperSource: entity.source,
            prepareSource: prepareSource ?? localSource,
          ),
        ),
      ],
    );
  }

  /// Opens Make it live. The first palette colour seeds its gradients, so they follow this wallpaper.
  Future<void> _openMakeItLive(BuildContext context, WallpaperDetailLoaded state) async {
    final entity = state.entity;
    String imageUrl = entity.fullUrl;
    try {
      imageUrl = (await WallpaperService.resolveToLocalFile(
        entity.fullUrl,
        allowNetwork: false,
        wallpaperId: entity.id,
        wallpaperSource: entity.source,
      )).path;
    } catch (_) {}
    if (context.mounted) {
      await context.router.push(LiveWallpaperRoute(imageUrl: imageUrl, accentSeed: state.colors?.firstOrNull));
    }
  }

  Size _screenPixels(BuildContext context) {
    final Size px = MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
    return Size(px.shortestSide, px.longestSide);
  }

  void _onWallpaperSet(FeedItemEntity entity) {
    _recordTaste(TasteAction.set, entity);
    if (shouldRecordWallpaperSetStats(entity)) {
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

  List<Widget> _buildPanelExtras(BuildContext context, WallpaperDetailLoaded state) {
    final entity = state.entity;
    final theme = Theme.of(context);
    final tags = wallpaperTags(entity);
    final notes = wallpaperResolutionNotes(entity.wallpaperCore, _screenPixels(context));
    final bool canBlock = canBlockWallCreator(entity);
    final String? reportWallDocId = BundledWallpapers.isStarter(entity)
        ? null
        : switch (entity) {
            PrismFeedItem(:final wallpaper) => wallpaper.firestoreDocumentId,
            _ => null,
          };
    const gap = SizedBox(height: 12);
    Widget padded(Widget child) =>
        Padding(padding: const EdgeInsets.fromLTRB(_sheetHPad, 0, _sheetHPad, 12), child: child);
    return [
      for (final note in notes)
        padded(
          Row(
            children: [
              Icon(JamIcons.alert, size: 18, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(note, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary)),
              ),
            ],
          ),
        ),
      if (tags.isNotEmpty) padded(WallpaperTagChips(tags: tags, onTagTap: (tag) => openTagSearch(context, tag))),
      if (!hideSetWallpaperUi && entity.fullUrl.trim().isNotEmpty)
        padded(
          Align(
            alignment: Alignment.centerLeft,
            child: MakeItLiveButton(onPressed: () => _openMakeItLive(context, state)),
          ),
        ),
      if (entity case PrismFeedItem(:final wallpaper) when canBoostWall(wallpaper))
        padded(PrismGroup(children: <Widget>[BoostWallRow(wall: wallpaper)])),
      padded(
        SimilarWallpapersStrip(
          entity: entity,
          loader: _similarLoader.load,
          onOpen: (item) => context.router.push(WallpaperDetailRoute(entity: item, thumbnailUrl: item.thumbnailUrl)),
        ),
      ),
      if (reportWallDocId != null && reportWallDocId.isNotEmpty)
        padded(
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              children: [
                TextButton.icon(
                  onPressed: () => showContentReportSheet(
                    context,
                    contentType: 'wall',
                    targetFirestoreDocId: reportWallDocId,
                    subtitle: entity.id,
                    onBlockCreator: canBlock ? () => unawaited(blockWallCreator(context, entity)) : null,
                  ),
                  icon: Icon(JamIcons.flag, size: 20, color: theme.colorScheme.secondary),
                  label: Text('Report', style: TextStyle(color: theme.colorScheme.secondary)),
                ),
                if (canBlock)
                  TextButton.icon(
                    onPressed: () => unawaited(blockWallCreator(context, entity)),
                    icon: Icon(JamIcons.user_remove, size: 20, color: theme.colorScheme.secondary),
                    label: Text('Block creator', style: TextStyle(color: theme.colorScheme.secondary)),
                  ),
              ],
            ),
          ),
        ),
      gap,
    ];
  }

  Widget _buildImageBody(
    BuildContext context,
    bool paletteLoading,
    WallpaperDetailLoaded state,
    _PanelGeometry geometry,
  ) {
    final entity = state.entity;
    final topPad = _topOverlayPadding(context);
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
                  if (details.delta.dy < -10) panelController.open();
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
                      _buildProgressiveWallpaperImage(
                        context: context,
                        entity: entity,
                        state: state,
                        paletteLoading: paletteLoading,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        ValueListenableBuilder<double>(
          valueListenable: _panelPosition,
          builder: (BuildContext context, double position, Widget? _) => Positioned(
            left: geometry.left,
            right: geometry.right,
            bottom: geometry.bottom,
            height: geometry.heightAt(position),
            child: IgnorePointer(
              child: _GlassShadow(
                radius: _panelRadius,
                shadow: Theme.of(context).brightness == Brightness.light ? _shadowLight : _shadowDark,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(_chromePad, topPad, _chromePad, _chromePad),
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () {
                _trackAction(state, AnalyticsActionValue.backTapped);
                Navigator.pop(context);
              },
              color: _chromeColor(context, paletteLoading, state),
              icon: const Icon(JamIcons.chevron_left),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(_chromePad, topPad, _chromePad, _chromePad),
            child: IconButton(
              tooltip: 'Clock preview',
              onPressed: () {
                _trackAction(state, AnalyticsActionValue.clockOverlayOpened);
                pushClockPreview(
                  context,
                  link: widget.localFile?.path ?? entity.fullUrl,
                  file: widget.localFile != null,
                  wallpaperId: entity.id,
                  wallpaperSource: entity.source,
                  thumbnailUrl: entity.thumbnailUrl,
                  tint: state.tint,
                );
              },
              color: _chromeColor(context, paletteLoading, state),
              icon: const Icon(JamIcons.clock),
            ),
          ),
        ),
        if (!hideSetWallpaperUi && entity.fullUrl.trim().isNotEmpty)
          ValueListenableBuilder<double>(
            valueListenable: _panelPosition,
            child: MakeItLiveChip(onPressed: () => _openMakeItLive(context, state)),
            builder: (BuildContext context, double position, Widget? chip) => Positioned(
              left: geometry.left + _sheetHPad,
              bottom:
                  geometry.bottom +
                  geometry.heightAt(position) +
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

  /// Thumbnail first, then the full image on top. The spinner lives outside this subtree.
  Widget _buildProgressiveWallpaperImage({
    required BuildContext context,
    required FeedItemEntity entity,
    required WallpaperDetailLoaded state,
    required bool paletteLoading,
  }) {
    final String thumb = entity.thumbnailUrl.trim();
    final String full = entity.fullUrl.trim();
    final int cacheWidth = previewCacheWidth(MediaQuery.sizeOf(context).width, MediaQuery.devicePixelRatioOf(context));
    final bool fullIsNetwork = isValidNetworkUrl(full);
    final bool thumbIsNetwork = isValidNetworkUrl(thumb);
    final bool useProgressive = thumbIsNetwork && fullIsNetwork && full != thumb;

    Widget imageLayer;
    final File? localFile = widget.localFile;
    if (localFile != null) {
      imageLayer = Image.file(
        localFile,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) =>
            const GlintState(kind: GlintStateKind.error, title: 'Downloaded wallpaper is unavailable'),
      );
    } else if (full.startsWith('assets/')) {
      imageLayer = Image.asset(
        full,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) =>
            Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state))),
      );
    } else if (!fullIsNetwork && full.isNotEmpty) {
      final Uri? uri = Uri.tryParse(full);
      final String path = uri?.scheme == 'file' ? uri!.toFilePath() : full;
      imageLayer = Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) =>
            Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state))),
      );
    } else if (useProgressive) {
      imageLayer = Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            cacheManager: PrismImageCache.instance,
            imageUrl: thumb,
            memCacheWidth: cacheWidth,
            fadeInDuration: context.motion(const Duration(milliseconds: 180)),
            fadeOutDuration: context.motion(const Duration(milliseconds: 180)),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(color: Theme.of(context).primaryColor),
            errorWidget: (context, url, error) {
              return Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state)));
            },
          ),
          CachedNetworkImage(
            cacheManager: PrismFullImageCache.instance,
            imageUrl: full,
            memCacheWidth: cacheWidth,
            fit: BoxFit.cover,
            fadeInDuration: context.motion(const Duration(milliseconds: 280)),
            fadeOutDuration: Duration.zero,
            imageBuilder: (context, imageProvider) {
              return SizedBox.expand(
                child: Image(image: imageProvider, fit: BoxFit.cover),
              );
            },
            progressIndicatorBuilder: (context, url, downloadProgress) => const SizedBox.shrink(),
            errorWidget: (context, url, error) {
              return const SizedBox.shrink();
            },
          ),
        ],
      );
    } else {
      final String url = fullIsNetwork ? full : thumb;
      if (url.isEmpty) {
        imageLayer = Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state)));
      } else {
        imageLayer = CachedNetworkImage(
          cacheManager: fullIsNetwork ? PrismFullImageCache.instance : PrismImageCache.instance,
          imageUrl: url,
          memCacheWidth: cacheWidth,
          fadeInDuration: context.motion(const Duration(milliseconds: 180)),
          fadeOutDuration: context.motion(const Duration(milliseconds: 180)),
          imageBuilder: (context, imageProvider) {
            return SizedBox.expand(
              child: Image(image: imageProvider, fit: BoxFit.cover),
            );
          },
          progressIndicatorBuilder: (context, url, downloadProgress) => const SizedBox.shrink(),
          errorWidget: (context, url, error) {
            return Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state)));
          },
        );
      }
    }

    final Widget offlineAwareImage = localFile != null || full.isEmpty || !fullIsNetwork
        ? imageLayer
        : FutureBuilder<File?>(
            future: _offlinePreviewFor(entity),
            builder: (BuildContext context, AsyncSnapshot<File?> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return imageLayer;
              }
              final File? retained = snapshot.data;
              if (retained == null || !retained.existsSync()) return imageLayer;
              return Image.file(
                retained,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                errorBuilder: (_, _, _) => imageLayer,
              );
            },
          );

    return SizedBox.expand(
      child: _HueTint(
        tint: state.tint,
        duration: context.motion(const Duration(milliseconds: 220)),
        child: offlineAwareImage,
      ),
    );
  }

  Future<File?> _offlinePreviewFor(FeedItemEntity entity) {
    final String url = entity.fullUrl.trim();
    final String key = '${entity.source.wireValue}\u0000${entity.id}\u0000$url';
    if (_offlinePreviewKey != key) {
      _offlinePreviewKey = key;
      _offlinePreviewFuture = WallpaperService.resolveToLocalFile(
        url,
        allowNetwork: false,
        wallpaperId: entity.id,
        wallpaperSource: entity.source,
      ).then<File?>((File file) => file).catchError((Object _) => null);
    }
    return _offlinePreviewFuture ?? Future<File?>.value();
  }

  Color _chromeColor(BuildContext context, bool paletteLoading, WallpaperDetailLoaded state) {
    if (paletteLoading) return Theme.of(context).colorScheme.secondary;
    final accent = state.accent;
    return accent == null ? Colors.white : onColor(accent);
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    if (now.difference(local).inDays < 7) return timeago.format(local);
    return DateFormat(local.year == now.year ? 'd MMM' : 'd MMM y').format(local);
  }
}

/// Where the glass sits on the screen and how tall it is at each panel position.
class _PanelGeometry extends Equatable {
  const _PanelGeometry({
    required this.collapsed,
    required this.open,
    required this.left,
    required this.right,
    required this.bottom,
  });

  /// Glass height with the panel closed and open.
  final double collapsed;
  final double open;

  /// Distance from the screen edge to the glass edge: the safe area plus the inset.
  final double left;
  final double right;
  final double bottom;

  double heightAt(double position) => collapsed + (open - collapsed) * position;

  @override
  List<Object?> get props => [collapsed, open, left, right, bottom];
}

/// A soft shadow in the shape of the glass, painted outside it only. Inside, the glass blurs whatever is behind it, and
/// a shadow there would darken the icons' backdrop.
class _GlassShadow extends StatelessWidget {
  const _GlassShadow({required this.radius, required this.shadow});

  final double radius;
  final BoxShadow shadow;

  @override
  Widget build(BuildContext context) {
    final ShapeBorder shape = RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));
    return ClipPath(
      clipper: _OutsideShapeClipper(shape),
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: shape, shadows: [shadow]),
      ),
    );
  }
}

class _OutsideShapeClipper extends CustomClipper<Path> {
  _OutsideShapeClipper(this.shape);

  final ShapeBorder shape;

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Rect.fromLTWH(-200, -200, size.width + 400, size.height + 400)),
    shape.getOuterPath(Offset.zero & size),
  );

  @override
  bool shouldReclip(_OutsideShapeClipper oldClipper) => oldClipper.shape != shape;
}

/// The tint [t] of the way from [a] to [b]. Colours blend in HSL space and the hue takes the short way round. A blend in
/// RGB passes through grey between opposite hues, and a grey tint takes the colour out of the wallpaper. With no tint
/// at one end, the other fades in or out.
@visibleForTesting
Color? lerpHueTint(Color? a, Color? b, double t) {
  if (a == null || b == null) return Color.lerp(a, b, t);
  final HSLColor from = HSLColor.fromColor(a);
  final HSLColor to = HSLColor.fromColor(b);
  final double sweep = ((to.hue - from.hue + 540) % 360) - 180;
  return HSLColor.fromAHSL(
    lerpDouble(from.alpha, to.alpha, t)!,
    (from.hue + sweep * t) % 360,
    lerpDouble(from.saturation, to.saturation, t)!,
    lerpDouble(from.lightness, to.lightness, t)!,
  ).toColor();
}

class _HueTintTween extends Tween<Color?> {
  _HueTintTween({super.begin, super.end});

  @override
  Color? lerp(double t) => lerpHueTint(begin, end, t);
}

/// Shows [child] with the hue of [tint]. A new tint slides over from the one on screen, and no tint fades the hue out.
class _HueTint extends StatefulWidget {
  const _HueTint({required this.tint, required this.duration, required this.child});

  final Color? tint;
  final Duration duration;
  final Widget child;

  @override
  State<_HueTint> createState() => _HueTintState();
}

class _HueTintState extends State<_HueTint> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)..value = 1;
  late _HueTintTween _tween = _HueTintTween(begin: widget.tint, end: widget.tint);

  Color? get _shown => _tween.transform(Curves.easeOutCubic.transform(_controller.value));

  @override
  void didUpdateWidget(_HueTint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tint == widget.tint) return;
    _tween = _HueTintTween(begin: _shown, end: widget.tint);
    _controller
      ..duration = widget.duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: RepaintBoundary(child: widget.child),
      builder: (BuildContext context, Widget? child) {
        final Color? tint = _shown;
        return tint == null ? child! : ColorFiltered(colorFilter: ColorFilter.mode(tint, BlendMode.hue), child: child);
      },
    );
  }
}
