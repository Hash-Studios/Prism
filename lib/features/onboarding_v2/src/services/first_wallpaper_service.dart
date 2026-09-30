import 'dart:math';

import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/onboarding_v2/src/views/viewmodels/onboarding_wallpaper_vm.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FirstWallpaperService {
  FirstWallpaperService(this._categoryFeedRepository, this._wallOfTheDayRepository);

  final CategoryFeedRepository _categoryFeedRepository;
  final WallOfTheDayRepository _wallOfTheDayRepository;
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

  Future<bool> performAction(String fullUrl) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await WallpaperService.setWallpaperFromSource(fullUrl, WallpaperTarget.both);
      } else {
        final result = await PrismMediaHostApi().saveMedia(
          SaveMediaRequest(link: fullUrl, isLocalFile: false, kind: SaveMediaKind.wallpaper),
        );
        return result.success;
      }
    } catch (_) {
      return false;
    }
  }
}
