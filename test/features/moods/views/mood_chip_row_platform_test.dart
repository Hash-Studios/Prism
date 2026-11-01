import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/moods/biz/moods_cubit.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/widgets/mood_chip_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import 'mood_test_support.dart';

const List<MoodList> _allMoods = <MoodList>[
  MoodList(mood: WallMood.dreamy, wallIds: <String>['wall']),
  MoodList(mood: WallMood.spatialReady, wallIds: <String>['wall']),
  MoodList(mood: WallMood.depthReady, wallIds: <String>['wall']),
];

Future<void> _pumpChips(WidgetTester tester, {required int? iosMajor}) async {
  final cubit = MoodsCubit(FakeMoodRepository(moods: _allMoods), iosMajor: () async => iosMajor);
  addTearDown(cubit.close);
  await cubit.load();
  await tester.pumpWidget(
    moodTestApp(
      Scaffold(
        body: BlocBuilder<MoodsCubit, List<MoodList>>(
          bloc: cubit,
          builder: (_, moods) => MoodChipRow(moods: moods),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(AnalyticsRuntime.reset);

  testWidgets('on Android only the platform-neutral mood shows', (tester) async {
    await _pumpChips(tester, iosMajor: null);

    expect(find.text('Dreamy'), findsOneWidget);
    expect(find.text('Spatial ready'), findsNothing);
    expect(find.text('Depth ready'), findsNothing);
  });

  testWidgets('iOS 26 shows the Spatial and Depth moods', (tester) async {
    await _pumpChips(tester, iosMajor: 26);

    expect(find.text('Spatial ready'), findsOneWidget);
    expect(find.text('Depth ready'), findsOneWidget);
  });

  testWidgets('iOS 18 shows Depth ready but not Spatial ready', (tester) async {
    await _pumpChips(tester, iosMajor: 18);

    expect(find.text('Depth ready'), findsOneWidget);
    expect(find.text('Spatial ready'), findsNothing);
  });
}
