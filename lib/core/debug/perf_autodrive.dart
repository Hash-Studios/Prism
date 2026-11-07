import 'dart:async';

import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/search_tags.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Measurement-only: drives the home, detail, search and rewards flows on a device where taps cannot be injected.
/// Compiled out unless `PRISM_PERF_AUTODRIVE` is set, and never runs in release builds.
class PerfAutodrive {
  const PerfAutodrive._();

  static const String _launchKey = 'perfAutodrive.launch';
  static bool _started = false;

  static void start(AppRouter router) {
    if (!Env.perfAutodrive || kReleaseMode || _started) return;
    _started = true;
    unawaited(_run(router));
  }

  static Future<void> _run(AppRouter router) async {
    Timer? afterResume;
    int resumeGeneration = 0;
    AppLifecycleListener(
      onResume: () {
        final int generation = ++resumeGeneration;
        PerformanceProbe.phase('resume');
        final Stopwatch sinceResume = Stopwatch()..start();
        unawaited(
          SchedulerBinding.instance.endOfFrame.then((_) {
            if (generation != resumeGeneration) return;
            PerformanceProbe.emit(kind: 'resume', name: 'resume_to_frame', durationMs: sinceResume.elapsedMilliseconds);
          }),
        );
        afterResume?.cancel();
        afterResume = Timer(const Duration(seconds: 4), () => PerformanceProbe.phase('after_resume'));
      },
      onPause: () => PerformanceProbe.phase('paused'),
      onStateChange: (AppLifecycleState state) {
        if (state == AppLifecycleState.resumed) return;
        resumeGeneration++;
        afterResume?.cancel();
      },
    );
    int launch = 0;
    await _step('launch counter', () async {
      final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
      launch = settings.get<int>(_launchKey, defaultValue: 0);
      await settings.set(_launchKey, launch + 1);
    });

    await _step('wait for home', () async {
      for (int i = 0; i < 150 && router.current.name != DashboardRoute.name; i++) {
        await _wait(const Duration(milliseconds: 100));
      }
      await _wait(const Duration(seconds: 3));
    });

    await _step('home scroll', () async {
      PerformanceProbe.phase('home_idle');
      await _wait(const Duration(seconds: 2));
      PerformanceProbe.phase('home_scroll');
      for (int i = 0; i < 4; i++) {
        await _fling(up: true);
        await _wait(const Duration(milliseconds: 1500));
      }
      await _fling(up: false);
      await _wait(const Duration(milliseconds: 1500));
    });

    await _step('open detail', () async {
      final page = await getIt<PersonalizedFeedRepository>().readCached();
      if (page == null || page.items.isEmpty) throw StateError('no cached feed item');
      PerformanceProbe.phase('detail_open');
      unawaited(router.push(WallpaperDetailRoute(entity: page.items.first, heroTag: 'perfAutodrive')));
      await _wait(const Duration(seconds: 3));
      PerformanceProbe.phase('detail_close');
      await router.maybePop();
      await _wait(const Duration(milliseconds: 1500));
      PerformanceProbe.phase('after_detail');
    });

    await _step('search tab', () async {
      await router.navigate(const DashboardRoute(children: <PageRouteInfo>[SearchTabRoute()]));
      await _wait(const Duration(seconds: 2));
    });

    await _step('chip search', () async {
      pendingTagSearch.value = null;
      pendingTagSearch.value = curatedSearchTags[launch % curatedSearchTags.length];
      await _wait(const Duration(seconds: 4));
    });

    await _step('colour search', () async {
      final PrismPaletteColor color = prismPalette[launch % prismPalette.length];
      await getIt<WallpaperSearchService>().search('', filters: SearchFilters(color: color));
      await _wait(const Duration(seconds: 4));
    });

    await _step('rewards tab', () async {
      await router.navigate(const DashboardRoute(children: <PageRouteInfo>[RewardsTabRoute()]));
      await _wait(const Duration(seconds: 3));
      await router.navigate(const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()]));
    });

    await _wait(const Duration(milliseconds: 1500));
    PerformanceProbe.phase('done');
    PerformanceProbe.mark('autodrive.done');
    logger.i('perfAutodrive done', tag: 'PerfAutodrive');
  }

  /// A quick vertical drag in the middle of the screen, sent as real pointer events so the feed flings.
  static Future<void> _fling({required bool up}) async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final Size size = view.physicalSize / view.devicePixelRatio;
    final double x = size.width / 2;
    final double from = size.height * (up ? 0.75 : 0.3);
    final double to = size.height * (up ? 0.3 : 0.75);
    const int steps = 10;
    final Stopwatch clock = Stopwatch()..start();
    const int pointer = 9001;
    final binding = WidgetsBinding.instance;
    binding.handlePointerEvent(PointerDownEvent(pointer: pointer, position: Offset(x, from), timeStamp: clock.elapsed));
    for (int i = 1; i <= steps; i++) {
      await _wait(const Duration(milliseconds: 8));
      final double dy = (to - from) / steps;
      binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: Offset(x, from + dy * i),
          delta: Offset(0, dy),
          timeStamp: clock.elapsed,
        ),
      );
    }
    binding.handlePointerEvent(PointerUpEvent(pointer: pointer, position: Offset(x, to), timeStamp: clock.elapsed));
  }

  static Future<void> _wait(Duration d) => Future<void>.delayed(d);

  static Future<void> _step(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (error, stackTrace) {
      logger.w('perfAutodrive step "$name" failed', tag: 'PerfAutodrive', error: error, stackTrace: stackTrace);
    }
  }
}
