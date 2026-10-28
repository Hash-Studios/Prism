import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:flutter_test/flutter_test.dart';

MoodList _mood(WallMood mood) => MoodList(mood: mood, wallIds: const <String>[]);

void main() {
  final MoodList dreamy = _mood(WallMood.dreamy);
  final MoodList minimal = _mood(WallMood.minimal);

  test('two moods split the For you grid after rows 4 and 12', () {
    expect(forYouChunks(30, 3, <MoodList>[dreamy, minimal]), <(int, int, MoodList?)>[(0, 12, dreamy), (12, 30, null)]);
    expect(forYouChunks(50, 3, <MoodList>[dreamy, minimal]), <(int, int, MoodList?)>[
      (0, 12, dreamy),
      (12, 36, minimal),
      (36, 50, null),
    ]);
  });

  test('no moods give one chunk with no row', () {
    expect(forYouChunks(30, 3, const <MoodList>[]), <(int, int, MoodList?)>[(0, 30, null)]);
  });

  test('a grid too short for the first row gives one chunk with no row', () {
    expect(forYouChunks(10, 3, <MoodList>[dreamy, minimal]), <(int, int, MoodList?)>[(0, 10, null)]);
  });

  test('a mood row still follows a grid that ends exactly at its boundary', () {
    expect(forYouChunks(12, 3, <MoodList>[dreamy, minimal]), <(int, int, MoodList?)>[(0, 12, dreamy)]);
    expect(forYouChunks(36, 3, <MoodList>[dreamy, minimal]), <(int, int, MoodList?)>[
      (0, 12, dreamy),
      (12, 36, minimal),
    ]);
  });
}
