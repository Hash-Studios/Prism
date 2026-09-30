import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/dtos/public_user_doc_dto.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:Prism/features/badges/views/widgets/badge_celebrate_host.dart';
import 'package:Prism/features/badges/views/widgets/badge_celebrate_sheet.dart';
import 'package:Prism/features/badges/views/widgets/profile_badge_row.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';

class _Repo implements BadgeRepository {
  final ValueNotifier<List<EarnedBadge>> queue = ValueNotifier<List<EarnedBadge>>(const <EarnedBadge>[]);

  @override
  ValueListenable<List<EarnedBadge>> get unseen => queue;

  @override
  Future<Result<List<Badge>>> check() async => Result.success(<Badge>[]);

  @override
  void markSeen(String id) => queue.value = queue.value.where((b) => b.id != id).toList();
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('catalog matches the server badge ids', () {
    expect(badgeCatalog.map((b) => b.id), <String>[
      'week_warrior',
      'streak_master',
      'creator',
      'ai_artist',
      'prism_veteran',
      'collector',
      'art_curator',
      'social_butterfly',
      'profile_complete',
    ]);
    expect(badgeInfo('nope'), isNull);
  });

  test('public user dto reads badge ids from the badges array and tolerates junk', () {
    final dto = PublicUserDocDto.fromJson(<String, dynamic>{
      'badges': <Object?>[
        <String, Object?>{'id': 'creator', 'name': 'Creator'},
        <String, Object?>{'name': 'no id'},
        'junk',
      ],
    });
    expect(dto.badges, <String>['creator']);
    expect(PublicUserDocDto.fromJson(<String, dynamic>{}).badges, isEmpty);
  });

  testWidgets('profile row shows known badges only, and nothing when empty', (tester) async {
    await tester.pumpWidget(_app(const ProfileBadgeRow(badgeIds: <String>['creator', 'creator', 'from_the_future'])));
    expect(find.byType(Tooltip), findsOneWidget);
    expect(find.bySemanticsLabel('Creator badge'), findsOneWidget);

    await tester.pumpWidget(_app(const ProfileBadgeRow(badgeIds: <String>[])));
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('celebrate sheet shows the badge and its coins, and hides coins at zero', (tester) async {
    await tester.pumpWidget(_app(const BadgeCelebrateSheet(badge: EarnedBadge(id: 'week_warrior', coins: 25))));
    await tester.pump();
    expect(find.text('Week Warrior'), findsOneWidget);
    expect(find.text('+25'), findsOneWidget);

    await tester.pumpWidget(_app(const BadgeCelebrateSheet(badge: EarnedBadge(id: 'collector', coins: 0))));
    await tester.pump();
    expect(find.text('Collector'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('host shows each queued badge once, in order', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    getIt.registerSingleton<BadgeRepository>(repo);
    addTearDown(getIt.reset);
    repo.queue.value = const <EarnedBadge>[
      EarnedBadge(id: 'creator', coins: 50),
      EarnedBadge(id: 'collector', coins: 0),
    ];

    await tester.pumpWidget(_app(BadgeCelebrateHost(onSeeRewards: () {}, child: const Text('home'))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Creator'), findsOneWidget);

    await tester.tap(find.text('Nice'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Collector'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Nice'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Nice'), findsNothing);
    expect(repo.queue.value, isEmpty);
  });
}
