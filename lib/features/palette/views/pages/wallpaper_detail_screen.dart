import 'dart:async';
import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menuButton/editButton.dart';
import 'package:Prism/core/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/core/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/core/widgets/menuButton/shareButton.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/palette/domain/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/palette/domain/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/palette/domain/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/palette/palette.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

@RoutePage()
class WallpaperDetailScreen extends StatefulWidget {
  const WallpaperDetailScreen({
    super.key,
    this.entity,
    this.wallId,
    this.source,
    this.wallpaperUrl,
    this.thumbnailUrl,
    this.analyticsSurface = AnalyticsSurfaceValue.wallpaperScreen,
  }) : assert(entity != null || (wallId != null && source != null), 'Either entity or wallId+source must be provided');

  final WallpaperDetailEntity? entity;
  final String? wallId;
  final WallpaperSource? source;
  final String? wallpaperUrl;
  final String? thumbnailUrl;
  final AnalyticsSurfaceValue analyticsSurface;

  @override
  State<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends State<WallpaperDetailScreen> with SingleTickerProviderStateMixin {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  late AnimationController shakeController;
  late Animation<double> _offsetAnimation;
  ScreenshotController screenshotController = ScreenshotController();
  PanelController panelController = PanelController();
  int _toastFirstTime = 0;

  /// Identity for the wallpaper currently shown; resets capture readiness when it changes.
  String? _wallpaperLoadIdentity;
  int _wallpaperCaptureGeneration = 0;
  bool _wallpaperReadyForCapture = false;

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
    final bloc = context.read<WallpaperDetailBloc>();
    bloc.add(const OnPanelOpened());
    _trackAction(state, AnalyticsActionValue.panelOpened);

    if (state.panelClosed) {
      logger.d('Screenshot Starting');
      final gen = _wallpaperCaptureGeneration;
      unawaited(_captureWallpaperScreenshotWhenReady(context, bloc, gen));
    }
  }

  Future<void> _captureWallpaperScreenshotWhenReady(
    BuildContext context,
    WallpaperDetailBloc bloc,
    int captureGeneration,
  ) async {
    while (mounted && captureGeneration == _wallpaperCaptureGeneration && !_wallpaperReadyForCapture) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    if (!mounted || captureGeneration != _wallpaperCaptureGeneration) return;

    final current = bloc.state;
    if (current is! WallpaperDetailLoaded) return;

    final capture = current.colorChanged
        ? screenshotController.capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
        : _settingsLocal.get<bool>('optimisedWallpapers', defaultValue: true) == true
        ? screenshotController.capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
        : Future<Uint8List?>.value();

    try {
      final Uint8List? image = await capture;
      if (image != null && mounted && captureGeneration == _wallpaperCaptureGeneration) {
        bloc.add(CaptureScreenshot(imageBytes: image));
        logger.d('Screenshot Taken');
      }
    } catch (e, st) {
      logger.d('$e\n$st');
    }
  }

  void _syncWallpaperIdentity(WallpaperDetailEntity entity) {
    final key = '${entity.id}|${entity.fullUrl}|${entity.thumbnailUrl}';
    if (_wallpaperLoadIdentity != key) {
      _wallpaperLoadIdentity = key;
      _wallpaperCaptureGeneration++;
      _wallpaperReadyForCapture = false;
    }
  }

  void _scheduleWallpaperDisplayReady() {
    if (_wallpaperReadyForCapture) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _wallpaperReadyForCapture) return;
      setState(() => _wallpaperReadyForCapture = true);
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

