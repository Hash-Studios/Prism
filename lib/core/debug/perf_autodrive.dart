import 'dart:async';

import 'package:Prism/core/color/prism_palette.dart';
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

    await _step('open detail', () async {
      final page = await getIt<PersonalizedFeedRepository>().readCached();
      if (page == null || page.items.isEmpty) throw StateError('no cached feed item');
      unawaited(router.push(WallpaperDetailRoute(entity: page.items.first, heroTag: 'perfAutodrive')));
      await _wait(const Duration(seconds: 3));
      await router.maybePop();
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

    logger.i('perfAutodrive done', tag: 'PerfAutodrive');
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
