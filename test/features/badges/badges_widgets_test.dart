import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/dtos/public_user_doc_dto.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:Prism/features/badges/views/widgets/badge_celebrate_host.dart';
import 'package:Prism/features/badges/views/widgets/badge_celebrate_sheet.dart';
import 'package:Prism/features/badges/views/widgets/profile_badge_row.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/rewards/views/widgets/daily_claim_host.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

class _Repo implements BadgeRepository {
  final ValueNotifier<List<EarnedBadge>> queue = ValueNotifier<List<EarnedBadge>>(const <EarnedBadge>[]);

  @override
  ValueListenable<List<EarnedBadge>> get unseen => queue;

  @override
  Future<Result<List<Badge>>> check() async => Result.success(<Badge>[]);

  @override
  void markSeen(String id) => queue.value = queue.value.where((b) => b.id != id).toList();
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Future<void> _openBadge(WidgetTester tester, EarnedBadge badge, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) =>
              TextButton(onPressed: () => showBadgeCelebrateSheet(context, badge), child: const Text('open')),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  test('catalog matches the server badge ids', () {
    expect(badgeCatalog.map((b) => b.id), <String>[
      'challenge_winner',
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

  test('public user dto reads badge ids from the profiles badges list', () {
    final dto = PublicUserDocDto.fromJson(<String, dynamic>{
      'badges': <Object?>['creator', 'early_adopter'],
    });
    expect(dto.badges, <String>['creator', 'early_adopter']);
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
    Future<void> open(EarnedBadge badge) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) =>
                TextButton(onPressed: () => showBadgeCelebrateSheet(context, badge), child: const Text('open')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    await open(const EarnedBadge(id: 'week_warrior', coins: 25));
    expect(find.text('Week Warrior'), findsOneWidget);
    expect(find.text('+25'), findsOneWidget);
    await tester.tap(find.text('Nice'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BadgeCelebrateSheet), findsNothing);

    await open(const EarnedBadge(id: 'collector', coins: 0));
    expect(find.text('Collector'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('creator approval shows only the confirmed inline amount and keeps Glint calm', (tester) async {
    DailyMomentConfig.enabledOverride = true;
    addTearDown(() => DailyMomentConfig.enabledOverride = null);
    await _openBadge(tester, const EarnedBadge(id: 'creator', coins: 37));
    expect(find.text('+37 coins'), findsOneWidget);
    expect(find.text('+37'), findsNothing);
    expect(tester.widget<Text>(find.text('+37 coins')).style!.fontSize, lessThan(44));
    final inline = find.ancestor(of: find.text('+37 coins'), matching: find.byType(Wrap));
    expect(inline, findsOneWidget);
    expect(find.descendant(of: inline, matching: find.text('Get a wallpaper approved')), findsOneWidget);
    expect(tester.widget<Glint>(find.byType(Glint)).mood, GlintMood.calm);
    final announcement = tester.widget<Semantics>(
      find.ancestor(of: find.text('+37 coins'), matching: find.byType(Semantics)).first,
    );
    expect(announcement.properties.liveRegion, isTrue);

    await tester.tap(find.text('Nice'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await _openBadge(tester, const EarnedBadge(id: 'creator', coins: 0));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('creator approval keeps the legacy amount when the flag is off', (tester) async {
    DailyMomentConfig.enabledOverride = false;
    addTearDown(() => DailyMomentConfig.enabledOverride = null);
    await _openBadge(tester, const EarnedBadge(id: 'creator', coins: 37));
    expect(find.text('+37'), findsOneWidget);
    expect(tester.widget<Text>(find.text('+37')).style!.fontSize, 44);
    expect(tester.widget<Glint>(find.byType(Glint)).mood, GlintMood.celebrate);
  });

  testWidgets('inline creator approval wraps on a narrow screen with large text', (tester) async {
    DailyMomentConfig.enabledOverride = true;
    addTearDown(() => DailyMomentConfig.enabledOverride = null);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _openBadge(tester, const EarnedBadge(id: 'creator', coins: 37), textScale: 3);
    expect(find.text('+37 coins'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    await tester.pump();
    expect(find.text('Collector'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Nice'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Nice'), findsNothing);
    expect(repo.queue.value, isEmpty);
  });

  testWidgets('host waits while another route is on top, then shows without polling', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    getIt.registerSingleton<BadgeRepository>(repo);
    addTearDown(getIt.reset);

    await tester.pumpWidget(
      _app(
        BadgeCelebrateHost(
          onSeeRewards: () {},
          child: Builder(
            builder: (context) => Scaffold(
              body: const Center(child: Text('home')),
              floatingActionButton: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Center(child: Text('other route'))),
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(find.text('other route'), findsOneWidget);
    repo.queue.value = const <EarnedBadge>[EarnedBadge(id: 'creator', coins: 50)];
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Creator'), findsNothing);

    Navigator.of(tester.element(find.text('other route'))).pop();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Creator'), findsOneWidget);
  });

  testWidgets('daily claim and badge sheets wait for each other instead of stacking', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    DailyMomentConfig.enabledOverride = false;
    addTearDown(() => DailyMomentConfig.enabledOverride = null);
    final backend = CoinsTestBackend();
    await backend.install();
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    backend.onCall = (_, _) async => <String, Object>{
      ...CoinsTestBackend.claimPayload,
      'todayLocalKey': today,
      'timezoneOffsetMinutes': 0,
    };
    addTearDown(() async {
      CoinsService.instance.consumeLastClaim();
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });
    await CoinsService.instance.claimDailyLoginAndStreakIfEligible();

    final repo = _Repo();
    repo.queue.value = const <EarnedBadge>[EarnedBadge(id: 'creator', coins: 50)];
    getIt.registerSingleton<BadgeRepository>(repo);
    await tester.pumpWidget(
      _app(
        DailyClaimSheetHost(
          onSeeRewards: () {},
          child: BadgeCelebrateHost(onSeeRewards: () {}, child: const Text('home')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Day 3'), findsWidgets);
    expect(find.text('Creator'), findsNothing);

    await tester.tap(find.text('Nice'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Day 3'), findsNothing);
    expect(find.text('Creator'), findsOneWidget);

    await tester.tap(find.text('Nice'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repo.queue.value, isEmpty);

    repo.queue.value = const <EarnedBadge>[EarnedBadge(id: 'collector', coins: 0)];
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Collector'), findsOneWidget);
    CoinsService.instance.resetSession();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = '${backend.userId}-second'
      ..loggedIn = true
      ..coins = 100;
    await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Day 3'), findsNothing);

    await tester.tap(find.text('Nice'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Collector'), findsNothing);
    expect(find.text('Day 3'), findsWidgets);
  });
}
