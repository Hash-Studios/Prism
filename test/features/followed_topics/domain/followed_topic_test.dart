import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the topic ids match the classifier categories and Home moods', () {
    expect(prismClassifierCategories, <String>{
      'Nature',
      'Architecture',
      'Cars',
      'Anime',
      'Gaming',
      'Space',
      'Ocean',
      'Flowers',
      'Neon',
      'Dark',
      'Abstract',
      '3D Render',
      'Minimal',
      'Gradient',
      'AI Art',
      'Cyberpunk',
      'Vintage',
      'Landscape',
      'Galaxy',
      'Pastel',
    });
    expect(WallMood.values.map((WallMood mood) => FollowedTopic.mood(mood).key).toSet(), <String>{
      'mood:duo_reveal',
      'mood:dreamy',
      'mood:dark_quiet',
      'mood:bright_bold',
      'mood:minimal',
      'mood:spatial_ready',
      'mood:depth_ready',
    });
  });

  test('a category is found in any letter case and keeps the classifier spelling', () {
    expect(FollowedTopic.category('Pastel')!.key, 'category:Pastel');
    expect(FollowedTopic.category('pastel')!.key, 'category:Pastel');
  });

  test('a stock-only category or a name the classifier does not write has no topic', () {
    expect(FollowedTopic.category('AMOLED'), isNull);
    expect(FollowedTopic.category('Aesthetic'), isNull);
    expect(FollowedTopic.category('Desktop'), isNull);
  });

  test('a mood key uses the mood id', () {
    expect(FollowedTopic.mood(WallMood.dreamy).key, 'mood:dreamy');
  });

  test('parse reads a known category or mood key', () {
    expect(FollowedTopic.parse('category:Pastel')!.key, 'category:Pastel');
    expect(FollowedTopic.parse('mood:dark_quiet')!.wallMood, WallMood.darkQuiet);
  });

  test('parse rejects a wrong case, an unknown mood, a bare name, a non-string and free text', () {
    expect(FollowedTopic.parse('category:pastel'), isNull);
    expect(FollowedTopic.parse('mood:nope'), isNull);
    expect(FollowedTopic.parse('Pastel'), isNull);
    expect(FollowedTopic.parse(42), isNull);
    expect(FollowedTopic.parse('free text'), isNull);
  });
}
