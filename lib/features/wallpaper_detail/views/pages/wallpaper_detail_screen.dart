import 'dart:async';
import 'dart:io';
import 'dart:math' show min;
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
import 'package:Prism/core/utils/localized_relative_time.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/depth_tag.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/original_access_prompt.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart' show PrismGroup;

import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/biz/block_wall_creator.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/data/wallpaper_tint_renderer.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/boost_wall_row.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/depth_effect_row.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_recommendations.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_tag_chips.dart';
import 'package:Prism/l10n/l10n.dart';

import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

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

  /// Text and icons in the panel that sit one step below the title.
  static const double _secondaryAlpha = 0.85;

  static const double _chromePad = 8.0;

  /// "Set N times" shows from this count, so a small number never reads as a poor wallpaper.
  static const int _minSetCountShown = 5;

  final ShakeController _shake = ShakeController();
  final ScrollController _scroll = ScrollController();
  final Object _recommendationHeroScope = Object();
  double _imageStatusBoundary = double.infinity;
  bool _imageBehindStatusBar = true;

  void _loadMoreRecommendations() {
    context.read<WallpaperDetailBloc>().add(LoadRecommendations(discoveryOnly: widget.localFile != null));
  }

  void _onDiscoveryScroll() {
    if (_scroll.hasClients) {
      final imageBehindStatusBar = _scroll.offset < _imageStatusBoundary;
      if (imageBehindStatusBar != _imageBehindStatusBar) {
        setState(() => _imageBehindStatusBar = imageBehindStatusBar);
      }
    }
    final state = context.read<WallpaperDetailBloc>().state;
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 600 &&
        state is WallpaperDetailLoaded &&
        !state.recommendations.loading &&
        !state.recommendations.failed &&
        state.recommendations.hasMore) {
      _loadMoreRecommendations();
    }
  }

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
      toasts.success(context.l10n.wallpaperAccentResetHint, haptic: false);
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
    _scroll.addListener(_onDiscoveryScroll);
    _loadWallpaper(context);
  }

  @override
  void dispose() {
    _shake.dispose();
    _scroll.dispose();
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
        if (state is WallpaperDetailLoaded && !state.recommendations.started) {
          _loadMoreRecommendations();
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
            // Keep the destination Hero mounted while Prism resolves its canonical access policy.
            WallpaperDetailInitial() || WallpaperDetailLoading() when entity != null => _buildLoadedState(
              context,
              WallpaperDetailLoaded(entity: entity),
              canonicalLoading: true,
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
    final localFile = widget.localFile;
    final thumbnail = normalizeWallpaperThumbnailUrl(
      (state is WallpaperDetailLoading ? state.thumbnailUrl : widget.thumbnailUrl) ?? widget.entity?.thumbnailUrl ?? '',
    );
    final imageHeight = widget.entity == null
        ? MediaQuery.sizeOf(context).height * 0.62
        : _detailImageHeight(context, widget.entity!.wallpaperCore);
    final Widget image;
    if (localFile != null) {
      image = Image.file(
        localFile,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            GlintState(kind: GlintStateKind.error, title: context.l10n.wallpaperDownloadedWallpaperUnavailable),
      );
    } else if (thumbnail.isNotEmpty) {
      image = CachedNetworkImage(
        cacheManager: PrismImageCache.instance,
        imageUrl: thumbnail,
        fit: BoxFit.contain,
        fadeInDuration: context.motion(const Duration(milliseconds: 180)),
        fadeOutDuration: context.motion(const Duration(milliseconds: 180)),
        placeholder: (ctx, _) => Container(color: Theme.of(ctx).primaryColor),
        errorWidget: (ctx, _, _) => Container(color: Theme.of(ctx).primaryColor),
      );
    } else {
      image = GlintState(kind: GlintStateKind.loading, title: context.l10n.wallpaperLoadingWallpaper);
    }
    return Scaffold(
      body: Stack(
        children: [
          SizedBox(height: imageHeight, width: double.infinity, child: _withHero(image)),
          _pinnedBack(state),
        ],
      ),
    );
  }

  Widget _pinnedBack(WallpaperDetailState state) => PositionedDirectional(
    start: MediaQuery.paddingOf(context).left + _chromePad,
    top: _topOverlayPadding(context),
    child: Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () {
          _trackAction(state, AnalyticsActionValue.backTapped);
          Navigator.pop(context);
        },
        icon: const Icon(JamIcons.chevron_left),
      ),
    ),
  );

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
                    title: context.l10n.wallpaperOpenError,
                    body: switch (state.failure) {
                      WallpaperDetailLoadFailure.notFound => context.l10n.wallpaperDetailNotFound,
                      WallpaperDetailLoadFailure.unavailable => context.l10n.wallpaperCheckConnection,
                    },
                    actionLabel: context.l10n.wallpaperTryAgain,
                    onAction: () => _loadWallpaper(context),
                  ),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.wallpaperGoBack)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, WallpaperDetailLoaded state, {bool canonicalLoading = false}) {
    final theme = Theme.of(context);
    final imageHeight = _detailImageHeight(context, state.entity.wallpaperCore);
    _imageStatusBoundary = imageHeight - MediaQuery.paddingOf(context).top;
    _imageBehindStatusBar = !_scroll.hasClients || _scroll.offset < _imageStatusBoundary;
    final chromeBackground = _imageBehindStatusBar
        ? (state.paletteLoading ? theme.primaryColor : state.accent ?? theme.scaffoldBackgroundColor)
        : theme.scaffoldBackgroundColor;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: edgeToEdgeOverlayStyle(
        statusBarIconBrightness: onColor(chromeBackground) == Colors.black ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: canonicalLoading,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (canonicalLoading) return false;
                    if (notification is ScrollStartNotification) {
                      context.read<WallpaperDetailBloc>().add(const OnPanelScrollStart());
                    } else if (notification is ScrollEndNotification) {
                      context.read<WallpaperDetailBloc>().add(const OnPanelScrollEnd());
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    key: PageStorageKey<Object>(_recommendationHeroScope),
                    controller: _scroll,
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: imageHeight,
                          child: _buildImageBody(
                            context,
                            state.paletteLoading,
                            state,
                            canonicalLoading: canonicalLoading,
                          ),
                        ),
                      ),
                      if (canonicalLoading)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(_sheetHPad),
                            child: Column(
                              children: [
                                const LinearProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(context.l10n.wallpaperLoadingWallpaper),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: SafeArea(top: false, bottom: false, child: _buildActionBar(context, state)),
                        ),
                        SliverToBoxAdapter(
                          child: SafeArea(top: false, bottom: false, child: _buildColorBar(context, state)),
                        ),
                        SliverToBoxAdapter(
                          child: ListTile(
                            title: Text(
                              wallpaperPreviewTitle(context.l10n, state.entity),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              state.entity.source == WallpaperSource.wallhaven
                                  ? context.l10n.wallpaperProviderWallhaven
                                  : state.entity.source.legacyProviderString,
                            ),
                            trailing: IconButton(
                              tooltip: state.panelCollapsed
                                  ? context.l10n.wallpaperExpandDetails
                                  : context.l10n.wallpaperCollapseDetails,
                              icon: Icon(state.panelCollapsed ? Icons.expand_more : Icons.expand_less),
                              onPressed: () => _toggleDetails(context, state),
                            ),
                            onTap: () {
                              _toggleDetails(context, state);
                            },
                            contentPadding: const EdgeInsets.symmetric(horizontal: _sheetHPad),
                          ),
                        ),
                        if (!state.panelCollapsed)
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMetadataRow(context, state.entity, state),
                                ..._buildPanelExtras(context, state),
                              ],
                            ),
                          ),
                        WallpaperRecommendations(
                          state: state.recommendations,
                          heroScope: _recommendationHeroScope,
                          onLoadMore: _loadMoreRecommendations,
                          onOpen: (item, hero) => context.router.push(
                            WallpaperDetailRoute(entity: item, thumbnailUrl: item.thumbnailUrl, heroTag: hero),
                          ),
                        ),
                        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _pinnedBack(state),
          ],
        ),
      ),
    );
  }

  double _detailImageHeight(BuildContext context, WallpaperCore core) {
    final viewport = MediaQuery.sizeOf(context);
    final stableCore = widget.entity?.wallpaperCore ?? core;
    final width = stableCore.width;
    final height = stableCore.height;
    final parts = stableCore.resolution?.toLowerCase().split('x');
    final ratio = width != null && height != null && width > 0 && height > 0
        ? width / height
        : parts?.length == 2
        ? (double.tryParse(parts![0]) ?? 0) / (double.tryParse(parts[1]) ?? 1)
        : 9 / 16;
    final naturalHeight = viewport.width / (ratio.isFinite && ratio > 0 ? ratio : 9 / 16);
    return min(naturalHeight, viewport.height * 0.62);
  }

  void _toggleDetails(BuildContext context, WallpaperDetailLoaded state) {
    if (state.panelScrollInProgress) return;
    _trackAction(state, AnalyticsActionValue.panelCollapseTapped);
    state.panelCollapsed ? _handlePanelOpened(context, state) : _handlePanelClosed(context, state);
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
            final String copiedMessage = context.l10n.wallpaperDetailColorCodeCopied;
            Clipboard.setData(
              ClipboardData(text: '#${color.rgbHex.toUpperCase()}'),
            ).then((_) => toasts.color(color, message: copiedMessage));
          },
        ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(_sheetHPad, 0, _sheetHPad, 0),
      height: 44,
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
    final label = color == null ? context.l10n.wallpaperAccentColorsOriginal : context.l10n.wallpaperAccentColor;
    final placeholder = color ?? secondary.withValues(alpha: 0.1);
    final hint = color == null ? null : context.l10n.wallpaperCopyAccentHexHint;
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
                    wallpaperTitle(context.l10n, state.entity),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: secondary),
                  ),
                ),
                if (state.views != null) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      divider,
                      Flexible(
                        child: Text(switch (int.tryParse(state.views!)) {
                          final int views => context.l10n.wallpaperViewCount(views),
                          _ => context.l10n.wallpaperViewCountUnavailable,
                        }, style: dimmedHeadline),
                      ),
                    ],
                  ),
                ],
                if (state.setCount case final int sets when sets >= _minSetCountShown) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.views != null) divider else const SizedBox(width: 6),
                      Flexible(child: Text(context.l10n.wallpaperSetCount(sets), style: dimmedHeadline)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        PrismFavouriteCount(
          id: wallpaper.id,
          builder: (context, count) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildInfoRow(context, JamIcons.heart_f, '$count'),
          ),
        ),
        if (collections != null && collections.isNotEmpty) ...[
          _buildInfoRow(context, JamIcons.folder, collections.take(2).join(', ')),
          const SizedBox(height: 4),
        ],
        if (category != null) ...[_buildInfoRow(context, JamIcons.unordered_list, category), const SizedBox(height: 4)],
        if (resolution != null) ...[_buildInfoRow(context, JamIcons.set_square, resolution), const SizedBox(height: 4)],
        if (sizeBytes != null) _buildInfoRow(context, JamIcons.save, formatMegabytes(sizeBytes, context.l10n)),
      ],
      right: [
        _buildPrismAuthorRow(context, wallpaper),
        if (createdAt != null) ...[
          const SizedBox(height: 4),
          _buildInfoRow(
            context,
            JamIcons.calendar,
            _formatDate(createdAt, context.l10n, Localizations.localeOf(context)),
            reversed: true,
          ),
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
          _buildInfoRow(context, JamIcons.save, formatMegabytes(sizeBytes, context.l10n)),
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
        _buildInfoRow(context, JamIcons.database, context.l10n.wallpaperProviderWallhaven, reversed: true),
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
            alignment: AlignmentDirectional.centerEnd,
            child: uri == null
                ? label
                : InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!ok && context.mounted) {
                        toasts.error(context.l10n.wallpaperProfileOpenError);
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
    final String previewTitle = wallpaperPreviewTitle(context.l10n, entity);
    final File? localFile = widget.localFile;
    final DownloadedWallRef? localIdentity = localFile != null && getIt.isRegistered<DownloadedWallIndex>()
        ? getIt<DownloadedWallIndex>().resolve(localFile.path)
        : null;
    final WallpaperSource indexSource =
        localFile == null || (localIdentity?.id == entity.id && localIdentity?.source == entity.source)
        ? entity.source
        : WallpaperSource.downloaded;
    final String source = localFile?.path ?? url;
    final Future<String> Function()? localSource = localFile == null ? null : () async => localFile.path;
    final Color? tint = state.tint;
    final double deviceLongSidePx = _screenPixels(context).longestSide;
    Future<String> Function()? prepareSource;
    Future<String> Function(String)? prepareAuthorized;
    DownloadVariant? variant;
    if (tint != null) {
      prepareAuthorized = (authorized) => renderTintedWallpaper(
        source: authorized,
        tint: tint,
        deviceLongSidePx: deviceLongSidePx,
        wallpaperId: entity.id,
        wallpaperSource: entity.source,
      );
      prepareSource = () => prepareAuthorized!(source);
      variant = DownloadVariant(key: _tintKey(tint), prepare: prepareSource, prepareAuthorized: prepareAuthorized);
    } else if (localFile != null) {
      final String? savedKey = _savedTintKeyOf(localFile.path);
      if (savedKey != null) variant = DownloadVariant(key: savedKey, prepare: () async => localFile.path);
    }
    // The round icon buttons press-scale themselves. Only the labelled pill needs the wrapper.
    Widget downloadButton({String? label}) {
      final Widget button = DownloadButton(
        label: label,
        link: source,
        variant: variant,
        isPremiumContent: isPremiumFeedItem(entity, app_state.premiumCollections),
        contentId: entity.id,
        wallpaperSource: localFile == null ? entity.source : WallpaperSource.downloaded,
        indexSource: indexSource,
        savedIdentity: localFile != null && tint == null && getIt.isRegistered<DownloadedWallIndex>()
            ? getIt<DownloadedWallIndex>().acquiredIdentityForLocalFile(
                filePath: localFile.path,
                id: entity.id,
                source: indexSource,
              )
            : null,
        depthTier: depthTierOf(entity),
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
            label: context.l10n.wallpaperSaveToPhotos,
            child: downloadButton(label: context.l10n.wallpaperSave),
          )
        : WallpaperBarAction(
            label: context.l10n.wallpaperSetAsWallpaper,
            child: PressScale(
              child: SetWallpaperButton(
                label: context.l10n.wallpaperSet,
                url: source,
                wallpaperId: entity.id,
                wallpaperSource: localFile == null ? entity.source : WallpaperSource.downloaded,
                prepareSource: prepareSource,
                prepareAuthorized: prepareAuthorized,
                thumbnailUrl: entity.thumbnailUrl,
                promptNotificationPermissionOnSuccess: true,
                entryPoint: 'wallpaper_detail',
                requestId: widget.requestId,
                notes: wallpaperResolutionNotes(context.l10n, entity.wallpaperCore, _screenPixels(context)),
                onMatchAccent: _matchAccentAction(context, state),
                onSet: () => _onWallpaperSet(entity),
              ),
            ),
          );
    return WallpaperActionBar(
      primary: primary,
      actions: [
        if (!hideSetWallpaperUi) WallpaperBarAction(label: context.l10n.wallpaperDownload, child: downloadButton()),
        WallpaperBarAction(
          label: context.l10n.wallpaperFavourite,
          child: PressScale(
            child: FavouriteWallpaperButton(
              wall: FavouriteWallEntity.fromFeedItem(entity),
              trash: false,
              onFavourited: () => _recordTaste(TasteAction.favourite, entity),
            ),
          ),
        ),
        WallpaperBarAction(
          label: context.l10n.wallpaperShare,
          child: ShareButton(
            id: entity.id,
            source: entity.source,
            url: entity.fullUrl,
            thumbUrl: entity.thumbnailUrl,
            contextLine: _shareContextLine(entity),
            createLink: (id, source, url, thumbUrl) => createDynamicLink(
              id,
              source,
              url,
              thumbUrl,
              l10n: context.l10n,
              title: previewTitle,
              core: entity.wallpaperCore,
            ),
          ),
        ),
        WallpaperBarAction(
          label: context.l10n.wallpaperEdit,
          child: EditButton(
            url: source,
            wallpaperId: entity.id,
            wallpaperSource: localFile == null ? entity.source : WallpaperSource.downloaded,
            prepareSource: prepareSource ?? localSource,
            prepareAuthorized: prepareAuthorized,
          ),
        ),
      ],
    );
  }

  /// Opens Make it live. The first palette colour seeds its gradients, so they follow this wallpaper.
  Future<void> _openMakeItLive(BuildContext context, WallpaperDetailLoaded state) async {
    final entity = state.entity;
    String? imageUrl;
    try {
      imageUrl = await resolveOriginalWithConsent(
        context,
        url: widget.localFile?.path ?? entity.fullUrl,
        wallpaperId: entity.id,
        wallpaperSource: widget.localFile == null ? entity.source : WallpaperSource.downloaded,
        action: OriginalAccessAction.live,
        label: context.l10n.wallpaperMakeItLive,
      );
    } catch (_) {
      if (context.mounted) toasts.error(context.l10n.coreCouldNotLoadWallpaperForEditing);
      return;
    }
    if (context.mounted && imageUrl != null) {
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
    final notes = wallpaperResolutionNotes(context.l10n, entity.wallpaperCore, _screenPixels(context));
    final bool canBlock = canBlockWallCreator(entity);
    final WallDepthTier? depthTier = depthTierOf(entity);
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
      if (depthTier != null && showsDepthEffect(depthTier)) padded(DepthEffectRow(tier: depthTier)),
      if (!hideSetWallpaperUi && (entity.fullUrl.trim().isNotEmpty || entity.source == WallpaperSource.prism))
        padded(
          Align(
            alignment: Alignment.centerLeft,
            child: MakeItLiveButton(onPressed: () => _openMakeItLive(context, state)),
          ),
        ),
      if (entity case PrismFeedItem(:final wallpaper) when canBoostWall(wallpaper))
        padded(PrismGroup(children: <Widget>[BoostWallRow(wall: wallpaper)])),
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
                  label: Text(context.l10n.wallpaperReport, style: TextStyle(color: theme.colorScheme.secondary)),
                ),
                if (canBlock)
                  TextButton.icon(
                    onPressed: () => unawaited(blockWallCreator(context, entity)),
                    icon: Icon(JamIcons.user_remove, size: 20, color: theme.colorScheme.secondary),
                    label: Text(
                      context.l10n.wallpaperBlockCreator,
                      style: TextStyle(color: theme.colorScheme.secondary),
                    ),
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
    WallpaperDetailLoaded state, {
    bool canonicalLoading = false,
  }) {
    final entity = state.entity;
    final topPad = _topOverlayPadding(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ShakeOnce(
          controller: _shake,
          distance: 48,
          builder: (context, t, _) => WallpaperQuickActionRegion(
            item: entity,
            onResetOriginal: () => _handleAccentLongPress(context, state),
            preview: _buildProgressiveWallpaperImage(
              context: context,
              entity: entity,
              state: state,
              paletteLoading: paletteLoading,
              thumbnailOnly: canonicalLoading,
            ),
            child: Semantics(
              label: context.l10n.wallpaperImageSemanticLabel,
              hint: context.l10n.wallpaperImageSemanticHint,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!paletteLoading) _handleAccentTap(context, state);
                  _shake.shake();
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(t),
                  child: _withHero(
                    _buildProgressiveWallpaperImage(
                      context: context,
                      entity: entity,
                      state: state,
                      paletteLoading: paletteLoading,
                      thumbnailOnly: canonicalLoading,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!canonicalLoading)
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: Padding(
              padding: EdgeInsets.fromLTRB(_chromePad, topPad, _chromePad, _chromePad),
              child: IconButton(
                tooltip: context.l10n.wallpaperClockPreview,
                onPressed: () {
                  _trackAction(state, AnalyticsActionValue.clockOverlayOpened);
                  pushClockPreview(
                    context,
                    link:
                        widget.localFile?.path ??
                        (entity.source == WallpaperSource.prism ? entity.thumbnailUrl : entity.fullUrl),
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
        if (!canonicalLoading &&
            !hideSetWallpaperUi &&
            (entity.fullUrl.trim().isNotEmpty || entity.source == WallpaperSource.prism))
          PositionedDirectional(
            start: _sheetHPad,
            bottom: 8,
            child: MakeItLiveChip(onPressed: () => _openMakeItLive(context, state)),
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
    bool thumbnailOnly = false,
  }) {
    final String thumb = entity.thumbnailUrl.trim();
    final String full = thumbnailOnly
        ? thumb
        : wallpaperDetailPreviewUrl(entity, projectId: Firebase.apps.isEmpty ? null : Firebase.app().options.projectId);
    final int cacheWidth = previewCacheWidth(MediaQuery.sizeOf(context).width, MediaQuery.devicePixelRatioOf(context));
    final bool fullIsNetwork = isValidNetworkUrl(full);
    final bool thumbIsNetwork = isValidNetworkUrl(thumb);
    final bool useProgressive = thumbIsNetwork && fullIsNetwork && full != thumb;

    Widget imageLayer;
    final File? localFile = widget.localFile;
    if (localFile != null) {
      imageLayer = Image.file(
        localFile,
        fit: BoxFit.contain,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) =>
            GlintState(kind: GlintStateKind.error, title: context.l10n.wallpaperDownloadedWallpaperUnavailable),
      );
    } else if (full.startsWith('assets/')) {
      imageLayer = Image.asset(
        full,
        fit: BoxFit.contain,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) =>
            Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state))),
      );
    } else if (!fullIsNetwork && full.isNotEmpty) {
      final Uri? uri = Uri.tryParse(full);
      final String path = uri?.scheme == 'file' ? uri!.toFilePath() : full;
      imageLayer = Image.file(
        File(path),
        fit: BoxFit.contain,
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
            fit: BoxFit.contain,
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
            fit: BoxFit.contain,
            fadeInDuration: context.motion(const Duration(milliseconds: 280)),
            fadeOutDuration: Duration.zero,
            imageBuilder: (context, imageProvider) {
              return SizedBox.expand(
                child: Image(image: imageProvider, fit: BoxFit.contain),
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
          cacheManager: fullIsNetwork && !thumbnailOnly ? PrismFullImageCache.instance : PrismImageCache.instance,
          imageUrl: url,
          memCacheWidth: cacheWidth,
          fadeInDuration: context.motion(const Duration(milliseconds: 180)),
          fadeOutDuration: context.motion(const Duration(milliseconds: 180)),
          imageBuilder: (context, imageProvider) {
            return SizedBox.expand(
              child: Image(image: imageProvider, fit: BoxFit.contain),
            );
          },
          progressIndicatorBuilder: (context, url, downloadProgress) => const SizedBox.shrink(),
          errorWidget: (context, url, error) {
            return Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state)));
          },
        );
      }
    }

    final Widget offlineAwareImage = thumbnailOnly || localFile != null || full.isEmpty || !fullIsNetwork
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
                fit: BoxFit.contain,
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
    if (entity.source == WallpaperSource.prism && !BundledWallpapers.isStarter(entity)) {
      return Future<File?>.value();
    }
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

  String _formatDate(DateTime date, AppLocalizations l10n, Locale locale) {
    final local = date.toLocal();
    final now = DateTime.now();
    if (now.difference(local).inDays < 7) {
      return localizedRelativeTime(l10n, local, locale: locale);
    }
    return (local.year == now.year ? DateFormat.MMMd(l10n.localeName) : DateFormat.yMMMd(l10n.localeName)).format(
      local,
    );
  }
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
