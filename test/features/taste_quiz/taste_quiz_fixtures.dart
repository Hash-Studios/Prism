import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';

/// A Prism wall with the given tags and palette ids (most dominant first).
FeedItemEntity quizItem(
  String id, {
  List<String> tags = const <String>[],
  List<String> colors = const <String>[],
  String? author,
}) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/thumb_$id.jpg',
      authorEmail: author ?? '$id@example.com',
    ),
    tags: tags,
    colors: colors,
  ),
);

/// A quiz wall read the way the app reads it.
QuizWall quizWall(
  String id, {
  String category = 'Nature',
  bool wildCard = false,
  List<String> tags = const <String>[],
  List<String> colors = const <String>[],
}) => quizWallOf(quizItem(id, tags: tags, colors: colors), category: category, wildCard: wildCard);

/// A plan of [rounds] rounds. Left walls are dark and minimal, right walls are light and busy.
/// Round 3 (index 2) is a wild card. [pool] walls are left over for the tuning preview.
TasteQuizPlan quizPlan({int rounds = 6, List<QuizWall> pool = const <QuizWall>[]}) => TasteQuizPlan(
  rounds: <QuizRound>[
    for (int i = 0; i < rounds; i++)
      QuizRound(
        left: quizWall('l$i', wildCard: i == 2, tags: <String>['dark', 'minimal', 'neon']),
        right: quizWall('r$i', wildCard: i == 2, tags: <String>['bright', 'city', 'beach']),
      ),
  ],
  pool: pool,
);
