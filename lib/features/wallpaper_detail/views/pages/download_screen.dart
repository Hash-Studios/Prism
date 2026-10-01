import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

@RoutePage()
class DownloadScreen extends StatefulWidget {
  @override
  _DownloadScreenState createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  List<File> files = [];
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  GlobalKey<RefreshIndicatorState> refreshDownloadKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    readData();
  }

  Future<void> readData() async {
    _contentLoadTracker.start();
    List<File> found;
    try {
      final result = await PrismMediaHostApi().listDownloads();
      if (!result.success) {
        logger.w(result.message ?? 'Unable to list downloads');
        found = <File>[];
      } else {
        found = result.items.map(File.new).where((file) => file.existsSync()).toList(growable: false);
      }
    } catch (e) {
      logger.d(e.toString());
      found = <File>[];
    }
    if (!mounted) return;
    setState(() {
      files = found;
    });
    _contentLoadTracker.success(
      itemCount: found.length,
      onSuccess: ({required int loadTimeMs, int? itemCount}) async {
        await analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.downloadScreen,
            result: found.isEmpty ? EventResultValue.empty : EventResultValue.success,
            loadTimeMs: loadTimeMs,
            sourceContext: 'download_screen_read_data',
            itemCount: itemCount,
          ),
        );
      },
    );
  }

  Future<void> refreshList() async {
    refreshDownloadKey.currentState?.show();
    setState(() {
      files = [];
    });
    await readData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: "Downloads"),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        child: RefreshIndicator(
          backgroundColor: Theme.of(context).primaryColor,
          key: refreshDownloadKey,
          onRefresh: () {
            PrismHaptics.impact();
            return refreshList();
          },
          child: files.isNotEmpty
              ? GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
                  itemCount: files.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                    childAspectRatio: 0.6625,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            image: DecorationImage(image: FileImage(files[index]), fit: BoxFit.cover),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                              highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                              onTap: () {
                                PrismHaptics.tap();
                                unawaited(
                                  analytics.track(
                                    SurfaceActionTappedEvent(
                                      surface: AnalyticsSurfaceValue.downloadScreen,
                                      action: AnalyticsActionValue.openDownloadedWallpaperTapped,
                                      sourceContext: 'download_screen_open_item',
                                      itemId: files[index].path,
                                    ),
                                  ),
                                );
                                final File file = files[index];
                                final DownloadedWallRef? wall = getIt<DownloadedWallIndex>().resolve(file.path);
                                context.router.push(
                                  wall == null
                                      ? DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: file)
                                      : WallpaperDetailRoute(
                                          wallId: wall.id,
                                          source: wall.source,
                                          localFile: file,
                                          analyticsSurface: AnalyticsSurfaceValue.downloadWallpaperScreen,
                                        ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: SvgPicture.string(themedIllustration(context, dark: downloadsDark, light: downloadsLight)),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.1,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
