import 'dart:async';
import 'dart:math';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/anime_content_filter.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/repositories/taste_quiz_repository.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: TasteQuizRepository)
class TasteQuizRepositoryImpl implements TasteQuizRepository {
  TasteQuizRepositoryImpl(this._categoryFeedRepository, this._settingsLocal, {@ignoreParam Random? random})
    : _random = random ?? Random();

  final CategoryFeedRepository _categoryFeedRepository;
  final SettingsLocalDataSource _settingsLocal;
  final Random _random;

  /// The whole load, so a slow network can never hold the user on a blank step.
  static const Duration budget = Duration(seconds: 3);

  /// One slow category gives up first, so the others can still fill the quiz.
  static const Duration _categoryBudget = Duration(milliseconds: 2500);
  static const int _interestCategories = 3;
  static const int _wildCategories = 2;

  @override
  Future<TasteQuizPlan?> loadPlan(List<String> interests) async {
    try {
      return await _load(interests).timeout(budget);
    } catch (error) {
      logger.w('[TasteQuiz] walls did not load, so the quiz is skipped: $error');
      return null;
    }
  }

  Future<TasteQuizPlan?> _load(List<String> interests) async {
    final categoriesResult = await _categoryFeedRepository.getCategories();
    final List<CategoryEntity>? categories = categoriesResult.data;
    if (categoriesResult.isFailure || categories == null) return null;
    final Set<String> picked = interests.map((name) => name.toLowerCase()).toSet();
    final bool showAnime = AnimeContentFilter.showsAnime(_settingsLocal);
    final List<CategoryEntity> usable =
        categories.where((category) => category.name != OnboardingV2Config.excludedCategory).toList()..shuffle(_random);
    final Iterable<CategoryEntity> interestCategories = usable
        .where((category) => picked.contains(category.name.toLowerCase()))
        .take(_interestCategories);
    final Iterable<CategoryEntity> wildCategories = usable
        .where((category) => !picked.contains(category.name.toLowerCase()))
        .where((category) => showAnime || category.name.toLowerCase() != 'anime')
        .take(_wildCategories);
    final List<List<QuizWall>> walls = await Future.wait(<Future<List<QuizWall>>>[
      for (final CategoryEntity category in interestCategories) _walls(category, wildCard: false),
      for (final CategoryEntity category in wildCategories) _walls(category, wildCard: true),
    ]);
    return planTasteQuiz(walls.expand((list) => list).toList(), _random);
  }

  Future<List<QuizWall>> _walls(CategoryEntity category, {required bool wildCard}) async {
    try {
      final result = await _categoryFeedRepository
          .fetchCategoryFeed(category: category, refresh: false)
          .timeout(_categoryBudget);
      return (result.data?.items ?? const [])
          .where((item) => item.wallpaperCore.thumbnailUrl.trim().isNotEmpty)
          .map((item) => quizWallOf(item, category: category.name, wildCard: wildCard))
          .toList(growable: false);
    } catch (error) {
      logger.w('[TasteQuiz] ${category.name} walls did not load: $error');
      return const <QuizWall>[];
    }
  }
}
