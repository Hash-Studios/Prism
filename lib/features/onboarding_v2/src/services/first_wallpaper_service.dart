import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
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

  Future<OnboardingWallpaperVm?> recommendForOnboarding(List<String> interests) async {
    if (interests.isNotEmpty) {
      final categoriesResult = await _categoryFeedRepository.getCategories();
      if (categoriesResult.isSuccess && categoriesResult.data != null) {
        final allCategories = categoriesResult.data!;
        for (final interest in interests) {
          final category = allCategories.firstWhere(
            (c) => c.name.toLowerCase() == interest.toLowerCase(),
            orElse: () => CategoryEntity(
              name: interest,
              source: allCategories.isEmpty ? allCategories.first.source : allCategories.first.source,
              searchType: allCategories.isEmpty ? allCategories.first.searchType : allCategories.first.searchType,
              image: '',
            ),
          );

          final feedResult = await _categoryFeedRepository.fetchCategoryFeed(category: category, refresh: false);

          if (feedResult.isSuccess && feedResult.data != null) {
            final candidate = _pickFirstValidItem(feedResult.data!.items, sourceCategory: interest);
            if (candidate != null) {
              return candidate;
            }
          }
        }
      }
    }

    return _fetchWotdVm();
  }

  OnboardingWallpaperVm? _pickFirstValidItem(List<FeedItemEntity> items, {required String sourceCategory}) {
    for (final item in items) {
      final vm = item.when(
        prism: (_, wall) {
          if (wall.fullUrl.isEmpty) {
            return null;
          }
          return OnboardingWallpaperVm(
            fullUrl: wall.fullUrl,
            thumbnailUrl: wall.thumbnailUrl,
            title: wall.core.category ?? 'Wallpaper',
            authorName: wall.core.authorName ?? '',
            sourceCategory: sourceCategory,
          );
        },
        wallhaven: (_, wall) {
          if (wall.fullUrl.isEmpty) {
            return null;
          }
          return OnboardingWallpaperVm(
            fullUrl: wall.fullUrl,
            thumbnailUrl: wall.thumbnailUrl,
            title: 'Wallhaven',
            authorName: '',
            sourceCategory: sourceCategory,
          );
        },
        pexels: (_, wall) {
          if (wall.fullUrl.isEmpty) {
            return null;
          }
          return OnboardingWallpaperVm(
            fullUrl: wall.fullUrl,
            thumbnailUrl: wall.thumbnailUrl,
            title: 'Pexels',
            authorName: wall.photographer ?? '',
            sourceCategory: sourceCategory,
          );
        },
      );
      if (vm != null) {
        return vm;
      }
    }
    return null;
  }

  Future<OnboardingWallpaperVm?> _fetchWotdVm() async {
    try {
      final result = await _wallOfTheDayRepository.fetchToday();
      if (result.isSuccess && result.data != null) {
        final wotd = result.data!;
        if (wotd.url.isEmpty) {
          return null;
        }
        return OnboardingWallpaperVm(
          fullUrl: wotd.url,
          thumbnailUrl: wotd.thumbnailUrl.isNotEmpty ? wotd.thumbnailUrl : wotd.url,
          title: wotd.title.isNotEmpty ? wotd.title : 'Wall of the Day',
          authorName: wotd.photographer,
          sourceCategory: '',
        );
      }
    } catch (_) {}
    return null;
  }

  Future<bool> performAction(String fullUrl) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return WallpaperService.setWallpaperFromSource(fullUrl, WallpaperTarget.both);
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
