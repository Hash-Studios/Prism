import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';
import 'package:mocktail/mocktail.dart';

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
}) => quizWallOf(
  quizItem(id, tags: tags, colors: colors),
  category: category,
  wildCard: wildCard,
);

/// A plan of [rounds] rounds. Left walls are dark and minimal, right walls are light and busy.
/// Round 3 (index 2) is a wild card.
TasteQuizPlan quizPlan({int rounds = 6}) => TasteQuizPlan(
  rounds: <QuizRound>[
    for (int i = 0; i < rounds; i++)
      QuizRound(
        left: quizWall('l$i', wildCard: i == 2, tags: <String>['dark', 'minimal', 'neon']),
        right: quizWall('r$i', wildCard: i == 2, tags: <String>['bright', 'city', 'beach']),
      ),
  ],
);

class QuizFeedMock extends Mock implements PersonalizedFeedRepository {}

/// A feed whose primed first page holds [items] in order.
QuizFeedMock quizFeed([List<FeedItemEntity> items = const <FeedItemEntity>[]]) {
  final QuizFeedMock feed = QuizFeedMock();
  when(
    feed.primeFirstPage,
  ).thenAnswer((_) async => PersonalizedFeedPage(items: items, hasMore: true, usedKeys: const <String>[]));
  return feed;
}
