import 'package:Prism/features/rewards/domain/creator_progress.dart';
import 'package:Prism/features/rewards/views/widgets/creator_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CreatorProgress creatorFixture({int approved = 2, int members = 7}) => CreatorProgress.fromMap(<String, dynamic>{
  'version': 1,
  'trackedSinceMs': DateTime.utc(2026, 10, 2).millisecondsSinceEpoch,
  'approvedWalls': approved,
  'uniqueMembers': members,
  'awardedIds': <String>['approved_1'],
  'milestones': <Object?>[
    <String, Object?>{'id': 'approved_1', 'metric': 'approvedWalls', 'target': 1, 'xp': 50},
    <String, Object?>{'id': 'approved_5', 'metric': 'approvedWalls', 'target': 5, 'xp': 100},
    <String, Object?>{'id': 'members_10', 'metric': 'uniqueMembers', 'target': 10, 'xp': 50},
  ],
  'weeks': <Object?>[
    <String, Object?>{'weekKey': '2026-W42', 'approvedWalls': 2, 'newMembers': 7, 'xp': 50},
    <String, Object?>{'weekKey': '2026-W39', 'approvedWalls': 99, 'newMembers': 99, 'xp': 999},
  ],
})!;

void main() {
  test('uses exact current/previous ISO weeks across year rollover', () {
    final CreatorProgress progress = creatorFixture();
    expect(progress.week(DateTime.utc(2026, 10, 18)).newMembers, 7);
    expect(progress.week(DateTime.utc(2026, 10, 11)).newMembers, 0);
    expect(progress.week(DateTime.utc(2027)).weekKey, '2026-W53');
    expect(progress.week(DateTime.utc(2027, 1, 4)).weekKey, '2027-W01');
    expect(progress.next(CreatorMetric.approvedWalls)?.xp, 100);
    expect(CreatorProgress.fromMap(null), isNull);
    expect(CreatorProgress.fromMap(<String, Object?>{'version': 2}), isNull);
  });

  Future<void> pump(WidgetTester tester, CreatorProgressState state, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CreatorProgressView(state: state, now: DateTime.utc(2026, 10, 18), onRefresh: () {}),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('unknown is distinct from a real loaded zero', (tester) async {
    await pump(tester, const CreatorProgressState());
    expect(find.textContaining('Progress appears after your first qualifying contribution.'), findsOneWidget);
    expect(find.textContaining('0 new members'), findsNothing);
    await pump(
      tester,
      CreatorProgressState(progress: creatorFixture(approved: 0, members: 0), status: CreatorProgressStatus.loaded),
    );
    expect(find.text('Approved wallpapers: 0 / 5'), findsOneWidget);
    expect(find.textContaining('Progress appears after your first qualifying contribution.'), findsNothing);
  });

  testWidgets('shows dated history and server milestones with no stale week relabeling', (tester) async {
    await pump(tester, CreatorProgressState(progress: creatorFixture(), status: CreatorProgressStatus.loaded));
    expect(find.text('12–18 Oct 2026 UTC'), findsOneWidget);
    expect(find.text('Approved wallpapers: 2 / 5'), findsOneWidget);
    expect(find.text('Next milestone: +100 XP'), findsOneWidget);
    expect(find.textContaining('7 new members favourited'), findsOneWidget);
    expect(find.textContaining('99 new qualifying'), findsNothing);
    await tester.tap(find.text('What counts & history'));
    await tester.pumpAndSettle();
    expect(find.text('Tracking since 2 Oct 2026 UTC'), findsOneWidget);
    expect(find.text('5–11 Oct 2026 UTC'), findsOneWidget);
    expect(find.textContaining('Older uploads may be ineligible'), findsOneWidget);
    expect(find.textContaining('at least seven days old'), findsOneWidget);
  });

  testWidgets('saved unavailable state and 320px 2x text have no overflow', (tester) async {
    await pump(
      tester,
      CreatorProgressState(progress: creatorFixture(), status: CreatorProgressStatus.unavailable),
      scale: 2,
    );
    expect(find.text('Saved progress. Refresh is unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
