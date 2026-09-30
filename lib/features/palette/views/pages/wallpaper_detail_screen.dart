import 'dart:async';
import 'dart:math' show min;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/format_utils.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/palette/domain/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/palette/domain/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/palette/domain/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/palette/views/widgets/accent_contrast.dart';
import 'package:Prism/features/palette/views/widgets/clock_overlay.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:timeago/timeago.dart' as timeago;

@RoutePage()
class WallpaperDetailScreen extends StatefulWidget {
  const WallpaperDetailScreen({
    super.key,
    this.entity,
    this.wallId,
    this.source,
    this.thumbnailUrl,
    this.analyticsSurface = AnalyticsSurfaceValue.wallpaperScreen,
  }) : assert(entity != null || (wallId != null && source != null), 'Either entity or wallId+source must be provided');

  final WallpaperDetailEntity? entity;
  final String? wallId;
  final WallpaperSource? source;
  final String? thumbnailUrl;
  final AnalyticsSurfaceValue analyticsSurface;

  @override
  State<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends State<WallpaperDetailScreen> with SingleTickerProviderStateMixin {
  static const double _sheetHPad = 24.0;
  static const double _panelSideInset = 10.0;
  static const double _panelTopRadius = 20.0;
  static const double _chromePad = 8.0;
  static const double _minInteractiveTarget = 48.0;

  late AnimationController shakeController;
  late Animation<double> _offsetAnimation;
  PanelController panelController = PanelController();
  bool _accentToastShown = false;

  /// Identity for the wallpaper currently shown; resets [_wallpaperImageShown] when it changes.
  String? _wallpaperLoadIdentity;
  bool _wallpaperImageShown = false;

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

  void _syncWallpaperIdentity(WallpaperDetailEntity entity) {
    final key = '${entity.id}|${entity.fullUrl}|${entity.thumbnailUrl}';
    if (_wallpaperLoadIdentity != key) {
      _wallpaperLoadIdentity = key;
      _wallpaperImageShown = false;
    }
  }

  void _scheduleWallpaperDisplayReady() {
    if (_wallpaperImageShown) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _wallpaperImageShown) return;
      setState(() => _wallpaperImageShown = true);
    });
  }

  void _handlePanelClosed(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const OnPanelClosed());
    _trackAction(state, AnalyticsActionValue.panelClosed);
  }

  void _handleAccentTap(BuildContext context, WallpaperDetailLoaded state) {
    final colors = state.colors;
    final accent = state.accent;

    if (colors == null || colors.isEmpty || !colors.contains(accent)) return;

    context.read<WallpaperDetailBloc>().add(const CycleAccentColor());
    _setStatusBarIconBrightness(state.accent ?? Colors.white);
    _trackAction(state, AnalyticsActionValue.paletteCycleTapped);

    if (!_accentToastShown) {
      toasts.codeSend('Long press to reset');
      _accentToastShown = true;
    }
  }

  void _handleAccentLongPress(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const ResetAccentColor());
    _trackAction(state, AnalyticsActionValue.paletteResetLongPressed);
    HapticFeedback.vibrate();
    if (!MediaQuery.disableAnimationsOf(context)) {
      shakeController.forward(from: 0.0);
    }
  }

  void _handleColorSelected(BuildContext context, WallpaperDetailLoaded state, Color color) {
    context.read<WallpaperDetailBloc>().add(SelectAccentColor(color: color));
    _setStatusBarIconBrightness(color);
  }

  void _setStatusBarIconBrightness(Color color) {
    applyEdgeToEdgeOverlayStyle(
      statusBarIconBrightness: onColor(color) == Colors.black ? Brightness.dark : Brightness.light,
    );
  }

  @override
  void initState() {
    super.initState();
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _offsetAnimation =
        Tween(begin: 0.0, end: 48.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) shakeController.reverse();
          });

    _loadWallpaper(context);
  }

  @override
  void dispose() {
    shakeController.dispose();
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
    return inset + _chromePad;
  }

  FavouriteWallEntity _toFavouriteWall(WallpaperDetailEntity entity) {
    return entity.when(
      prism: (wallpaper) => PrismFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
      wallhaven: (wallpaper) => WallhavenFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
      pexels: (wallpaper) => PexelsFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WallpaperDetailBloc, WallpaperDetailState>(
      listener: (context, state) {
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

  Widget _buildLoadingState(WallpaperDetailState state) {
    final thumbnailUrl = state is WallpaperDetailLoading ? state.thumbnailUrl : widget.thumbnailUrl;
    final spinner = Center(
      child: Semantics(label: 'Loading wallpaper', child: const CircularProgressIndicator()),
    );

    if (thumbnailUrl == null || thumbnailUrl.isEmpty) return Scaffold(body: spinner);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (ctx, _) => Container(color: Theme.of(ctx).primaryColor),
            errorWidget: (ctx, _, _) => Container(color: Theme.of(ctx).primaryColor),
          ),
          spinner,
        ],
      ),
    );
  }

  Widget _buildErrorState(WallpaperDetailError state) {
    final scheme = Theme.of(context).colorScheme;
    final message = state.message.trim();
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'Error',
                child: Icon(Icons.error_outline, size: 64, color: scheme.error),
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Please try again later',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(onPressed: () => _loadWallpaper(context), child: const Text('Try again')),
              const SizedBox(height: 4),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go back')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, WallpaperDetailLoaded state) {
    final paletteLoading = state.paletteLoading;

    return Scaffold(
      backgroundColor: paletteLoading ? Theme.of(context).primaryColor : state.accent,
      body: SlidingUpPanel(
        onPanelOpened: () => _handlePanelOpened(context, state),
        onPanelClosed: () => _handlePanelClosed(context, state),
        // No backdropEnabled: its invisible backdrop covered Back and Clock while the panel was open.
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_panelTopRadius),
          topRight: Radius.circular(_panelTopRadius),
        ),
        boxShadow: const [],
        minHeight: MediaQuery.of(context).size.height / 20,
        parallaxEnabled: true,
        parallaxOffset: 0,
        color: Colors.transparent,
        maxHeight: MediaQuery.of(context).size.height * 0.43,
        controller: panelController,
        panel: _buildInfoPanel(context, state),
        body: _buildImageBody(context, paletteLoading, state),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context, WallpaperDetailLoaded state) {
    final entity = state.entity;
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    final size = Size(w - _panelSideInset * 2, h * 0.43);

    return Container(
      margin: const EdgeInsets.fromLTRB(_panelSideInset, 0, _panelSideInset, _panelSideInset),
      height: size.height,
      width: size.width,
      child: LiquidGlassLayer(
        settings: LiquidGlassSettings(
          thickness: 40,
          ambientStrength: 0.2,
          blur: 4,
          glassColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
        fake: defaultTargetPlatform != TargetPlatform.iOS,
        child: LiquidGlass(
          shape: const LiquidRoundedSuperellipse(borderRadius: 56),
          child: SizedBox(
            height: size.height,
            width: size.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCollapseHandle(context, state),
                _buildColorBar(context, state),
                Expanded(
                  flex: 8,
                  child: SingleChildScrollView(
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
                      child: _buildMetadataRow(context, entity, state),
                    ),
                  ),
                ),
                _buildActionButtons(context, state),
                const SizedBox(height: _sheetHPad),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseHandle(BuildContext context, WallpaperDetailLoaded state) {
    final isCollapsed = state.panelCollapsed;
    return Center(
      child: Semantics(
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _minInteractiveTarget, minHeight: _minInteractiveTarget),
            child: Center(
              child: Icon(
                isCollapsed ? JamIcons.chevron_up : JamIcons.chevron_down,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorBar(BuildContext context, WallpaperDetailLoaded state) {
    final colors = state.colors;
    final thumbnailUrl = state.entity.thumbnailUrl.trim();

    // Build the default (no-filter) swatch + one swatch per palette color.
    final swatches = <Widget>[
      _buildColorSwatch(
        context: context,
        thumbnailUrl: thumbnailUrl,
        color: null,
        isSelected: !state.colorChanged,
        onTap: () {
          context.read<WallpaperDetailBloc>().add(const ResetAccentColor());
          _setStatusBarIconBrightness(state.accent ?? Colors.white);
        },
        onLongPress: null,
      ),
      for (final color in colors ?? const <Color>[])
        _buildColorSwatch(
          context: context,
          thumbnailUrl: thumbnailUrl,
          color: color,
          isSelected: state.colorChanged && color == state.accent,
          onTap: () => _handleColorSelected(context, state, color),
          onLongPress: () {
            HapticFeedback.vibrate();
            Clipboard.setData(ClipboardData(text: '#${color.rgbHex.toUpperCase()}')).then((_) => toasts.color(color));
          },
        ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _sheetHPad, vertical: 8),
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
    required Color? color,
    required bool isSelected,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
  }) {
    final label = color == null ? 'Original wallpaper colors' : 'Accent color';
    final hint = color == null ? null : 'Long press to copy hex color';
    return Semantics(
      button: onTap != null,
      selected: isSelected,
      label: label,
      hint: hint,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                imageBuilder: (ctx, imageProvider) => Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.hue) : null,
                    ),
                    border: Border(bottom: BorderSide(color: color ?? Theme.of(ctx).colorScheme.secondary, width: 8)),
                  ),
                ),
                placeholder: (_, u) =>
                    Container(color: color ?? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)),
                errorWidget: (_, u, e) =>
                    Container(color: color ?? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)),
              )
            else
              Container(color: color ?? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)),
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

  Widget _buildMetadataRow(BuildContext context, WallpaperDetailEntity entity, WallpaperDetailLoaded state) {
    return entity.when(
      prism: (wallpaper) => _buildPrismMetadata(context, wallpaper, state),
      wallhaven: (wallpaper) => _buildWallhavenMetadata(context, wallpaper),
      pexels: (wallpaper) => _buildPexelsMetadata(context, wallpaper),
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
    final collections = wallpaper.collections;
    final category = wallpaper.core.category;
    final resolution = wallpaper.core.resolution;
    final sizeBytes = wallpaper.core.sizeBytes;
    final createdAt = wallpaper.core.createdAt;
    return _metadataShell(
      left: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Text(
                wallpaper.id.toUpperCase(),
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: secondary),
              ),
              if (state.views != null) ...[
                divider,
                Text(
                  "${state.views} views",
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: secondary.withValues(alpha: 0.7)),
                ),
              ] else if (state.viewsLoading) ...[
                divider,
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(secondary)),
                ),
              ],
            ],
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
              onTap: () => context.router.push(ProfileRoute(profileIdentifier: profileIdentifier)),
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
                        toasts.codeSend('Could not open profile');
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
    final iconWidget = Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7));
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

  Widget _buildActionButtons(BuildContext context, WallpaperDetailLoaded state) {
    final entity = state.entity;
    final url = entity.fullUrl;
    final List<Widget> actions = <Widget>[
      _SheetActionTapScale(
        child: DownloadButton(colorChanged: state.colorChanged, link: url, sourceContext: _getSourceContext(state)),
      ),
      if (!hideSetWallpaperUi)
        _SheetActionTapScale(
          child: SetWallpaperButton(
            colorChanged: state.colorChanged,
            url: url,
            promptNotificationPermissionOnSuccess: true,
          ),
        ),
      _SheetActionTapScale(child: FavouriteWallpaperButton(wall: _toFavouriteWall(entity), trash: false)),
      _SheetActionTapScale(
        child: ShareButton(id: entity.id, source: entity.source, url: entity.fullUrl, thumbUrl: entity.thumbnailUrl),
      ),
      _SheetActionTapScale(child: EditButton(url: entity.fullUrl)),
    ];
    final String? reportWallDocId = switch (entity) {
      PrismDetailEntity(:final wallpaper) => wallpaper.firestoreDocumentId,
      _ => null,
    };
    if (reportWallDocId != null && reportWallDocId.isNotEmpty) {
      actions.insert(
        actions.length - 1,
        _SheetActionTapScale(
          child: CircularMenuButton(
            label: 'Report',
            isLoading: false,
            onTap: () => showContentReportSheet(
              context,
              contentType: 'wall',
              targetFirestoreDocId: reportWallDocId,
              subtitle: entity.id,
            ),
            child: Icon(JamIcons.flag, color: Theme.of(context).colorScheme.secondary, size: 20),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _sheetHPad),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: actions),
      ),
    );
  }

  Widget _buildImageBody(BuildContext context, bool paletteLoading, WallpaperDetailLoaded state) {
    final entity = state.entity;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final topPad = _topOverlayPadding(context);
    _syncWallpaperIdentity(entity);
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _offsetAnimation,
          builder: (context, child) {
            final t = reduceMotion ? 0.0 : _offsetAnimation.value;
            return Semantics(
              label: 'Wallpaper',
              hint: 'Tap to cycle accent color. Long press to reset. Swipe up for details.',
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (details.delta.dy < -10) panelController.open();
                },
                onLongPress: () => _handleAccentLongPress(context, state),
                onTap: () {
                  HapticFeedback.vibrate();
                  if (!paletteLoading) _handleAccentTap(context, state);
                  if (!reduceMotion) shakeController.forward(from: 0.0);
                },
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: t * 1.25, horizontal: t / 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(t),
                    child: _buildProgressiveWallpaperImage(
                      context: context,
                      entity: entity,
                      state: state,
                      paletteLoading: paletteLoading,
                      onWallpaperDisplayReady: _scheduleWallpaperDisplayReady,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (!_wallpaperImageShown)
          Positioned.fill(
            child: Center(
              child: Semantics(
                label: 'Loading wallpaper',
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.secondary),
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
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) {
                      animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: ClockOverlay(
                          colorChanged: state.colorChanged,
                          accent: state.accent,
                          link: entity.fullUrl,
                          file: false,
                        ),
                      );
                    },
                    fullscreenDialog: true,
                    opaque: false,
                  ),
                );
              },
              color: _chromeColor(context, paletteLoading, state),
              icon: const Icon(JamIcons.clock),
            ),
          ),
        ),
      ],
    );
  }

  /// Thumbnail first, then the full image on top. The spinner lives outside this subtree;
  /// [onWallpaperDisplayReady] fires when the full bitmap is shown or an error/empty state is final.
  Widget _buildProgressiveWallpaperImage({
    required BuildContext context,
    required WallpaperDetailEntity entity,
    required WallpaperDetailLoaded state,
    required bool paletteLoading,
    VoidCallback? onWallpaperDisplayReady,
  }) {
    final String thumb = entity.thumbnailUrl.trim();
    final String full = entity.fullUrl.trim();
    final bool useProgressive = thumb.isNotEmpty && full.isNotEmpty && full != thumb;

    Widget imageLayer;
    if (useProgressive) {
      imageLayer = Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(color: Theme.of(context).primaryColor),
            errorWidget: (context, url, error) {
              onWallpaperDisplayReady?.call();
              return Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state)));
            },
          ),
          CachedNetworkImage(
            imageUrl: full,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 280),
            fadeOutDuration: Duration.zero,
            imageBuilder: (context, imageProvider) {
              onWallpaperDisplayReady?.call();
              return SizedBox.expand(
                child: Image(image: imageProvider, fit: BoxFit.cover),
              );
            },
            progressIndicatorBuilder: (context, url, downloadProgress) => const SizedBox.shrink(),
            errorWidget: (context, url, error) {
              onWallpaperDisplayReady?.call();
              return const SizedBox.shrink();
            },
          ),
        ],
      );
    } else {
      final String url = full.isNotEmpty ? full : thumb;
      if (url.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onWallpaperDisplayReady?.call();
        });
        imageLayer = Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state)));
      } else {
        imageLayer = CachedNetworkImage(
          imageUrl: url,
          imageBuilder: (context, imageProvider) {
            onWallpaperDisplayReady?.call();
            return SizedBox.expand(
              child: Image(image: imageProvider, fit: BoxFit.cover),
            );
          },
          progressIndicatorBuilder: (context, url, downloadProgress) => const SizedBox.shrink(),
          errorWidget: (context, url, error) {
            onWallpaperDisplayReady?.call();
            return Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state)));
          },
        );
      }
    }

    if (state.colorChanged && state.accent != null) {
      imageLayer = ColorFiltered(colorFilter: ColorFilter.mode(state.accent!, BlendMode.hue), child: imageLayer);
    }

    return SizedBox.expand(child: imageLayer);
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

/// Press feedback for the wallpaper sheet action row: scale only (no layout animation).
/// Skips motion when [MediaQuery.disableAnimations] is true (e.g. reduce motion).
class _SheetActionTapScale extends StatefulWidget {
  const _SheetActionTapScale({required this.child});

  final Widget child;

  @override
  State<_SheetActionTapScale> createState() => _SheetActionTapScaleState();
}

class _SheetActionTapScaleState extends State<_SheetActionTapScale> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 85),
    );
    _scale = Tween<double>(
      begin: 1,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (pressed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          final s = reduceMotion ? 1.0 : _scale.value;
          return Transform.scale(scale: s, filterQuality: FilterQuality.low, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
