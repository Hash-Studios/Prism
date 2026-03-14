import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/core/widgets/menuButton/editButton.dart';
import 'package:Prism/core/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/core/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/core/widgets/menuButton/shareButton.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/palette/palette.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

@RoutePage()
class WallpaperDetailScreen extends StatefulWidget {
  const WallpaperDetailScreen({
    super.key,
    required this.entity,
    this.viewsFuture,
    this.analyticsSurface = AnalyticsSurfaceValue.wallpaperScreen,
  });

  final WallpaperDetailEntity entity;
  final Future<String>? viewsFuture;
  final AnalyticsSurfaceValue analyticsSurface;

  @override
  State<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends State<WallpaperDetailScreen> with SingleTickerProviderStateMixin {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  late AnimationController shakeController;
  List<Color?>? colors;
  Color? accent = Colors.white;
  bool colorChanged = false;
  late File _imageFile;
  bool screenshotTaken = false;
  ScreenshotController screenshotController = ScreenshotController();
  PanelController panelController = PanelController();
  bool panelClosed = true;
  bool panelCollapsed = true;
  bool _panelScrollInProgress = false;

  String get _sourceContext => '${widget.entity.source.wireValue}_wallpaper_screen';

  String? get _currentItemId => widget.entity.id;

  void _trackAction(AnalyticsActionValue action) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: widget.analyticsSurface,
          action: action,
          sourceContext: _sourceContext,
          itemType: ItemTypeValue.wallpaper,
          itemId: _currentItemId,
        ),
      ),
    );
  }

  void _updatePaletteGenerator() {
    final imageUrl = widget.entity.thumbnailUrl;
    if (imageUrl.trim().isEmpty) {
      logger.w('Skipping palette generation due to empty wallpaper link.', tag: 'WallpaperDetailScreen');
      return;
    }
    _contentLoadTracker.start();
    context.read<PaletteBloc>().add(PaletteEvent.paletteRequested(imageUrl: imageUrl));
  }

  void _applyPaletteState(PaletteState state) {
    if (!mounted) return;
    if (state.status == LoadStatus.failure) {
      _contentLoadTracker.failure(
        reason: AnalyticsReasonValue.error,
        onFailure: ({required int loadTimeMs, AnalyticsReasonValue? reason, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: widget.analyticsSurface,
              result: EventResultValue.failure,
              loadTimeMs: loadTimeMs,
              sourceContext: _sourceContext,
              reason: reason,
            ),
          );
        },
      );
      return;
    }
    if (state.status != LoadStatus.success || state.palette.paletteColorValues.isEmpty) {
      return;
    }

    final paletteColors = state.palette.paletteColorValues.map((colorValue) => Color(colorValue)).toList();
    final limitedColors = paletteColors.length > 5 ? paletteColors.sublist(0, 5) : paletteColors;

    setState(() {
      colors = limitedColors;
      accent = limitedColors[0];
    });

    _contentLoadTracker.success(
      itemCount: limitedColors.length,
      onSuccess: ({required int loadTimeMs, int? itemCount}) async {
        await analytics.track(
          SurfaceContentLoadedEvent(
            surface: widget.analyticsSurface,
            result: EventResultValue.success,
            loadTimeMs: loadTimeMs,
            sourceContext: _sourceContext,
            itemCount: itemCount,
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 500)).then((_) {
      if (!mounted || accent == null) return;
      _setStatusBarIconBrightness(accent!);
    });
  }

  void _setStatusBarIconBrightness(Color color) {
    if (color.computeLuminance() > 0.5) {
      applyEdgeToEdgeOverlayStyle(statusBarIconBrightness: Brightness.dark);
    } else {
      applyEdgeToEdgeOverlayStyle(statusBarIconBrightness: Brightness.light);
    }
  }

  void updateAccent() {
    if (colors!.contains(accent)) {
      final index = colors!.indexOf(accent);
      setState(() {
        accent = colors![(index + 1) % 5];
      });
      setState(() {
        colorChanged = true;
      });
      _setStatusBarIconBrightness(accent!);
    }
    _trackAction(AnalyticsActionValue.paletteCycleTapped);
    if (firstTime == 0) {
      toasts.codeSend("Long press to reset.");
      firstTime = 1;
    }
  }

  int firstTime = 0;

  void _handlePanelOpened() {
    _trackAction(AnalyticsActionValue.panelOpened);
    setState(() {
      panelCollapsed = false;
    });
    if (panelClosed) {
      logger.d('Screenshot Starting');
      setState(() {
        panelClosed = false;
      });
      if (colorChanged) {
        screenshotController
            .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
            .then((Uint8List? image) {
              setState(() {
                _imageFile = File.fromRawPath(image!);
                screenshotTaken = true;
              });
              logger.d('Screenshot Taken');
            })
            .catchError((onError) {
              logger.d(onError.toString());
            });
      } else {
        final optimize = _settingsLocal.get<bool>('optimisedWallpapers', defaultValue: true);
        if (optimize == true) {
          screenshotController
              .capture(pixelRatio: 3, delay: const Duration(milliseconds: 10))
              .then((Uint8List? image) {
                setState(() {
                  _imageFile = File.fromRawPath(image!);
                  screenshotTaken = true;
                });
                logger.d('Screenshot Taken');
              })
              .catchError((onError) {
                logger.d(onError.toString());
              });
        } else {
          logger.d("Wallpaper Optimisation is disabled!");
        }
      }
    }
  }

  void _handlePanelClosed() {
    _trackAction(AnalyticsActionValue.panelClosed);
    setState(() {
      panelCollapsed = true;
      panelClosed = true;
    });
  }

  @override
  void initState() {
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    super.initState();
    _contentLoadTracker.start();
    Future.delayed(Duration.zero).then((_) => _updatePaletteGenerator());
  }

  @override
  void dispose() {
    super.dispose();
    shakeController.dispose();
  }

  FavouriteWallEntity _toFavouriteWall() {
    return widget.entity.when(
      prism: (wallpaper) => PrismFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
      wallhaven: (wallpaper) => WallhavenFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
      pexels: (wallpaper) => PexelsFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paletteState = context.watch<PaletteBloc>().state;
    final paletteLoading = paletteState.status == LoadStatus.loading || paletteState.status == LoadStatus.initial;

    final Animation<double> offsetAnimation =
        Tween(begin: 0.0, end: 48.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });

    return BlocListener<PaletteBloc, PaletteState>(
      listenWhen: (previous, current) => previous.status != current.status || previous.palette != current.palette,
      listener: (context, state) => _applyPaletteState(state),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: paletteLoading ? Theme.of(context).primaryColor : accent,
        body: SlidingUpPanel(
          onPanelOpened: _handlePanelOpened,
          onPanelClosed: _handlePanelClosed,
          backdropEnabled: true,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          boxShadow: const [],
          collapsed: CollapsedPanel(panelCollapsed: panelCollapsed, panelController: panelController),
          minHeight: MediaQuery.of(context).size.height / 20,
          parallaxEnabled: true,
          parallaxOffset: 0.00,
          color: Colors.transparent,
          maxHeight: MediaQuery.of(context).size.height * 0.43,
          controller: panelController,
          panel: _buildInfoPanel(context),
          body: _buildImageBody(context, offsetAnimation, paletteLoading),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      height: MediaQuery.of(context).size.height * 0.43,
      width: MediaQuery.of(context).size.width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 750),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: panelCollapsed
                  ? Theme.of(context).primaryColor.withValues(alpha: 1)
                  : Theme.of(context).primaryColor.withValues(alpha: .5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCollapseHandle(context),
                _buildColorBar(context),
                Expanded(
                  flex: 8,
                  child: SingleChildScrollView(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollStartNotification) {
                          setState(() => _panelScrollInProgress = true);
                        } else if (notification is ScrollEndNotification) {
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (mounted) {
                              setState(() => _panelScrollInProgress = false);
                            }
                          });
                        }
                        return false;
                      },
                      child: _buildMetadataRow(context),
                    ),
                  ),
                ),
                Expanded(flex: 5, child: _buildActionButtons(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseHandle(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: AnimatedOpacity(
          duration: Duration.zero,
          opacity: panelCollapsed ? 0.0 : 1.0,
          child: GestureDetector(
            onTap: () {
              if (_panelScrollInProgress) return;
              _trackAction(AnalyticsActionValue.panelCollapseTapped);
              panelController.close();
            },
            child: Icon(JamIcons.chevron_down, color: Theme.of(context).colorScheme.secondary),
          ),
        ),
      ),
    );
  }

  Widget _buildColorBar(BuildContext context) {
    final circleSize = (64.0 * 0.7).clamp(32.0, 56.0);
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(colors == null ? 5 : colors!.length, (index) {
          return GestureDetector(
            onTap: () {
              if (colors != null && index < colors!.length) {
                setState(() {
                  accent = colors![index];
                });
                _setStatusBarIconBrightness(accent!);
              }
            },
            onLongPress: () {
              if (colors != null && index < colors!.length) {
                HapticFeedback.vibrate();
                Clipboard.setData(
                  ClipboardData(text: colors![index].toString().replaceAll('Color(0xff', '').replaceAll(')', '')),
                ).then((_) {
                  toasts.color(colors![index]!);
                });
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: colors == null ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : colors![index],
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

  Widget _buildMetadataRow(BuildContext context) {
    return widget.entity.when(
      prism: (wallpaper) => _buildPrismMetadata(context, wallpaper),
      wallhaven: (wallpaper) => _buildWallhavenMetadata(context, wallpaper),
      pexels: (wallpaper) => _buildPexelsMetadata(context, wallpaper),
    );
  }

  Widget _buildPrismMetadata(BuildContext context, PrismWallpaper wallpaper) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildLeftPrismColumn(context, wallpaper), _buildRightPrismColumn(context, wallpaper)],
      ),
    );
  }

  Widget _buildLeftPrismColumn(BuildContext context, PrismWallpaper wallpaper) {
    return Column(
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
                if (widget.viewsFuture != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Container(height: 20, color: Theme.of(context).colorScheme.secondary, width: 2),
                  ),
                  FutureBuilder(
                    future: widget.viewsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                        return Text(
                          "${snapshot.data} views",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.secondary, fontSize: 16),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        if (wallpaper.collections?.isNotEmpty == true)
          _buildInfoRow(context, JamIcons.folder, wallpaper.collections!.take(2).join(', ')),
        if (wallpaper.core.category != null) _buildInfoRow(context, JamIcons.unordered_list, wallpaper.core.category!),
        if (wallpaper.core.resolution != null) _buildInfoRow(context, JamIcons.set_square, wallpaper.core.resolution!),
        if (wallpaper.core.sizeBytes != null)
          _buildInfoRow(context, JamIcons.save, "${(wallpaper.core.sizeBytes! / 1000000).toStringAsFixed(2)} MB"),
      ],
    );
  }

  Widget _buildRightPrismColumn(BuildContext context, PrismWallpaper wallpaper) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (wallpaper.core.authorName != null)
          _buildInfoRow(context, JamIcons.user, wallpaper.core.authorName!, reversed: true),
        if (wallpaper.core.createdAt != null)
          _buildInfoRow(context, JamIcons.calendar, _formatDate(wallpaper.core.createdAt!), reversed: true),
        _buildInfoRow(context, JamIcons.database, 'Prism', reversed: true),
      ],
    );
  }

  Widget _buildWallhavenMetadata(BuildContext context, WallhavenWallpaper wallpaper) {
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
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
                sourceDisplayName(widget.entity.source),
                reversed: true,
                showIconLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPexelsMetadata(BuildContext context, PexelsWallpaper wallpaper) {
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
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (wallpaper.photographer != null)
                SizedBox(
                  width: 160,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ActionChip(
                      onPressed: () {
                        _openPhotographerLink(context, wallpaper);
                      },
                      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                      avatar: Icon(JamIcons.camera, color: Theme.of(context).colorScheme.secondary),
                      labelPadding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                      label: Text(
                        wallpaper.photographer!,
                        style: Theme.of(context).textTheme.bodyMedium!
                            .copyWith(color: Theme.of(context).colorScheme.secondary)
                            .copyWith(fontSize: 16),
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ),
                ),
              _buildInfoRow(context, JamIcons.database, 'Pexels', reversed: true, showIconLast: true),
            ],
          ),
        ],
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
    final iconWidget = Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7));
    final textWidget = Flexible(
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
    const spacer = SizedBox(width: 10);

    if (showIconLast) {
      return Row(mainAxisSize: MainAxisSize.min, children: [textWidget, spacer, iconWidget]);
    }
    if (reversed) {
      return Row(mainAxisSize: MainAxisSize.min, children: [textWidget, spacer, iconWidget]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [iconWidget, spacer, textWidget]);
  }

  Widget _buildActionButtons(BuildContext context) {
    final url = screenshotTaken ? _imageFile.path : widget.entity.fullUrl;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        DownloadButton(colorChanged: colorChanged, link: url, sourceContext: _sourceContext),
        if (!hideSetWallpaperUi) SetWallpaperButton(colorChanged: colorChanged, url: url),
        FavouriteWallpaperButton(wall: _toFavouriteWall(), trash: false),
        ShareButton(
          id: widget.entity.id,
          source: widget.entity.source == WallpaperSource.wallOfTheDay ? WallpaperSource.prism : widget.entity.source,
          url: widget.entity.fullUrl,
          thumbUrl: widget.entity.thumbnailUrl,
        ),
        EditButton(url: widget.entity.fullUrl),
      ],
    );
  }

  Widget _buildImageBody(BuildContext context, Animation<double> offsetAnimation, bool paletteLoading) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: offsetAnimation,
          builder: (context, child) {
            return GestureDetector(
              onPanUpdate: (details) {
                if (details.delta.dy < -10) {
                  panelController.open();
                }
              },
              onLongPress: () {
                _trackAction(AnalyticsActionValue.paletteResetLongPressed);
                setState(() {
                  colorChanged = false;
                });
                HapticFeedback.vibrate();
                shakeController.forward(from: 0.0);
              },
              onTap: () {
                HapticFeedback.vibrate();
                if (!paletteLoading) updateAccent();
                shakeController.forward(from: 0.0);
              },
              child: CachedNetworkImage(
                imageUrl: widget.entity.thumbnailUrl,
                imageBuilder: (context, imageProvider) => Screenshot(
                  controller: screenshotController,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      vertical: offsetAnimation.value * 1.25,
                      horizontal: offsetAnimation.value / 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(offsetAnimation.value),
                      image: DecorationImage(
                        colorFilter: colorChanged ? ColorFilter.mode(accent!, BlendMode.hue) : null,
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                  children: [
                    const SizedBox.expand(child: Text("")),
                    Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error),
                        value: downloadProgress.progress,
                      ),
                    ),
                  ],
                ),
                errorWidget: (context, url, error) => Center(
                  child: Icon(
                    JamIcons.close_circle_f,
                    color: paletteLoading
                        ? Theme.of(context).colorScheme.secondary
                        : accent!.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
            child: IconButton(
              onPressed: () {
                _trackAction(AnalyticsActionValue.backTapped);
                Navigator.pop(context);
              },
              color: paletteLoading
                  ? Theme.of(context).colorScheme.secondary
                  : accent!.computeLuminance() > 0.5
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
                _trackAction(AnalyticsActionValue.clockOverlayOpened);
                final link = widget.entity.fullUrl;
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) {
                      animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: ClockOverlay(colorChanged: colorChanged, accent: accent, link: link, file: false),
                      );
                    },
                    fullscreenDialog: true,
                    opaque: false,
                  ),
                );
              },
              color: paletteLoading
                  ? Theme.of(context).colorScheme.secondary
                  : accent!.computeLuminance() > 0.5
                  ? Colors.black
                  : Colors.white,
              icon: const Icon(JamIcons.clock),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  void _openPhotographerLink(BuildContext context, PexelsWallpaper wallpaper) {
    // Pexels photographer links would be opened via url_launcher
    // This is a placeholder - the original code used openPrismLink
  }

  String sourceDisplayName(WallpaperSource source) {
    return switch (source) {
      WallpaperSource.prism => 'Prism',
      WallpaperSource.wallhaven => 'Wallhaven',
      WallpaperSource.pexels => 'Pexels',
      WallpaperSource.wallOfTheDay => 'Prism',
      WallpaperSource.downloaded => 'Downloaded',
      WallpaperSource.unknown => 'Unknown',
    };
  }
}
