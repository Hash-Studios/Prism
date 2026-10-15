import 'dart:math';

import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_wallpaper_vm.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// What the first wallpaper action did. [target] is the screen set on Android. [errorCode] explains a failure.
class FirstWallpaperResult {
  const FirstWallpaperResult({required this.success, this.errorCode, this.target});

  final bool success;
  final String? errorCode;
  final WallpaperTarget? target;
}

@lazySingleton
class FirstWallpaperService {
  FirstWallpaperService(
    this._categoryFeedRepository,
    this._wallOfTheDayRepository, {
    @ignoreParam Future<aw.WallpaperCapabilities> Function()? getCapabilities,
    @ignoreParam Future<WallpaperSetResult> Function(String url, WallpaperTarget target)? setWallpaper,
    @ignoreParam Future<OperationResult> Function(SaveMediaRequest request)? saveMedia,
  }) : _getCapabilities = getCapabilities ?? aw.AsyncWallpaper.getCapabilities,
       _setWallpaper = setWallpaper ?? WallpaperService.setWallpaper,
       _saveMedia = saveMedia ?? ((request) => PrismMediaHostApi().saveMedia(request));

  final CategoryFeedRepository _categoryFeedRepository;
  final WallOfTheDayRepository _wallOfTheDayRepository;
  final Future<aw.WallpaperCapabilities> Function() _getCapabilities;
  final Future<WallpaperSetResult> Function(String url, WallpaperTarget target) _setWallpaper;
  final Future<OperationResult> Function(SaveMediaRequest request) _saveMedia;
  final Random _random = Random();

  Future<OnboardingWallpaperVm?> recommendForOnboarding(List<String> interests) async {
    if (interests.isNotEmpty) {
      final categoriesResult = await _categoryFeedRepository.getCategories();
      if (categoriesResult.isSuccess && categoriesResult.data != null) {
        final allCategories = categoriesResult.data!;
        if (allCategories.isEmpty) {
          return _fetchWotdVm();
        }
        final shuffled = [...interests]..shuffle();
        for (final interest in shuffled) {
          final matched = allCategories.where((c) => c.name.toLowerCase() == interest.toLowerCase());
          if (matched.isEmpty) {
            continue;
          }
          final category = matched.first;

          final feedResult = await _categoryFeedRepository.fetchCategoryFeed(category: category, refresh: false);

          if (feedResult.isSuccess && feedResult.data != null) {
            final candidate = _pickRandomValidItem(feedResult.data!.items, sourceCategory: interest);
            if (candidate != null) {
              return candidate;
            }
          }
        }
      }
    }

    return _fetchWotdVm();
  }

  OnboardingWallpaperVm? _pickRandomValidItem(List<FeedItemEntity> items, {required String sourceCategory}) {
    final valid = <OnboardingWallpaperVm>[];
    for (final item in items) {
      final (fullUrl, thumbnailUrl) = item.when(
        prism: (_, wall) => (wall.fullUrl, wall.thumbnailUrl),
        wallhaven: (_, wall) => (wall.fullUrl, wall.thumbnailUrl),
        pexels: (_, wall) => (wall.fullUrl, wall.thumbnailUrl),
      );
      if (fullUrl.isEmpty) continue;
      valid.add(OnboardingWallpaperVm(fullUrl: fullUrl, thumbnailUrl: thumbnailUrl, sourceCategory: sourceCategory));
    }
    if (valid.isEmpty) return null;
    return valid[_random.nextInt(valid.length)];
  }

  Future<OnboardingWallpaperVm?> _fetchWotdVm() async {
    final result = await _wallOfTheDayRepository.fetchToday();
    final wotd = result.data;
    if (!result.isSuccess || wotd == null || wotd.url.isEmpty) return null;
    return OnboardingWallpaperVm(
      fullUrl: wotd.url,
      thumbnailUrl: wotd.thumbnailUrl.isNotEmpty ? wotd.thumbnailUrl : wotd.url,
      sourceCategory: '',
    );
  }

  Future<FirstWallpaperResult> performAction(String fullUrl) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final target = await _androidTarget();
        if (target == null) {
          return const FirstWallpaperResult(success: false, errorCode: 'unsupported');
        }
        final result = await _setWallpaper(fullUrl, target);
        return FirstWallpaperResult(success: result.isSuccess, errorCode: result.errorCode, target: target);
      } else {
        final result = await _saveMedia(
          SaveMediaRequest(link: fullUrl, isLocalFile: false, kind: SaveMediaKind.wallpaper),
        );
        return FirstWallpaperResult(success: result.success, errorCode: result.errorCode);
      }
    } catch (_) {
      return const FirstWallpaperResult(success: false, errorCode: 'exception');
    }
  }

  /// Home and lock screens when the device can set both, else the one screen it can set.
  Future<WallpaperTarget?> _androidTarget() async {
    final aw.WallpaperCapabilities capabilities;
    try {
      capabilities = await _getCapabilities();
    } catch (_) {
      return WallpaperTarget.both;
    }
    for (final target in const <WallpaperTarget>[WallpaperTarget.both, WallpaperTarget.home, WallpaperTarget.lock]) {
      if (_supports(capabilities, target)) return target;
    }
    return null;
  }

  /// Unknown capabilities count as supported.
  static bool _supports(aw.WallpaperCapabilities capabilities, WallpaperTarget target) {
    if (!capabilities.supportsStaticWallpaper) return true;
    return switch (target) {
      WallpaperTarget.home => capabilities.supportsHomeWallpaper,
      WallpaperTarget.lock => capabilities.supportsLockWallpaper,
      WallpaperTarget.both => capabilities.supportsBothWallpapers,
    };
  }
}
