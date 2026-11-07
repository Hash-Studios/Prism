import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/wall_mood_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pink and white with a Sunset label is dreamy only', () {
    expect(
      wallMoodsOf(const WallMoodFields(colors: <String>['pink', 'white'], visionLabels: <String>['Sunset'])),
      <WallMood>[WallMood.dreamy],
    );
  });

  test('a grey first colour is not dreamy', () {
    final List<WallMood> moods = wallMoodsOf(
      const WallMoodFields(colors: <String>['grey', 'white'], visionLabels: <String>['Sunset']),
    );

    expect(moods, isNot(contains(WallMood.dreamy)));
    expect(moods, isEmpty);
  });

  test('black and grey with a night label is dark_quiet only', () {
    expect(
      wallMoodsOf(const WallMoodFields(colors: <String>['black', 'grey'], visionLabels: <String>['night'])),
      <WallMood>[WallMood.darkQuiet],
    );
  });

  test('a duo tag matches duo_reveal after trimming and lowercasing', () {
    expect(wallMoodsOf(const WallMoodFields(tags: <String>[' DUO-Reveal '])), <WallMood>[WallMood.duoReveal]);
  });

  test('a great spatial tier is spatial_ready', () {
    expect(
      wallMoodsOf(
        WallMoodFields.fromDoc(<String, dynamic>{
          'spatial': <String, dynamic>{'tier': 'great'},
        }),
      ),
      <WallMood>[WallMood.spatialReady],
    );
  });

  test('an auto depth tier is depth_ready', () {
    expect(
      wallMoodsOf(
        WallMoodFields.fromDoc(<String, dynamic>{
          'depth': <String, dynamic>{'tier': 'auto'},
        }),
      ),
      <WallMood>[WallMood.depthReady],
    );
  });

  test('an empty doc has no moods', () {
    expect(wallMoodsOf(WallMoodFields.fromDoc(<String, dynamic>{})), isEmpty);
  });

  test('fromDoc ignores non-string entries in the list fields', () {
    final WallMoodFields fields = WallMoodFields.fromDoc(<String, dynamic>{
      'tags': <Object?>[1, ' DUO-Reveal ', null],
      'colors': <Object?>['black', 2],
      'visionLabels': <Object?>[null, 'Night'],
    });

    expect(fields.tags, <String>[' DUO-Reveal ']);
    expect(fields.colors, <String>['black']);
    expect(fields.visionLabels, <String>['Night']);
    expect(wallMoodsOf(fields), <WallMood>[WallMood.duoReveal, WallMood.darkQuiet]);
  });
}