    if (_toastFirstTime == 0) {
      toasts.codeSend("Long press to reset.");
      _toastFirstTime = 1;
    }
  }

  void _handleAccentLongPress(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const ResetAccentColor());
    _trackAction(state, AnalyticsActionValue.paletteResetLongPressed);
    HapticFeedback.vibrate();
    shakeController.forward(from: 0.0);
  }

  void _handleColorSelected(BuildContext context, WallpaperDetailLoaded state, Color color) {
    context.read<WallpaperDetailBloc>().add(SelectAccentColor(color: color));
    _setStatusBarIconBrightness(color);
  }

  void _setStatusBarIconBrightness(Color color) {
    if (color.computeLuminance() > 0.5) {
      applyEdgeToEdgeOverlayStyle(statusBarIconBrightness: Brightness.dark);
    } else {
      applyEdgeToEdgeOverlayStyle(statusBarIconBrightness: Brightness.light);
    }
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
    _contentLoadTracker.start();

    final bloc = context.read<WallpaperDetailBloc>();
    if (widget.entity != null) {
      bloc.add(LoadFromEntity(entity: widget.entity!, analyticsSurface: widget.analyticsSurface));
    } else {
      bloc.add(
        LoadFromId(
          wallId: widget.wallId!,
          source: widget.source!,
          wallpaperUrl: widget.wallpaperUrl,
          thumbnailUrl: widget.thumbnailUrl,
          analyticsSurface: widget.analyticsSurface,
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    shakeController.dispose();
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
    return MultiBlocListener(
      listeners: [
        BlocListener<WallpaperDetailBloc, WallpaperDetailState>(
          listener: (context, state) {
            if (state is WallpaperDetailLoaded && state.colors != null && state.accent != null) {
              _setStatusBarIconBrightness(state.accent!);
            }
          },
        ),
        BlocListener<PaletteBloc, PaletteState>(
          listener: (context, paletteState) {
            if (paletteState.status == LoadStatus.success && paletteState.palette.paletteColorValues.isNotEmpty) {
              final paletteColors = paletteState.palette.paletteColorValues.map((c) => Color(c)).toList();
              context.read<WallpaperDetailBloc>().add(UpdateColorsFromPalette(colors: paletteColors));
            }
          },
        ),
      ],
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

    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey[900]),
              errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
            ),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildErrorState(WallpaperDetailError state) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Something went wrong', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Please try again later', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, WallpaperDetailLoaded state) {
    final paletteLoading = context.select<PaletteBloc, bool>((bloc) {
      final status = bloc.state.status;
      return status == LoadStatus.loading || status == LoadStatus.initial;
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: paletteLoading ? Theme.of(context).primaryColor : state.accent,
      body: SlidingUpPanel(
        onPanelOpened: () => _handlePanelOpened(context, state),
        onPanelClosed: () => _handlePanelClosed(context, state),
        backdropEnabled: true,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        boxShadow: const [],
        minHeight: MediaQuery.of(context).size.height / 20,
        parallaxEnabled: true,
        parallaxOffset: 0.00,
        color: Colors.transparent,
        maxHeight: MediaQuery.of(context).size.height * 0.43,
        controller: panelController,
        backdropOpacity: 0,
        panel: _buildInfoPanel(context, state),
        body: _buildImageBody(context, _offsetAnimation, paletteLoading, state),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context, WallpaperDetailLoaded state) {
    final entity = state.entity;
    final size = Size(MediaQuery.of(context).size.width - 20, MediaQuery.of(context).size.height * 0.43);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                            if (mounted) context.read<WallpaperDetailBloc>().add(const OnPanelScrollEnd());
                          });
                        }
                        return false;
                      },
                      child: _buildMetadataRow(context, entity, state),
                    ),
                  ),
                ),
                Expanded(flex: 5, child: _buildActionButtons(context, state)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseHandle(BuildContext context, WallpaperDetailLoaded state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
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
          child: Icon(
            state.panelCollapsed ? JamIcons.chevron_up : JamIcons.chevron_down,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }

  Widget _buildColorBar(BuildContext context, WallpaperDetailLoaded state) {
    final circleSize = (64.0 * 0.7).clamp(32.0, 56.0);
    final colors = state.colors;
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(colors == null ? 5 : colors.length, (index) {
          final color = colors != null && index < colors.length ? colors[index] : null;
          return GestureDetector(
            onTap: () {
              if (color != null) {
                _handleColorSelected(context, state, color);
              }
            },
            onLongPress: () {
              if (color != null) {
                HapticFeedback.vibrate();
                Clipboard.setData(
                  ClipboardData(text: color.toString().replaceAll('Color(0xff', '').replaceAll(')', '')),
                ).then((_) => toasts.color(color));
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: color ?? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              height: circleSize,
              width: circleSize,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, WallpaperDetailEntity entity, WallpaperDetailLoaded state) {
    return entity.when(
      prism: (wallpaper) => _buildPrismMetadata(context, wallpaper, state),
      wallhaven: (wallpaper) => _buildWallhavenMetadata(context, wallpaper, entity),
      pexels: (wallpaper) => _buildPexelsMetadata(context, wallpaper, entity),
    );
  }

  Widget _buildPrismMetadata(BuildContext context, PrismWallpaper wallpaper, WallpaperDetailLoaded state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.36,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      Text(
                        wallpaper.id.toUpperCase(),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.secondary, fontSize: 16),
                      ),
                      if (state.views != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: Container(height: 20, color: Theme.of(context).colorScheme.secondary, width: 2),
                        ),
                        Text(
                          "${state.views} views",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.secondary, fontSize: 16),
                        ),
                      ] else if (state.viewsLoading) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: Container(height: 20, color: Theme.of(context).colorScheme.secondary, width: 2),
                        ),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.secondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (wallpaper.collections?.isNotEmpty == true)
                _buildInfoRow(context, JamIcons.folder, wallpaper.collections!.take(2).join(', ')),
              if (wallpaper.core.category != null)
                _buildInfoRow(context, JamIcons.unordered_list, wallpaper.core.category!),
              if (wallpaper.core.resolution != null)
                _buildInfoRow(context, JamIcons.set_square, wallpaper.core.resolution!),
              if (wallpaper.core.sizeBytes != null)
                _buildInfoRow(context, JamIcons.save, "${(wallpaper.core.sizeBytes! / 1000000).toStringAsFixed(2)} MB"),
            ],
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildPrismAuthorRow(context, wallpaper),
                if (wallpaper.core.createdAt != null)
                  _buildInfoRow(context, JamIcons.calendar, _formatDate(wallpaper.core.createdAt!), reversed: true),
                _buildInfoRow(context, JamIcons.database, 'Prism', reversed: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallhavenMetadata(BuildContext context, WallhavenWallpaper wallpaper, WallpaperDetailEntity entity) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoTitle(context, wallpaper.id.toUpperCase()),
              const SizedBox(height: 5),
              if (wallpaper.views != null) _buildInfoRow(context, JamIcons.eye, wallpaper.views.toString()),
              const SizedBox(height: 5),
              if (wallpaper.core.favourites != null)
                _buildInfoRow(context, JamIcons.heart_f, wallpaper.core.favourites.toString()),
              const SizedBox(height: 5),
              if (wallpaper.sizeBytes != null || wallpaper.core.sizeBytes != null)
                _buildInfoRow(
                  context,
                  JamIcons.save,
                  "${((wallpaper.sizeBytes ?? wallpaper.core.sizeBytes ?? 0) / 1000000).toStringAsFixed(2)} MB",
                ),
            ],
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (wallpaper.core.authorName != null && wallpaper.core.authorName!.isNotEmpty) ...[
                  _buildWallhavenAuthorLink(context, wallpaper.core.authorName!),
                  const SizedBox(height: 5),
                ],
                if (wallpaper.core.category != null)
                  _buildInfoRow(
                    context,
                    JamIcons.unordered_list,
                    wallpaper.core.category!,
                    reversed: true,
                    showIconLast: true,
                  ),
                const SizedBox(height: 5),
                if (wallpaper.core.resolution != null)
                  _buildInfoRow(
                    context,
                    JamIcons.set_square,
                    wallpaper.core.resolution!,
                    reversed: true,
                    showIconLast: true,
                  ),
                const SizedBox(height: 5),
                _buildInfoRow(
                  context,
                  JamIcons.database,
                  sourceDisplayName(entity.source),
                  reversed: true,
                  showIconLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPexelsMetadata(BuildContext context, PexelsWallpaper wallpaper, WallpaperDetailEntity entity) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoTitle(context, wallpaper.id),
              const SizedBox(height: 5),
              _buildInfoRow(context, JamIcons.info, wallpaper.id),
              const SizedBox(height: 5),
              if (wallpaper.core.width != null && wallpaper.core.height != null)
                _buildInfoRow(context, JamIcons.set_square, "${wallpaper.core.width}x${wallpaper.core.height}"),
            ],
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (wallpaper.photographer != null && wallpaper.photographer!.isNotEmpty)
                  _buildPexelsPhotographerLink(context, wallpaper.photographer!, wallpaper.photographerUrl),
                _buildInfoRow(context, JamIcons.database, 'Pexels', reversed: true, showIconLast: true),
              ],
            ),
          ),
        ],
      ),
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
      radius: 18,
      backgroundColor: secondary.withValues(alpha: 0.15),
      child: hasPhoto
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoTrimmed,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Text(
                  initialChar,
                  style: TextStyle(color: secondary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            )
          : Text(
              initialChar,
              style: TextStyle(color: secondary, fontWeight: FontWeight.w600, fontSize: 14),
            ),
    );

    final bool canNavigate = emailTrimmed.isNotEmpty;

    if (displayLabel == null) {
      final Widget solo = Padding(padding: const EdgeInsets.only(bottom: 4), child: avatar);
      if (!canNavigate) {
        return solo;
      }
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.router.push(ProfileRoute(profileIdentifier: emailTrimmed)),
          borderRadius: BorderRadius.circular(8),
          child: solo,
        ),
      );
    }

    Widget row = Padding(
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
    );

    if (canNavigate) {
      row = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.router.push(ProfileRoute(profileIdentifier: emailTrimmed)),
          borderRadius: BorderRadius.circular(8),
          child: row,
        ),
      );
    }
    return row;
  }

  Widget _buildWallhavenAuthorLink(BuildContext context, String username) {
    return SizedBox(
      width: 200,
      child: Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: () async {
            final Uri uri = Uri.https('wallhaven.cc', '/user/${Uri.encodeComponent(username)}');
            final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (!ok && context.mounted) {
              toasts.codeSend('Could not open profile');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              username,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPexelsPhotographerLink(BuildContext context, String photographer, String? photographerUrl) {
    final String urlForLaunch = photographerUrl?.trim() ?? '';
    final bool hasUrl = urlForLaunch.isNotEmpty;
    final TextStyle style = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary, fontSize: 16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: SizedBox(
        width: 200,
        child: Align(
          alignment: Alignment.centerRight,
          child: hasUrl
              ? InkWell(
                  onTap: () async {
                    final Uri? uri = Uri.tryParse(urlForLaunch);
                    if (uri == null) {
                      return;
                    }
                    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!ok && context.mounted) {
                      toasts.codeSend('Could not open profile');
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(photographer, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: style),
                  ),
                )
              : Text(photographer, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: style),
        ),
      ),
    );
  }

  Widget _buildInfoTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String text, {
    bool reversed = false,
    bool showIconLast = false,
  }) {
    final iconWidget = Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7));
    final textWidget = Flexible(
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
    const spacer = SizedBox(width: 10);
    if (showIconLast || reversed) {
      return Row(mainAxisSize: MainAxisSize.min, children: [textWidget, spacer, iconWidget]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [iconWidget, spacer, textWidget]);
  }

  Widget _buildActionButtons(BuildContext context, WallpaperDetailLoaded state) {
    final entity = state.entity;
    final url = state.screenshotTaken && state.imageFile != null ? state.imageFile!.path : entity.fullUrl;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        DownloadButton(colorChanged: state.colorChanged, link: url, sourceContext: _getSourceContext(state)),
        if (!hideSetWallpaperUi)
          SetWallpaperButton(colorChanged: state.colorChanged, url: url, promptNotificationPermissionOnSuccess: true),
        FavouriteWallpaperButton(wall: _toFavouriteWall(entity), trash: false),
        ShareButton(id: entity.id, source: entity.source, url: entity.fullUrl, thumbUrl: entity.thumbnailUrl),
        EditButton(url: entity.fullUrl),
      ],
    );
  }

  Widget _buildImageBody(
    BuildContext context,
    Animation<double> offsetAnimation,
    bool paletteLoading,
    WallpaperDetailLoaded state,
  ) {
    final entity = state.entity;
    _syncWallpaperIdentity(entity);
    return Stack(
      children: [
        AnimatedBuilder(
          animation: offsetAnimation,
          builder: (context, child) {
            return GestureDetector(
              onPanUpdate: (details) {
                if (details.delta.dy < -10) panelController.open();
              },
              onLongPress: () => _handleAccentLongPress(context, state),
              onTap: () {
                HapticFeedback.vibrate();
                if (!paletteLoading) _handleAccentTap(context, state);
                shakeController.forward(from: 0.0);
              },
              child: Screenshot(
                controller: screenshotController,
                child: Container(
                  margin: EdgeInsets.symmetric(
                    vertical: offsetAnimation.value * 1.25,
                    horizontal: offsetAnimation.value / 2,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(offsetAnimation.value),
                    child: _buildProgressiveWallpaperImage(
                      context: context,
                      entity: entity,
                      state: state,
                      paletteLoading: paletteLoading,
                      progressOutsideScreenshot: true,
                      onWallpaperDisplayReady: _scheduleWallpaperDisplayReady,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (!_wallpaperReadyForCapture)
          Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error)),
            ),
          ),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
            child: IconButton(
              onPressed: () {
                _trackAction(state, AnalyticsActionValue.backTapped);
                Navigator.pop(context);
              },
              color: paletteLoading
                  ? Theme.of(context).colorScheme.secondary
                  : (state.accent?.computeLuminance() ?? 0) > 0.5
                  ? Colors.black
                  : Colors.white,
              icon: const Icon(JamIcons.chevron_left),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
            child: IconButton(
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
              color: paletteLoading
                  ? Theme.of(context).colorScheme.secondary
                  : (state.accent?.computeLuminance() ?? 0) > 0.5
                  ? Colors.black
                  : Colors.white,
              icon: const Icon(JamIcons.clock),
            ),
          ),
        ),
      ],
    );
  }

  /// Thumbnail first, loader while full resolution downloads, then full image on top (Wallhaven/Pexels).
  ///
  /// When [progressOutsideScreenshot] is true, download progress is not painted inside this subtree
  /// (so [Screenshot] cannot capture spinners); use [onWallpaperDisplayReady] when the full bitmap
  /// is shown or an error/empty state is finalized.
  Widget _buildProgressiveWallpaperImage({
    required BuildContext context,
    required WallpaperDetailEntity entity,
    required WallpaperDetailLoaded state,
    required bool paletteLoading,
    bool progressOutsideScreenshot = false,
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
            placeholder: (context, url) => Container(color: Colors.grey[900]),
            errorWidget: (context, url, error) {
              onWallpaperDisplayReady?.call();
              return Center(
                child: Icon(JamIcons.close_circle_f, color: _wallpaperErrorIconColor(context, paletteLoading, state)),
              );
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
            progressIndicatorBuilder: progressOutsideScreenshot
                ? (context, url, downloadProgress) => const SizedBox.shrink()
                : (context, url, downloadProgress) => Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error),
                      value: downloadProgress.progress,
                    ),
                  ),
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
        imageLayer = Center(
          child: Icon(JamIcons.close_circle_f, color: _wallpaperErrorIconColor(context, paletteLoading, state)),
        );
      } else {
        imageLayer = CachedNetworkImage(
          imageUrl: url,
          imageBuilder: (context, imageProvider) {
            onWallpaperDisplayReady?.call();
            return SizedBox.expand(
              child: Image(image: imageProvider, fit: BoxFit.cover),
            );
          },
          progressIndicatorBuilder: progressOutsideScreenshot
              ? (context, url, downloadProgress) => const SizedBox.shrink()
              : (context, url, downloadProgress) => Stack(
                  children: [
                    const SizedBox.expand(child: Text('')),
                    Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error),
                        value: downloadProgress.progress,
                      ),
                    ),
                  ],
                ),
          errorWidget: (context, url, error) {
            onWallpaperDisplayReady?.call();
            return Center(
              child: Icon(JamIcons.close_circle_f, color: _wallpaperErrorIconColor(context, paletteLoading, state)),
            );
          },
        );
      }
    }

    if (state.colorChanged && state.accent != null) {
      imageLayer = ColorFiltered(colorFilter: ColorFilter.mode(state.accent!, BlendMode.hue), child: imageLayer);
    }

    return SizedBox.expand(child: imageLayer);
  }

  Color _wallpaperErrorIconColor(BuildContext context, bool paletteLoading, WallpaperDetailLoaded state) {
    return paletteLoading
        ? Theme.of(context).colorScheme.secondary
        : (state.accent?.computeLuminance() ?? 0) > 0.5
        ? Colors.black
        : Colors.white;
  }

  String _formatDate(DateTime date) => "${date.day}/${date.month}/${date.year}";

  String sourceDisplayName(WallpaperSource source) => switch (source) {
    WallpaperSource.prism => 'Prism',
    WallpaperSource.wallhaven => 'Wallhaven',
    WallpaperSource.pexels => 'Pexels',
    WallpaperSource.downloaded => 'Downloaded',
    WallpaperSource.unknown => 'Unknown',
  };
}
