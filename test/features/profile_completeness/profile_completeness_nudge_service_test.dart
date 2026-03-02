import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/profile_completeness/services/profile_completeness_nudge_service.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_nudge_sheet.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';

const String _defaultPhotoUrl =
    'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4';

PrismUsersV2 _user({
  required String id,
  required bool loggedIn,
  String profilePhoto = _defaultPhotoUrl,
  String username = '',
  String bio = '',
  Map<dynamic, dynamic>? links,
}) {
  final String now = DateTime.now().toUtc().toIso8601String();
  return PrismUsersV2(
    username: username,
    email: 'user@example.com',
    id: id,
    createdAt: now,
    premium: false,
    lastLoginAt: now,
    links: links ?? <String, dynamic>{},
    followers: <dynamic>[],
    following: <dynamic>[],
    profilePhoto: profilePhoto,
    bio: bio,
    loggedIn: loggedIn,
    badges: <Badge>[],
    subPrisms: <dynamic>[],
    coins: 0,
    transactions: <PrismTransaction>[],
    name: '',
    coverPhoto: '',
  );
}

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  testWidgets('does not show modal for logged-out users', (tester) async {
    app_state.prismUser = _user(id: 'logged_out_user', loggedIn: false);

    int launchCount = 0;
    final Map<String, dynamic> prefs = <String, dynamic>{};

    final service = ProfileCompletenessNudgeService(
      isPrefsOpen: () => true,
      readPrefValue: (key, {defaultValue}) => prefs[key] ?? defaultValue,
      writePrefValue: (key, value) async => prefs[key] = value,
      sheetLauncher: (context, {required status}) async {
        launchCount += 1;
        return ProfileCompletenessNudgeAction.notNow;
      },
    );

    final context = await _pumpContext(tester);
    await service.maybeShowNudge(context, sourceContext: 'dashboard_entry');

    expect(launchCount, 0);
  });

  testWidgets('does not show modal for already complete users', (tester) async {
    app_state.prismUser = _user(
      id: 'complete_user',
      loggedIn: true,
      profilePhoto: 'https://example.com/photo.png',
      username: 'creator_01',
      bio: 'hello',
      links: <String, dynamic>{'github': 'https://github.com/creator'},
    );

    int launchCount = 0;
    final Map<String, dynamic> prefs = <String, dynamic>{};

    final service = ProfileCompletenessNudgeService(
      isPrefsOpen: () => true,
      readPrefValue: (key, {defaultValue}) => prefs[key] ?? defaultValue,
      writePrefValue: (key, value) async => prefs[key] = value,
      sheetLauncher: (context, {required status}) async {
        launchCount += 1;
        return ProfileCompletenessNudgeAction.notNow;
      },
    );

    final context = await _pumpContext(tester);
    await service.maybeShowNudge(context, sourceContext: 'dashboard_entry');

    expect(launchCount, 0);
  });

  testWidgets('shows once per user and persists shown flag', (tester) async {
    app_state.prismUser = _user(id: 'incomplete_user', loggedIn: true, username: 'creator_01');

    int launchCount = 0;
    final Map<String, dynamic> prefs = <String, dynamic>{};

    final service = ProfileCompletenessNudgeService(
      isPrefsOpen: () => true,
      readPrefValue: (key, {defaultValue}) => prefs[key] ?? defaultValue,
      writePrefValue: (key, value) async => prefs[key] = value,
      sheetLauncher: (context, {required status}) async {
        launchCount += 1;
        return ProfileCompletenessNudgeAction.notNow;
      },
    );

    final context = await _pumpContext(tester);
    await service.maybeShowNudge(context, sourceContext: 'dashboard_entry');
    await service.maybeShowNudge(context, sourceContext: 'dashboard_entry');

    final String key = service.shownPrefKeyForUser(app_state.prismUser.id);
    expect(launchCount, 1);
    expect(prefs[key], isTrue);
  });

  testWidgets('incomplete users can be shown from onboarding and dashboard triggers', (tester) async {
    final Map<String, dynamic> prefs = <String, dynamic>{};
    final List<AnalyticsEvent> trackedEvents = <AnalyticsEvent>[];
    int launchCount = 0;

    final service = ProfileCompletenessNudgeService(
      isPrefsOpen: () => true,
      readPrefValue: (key, {defaultValue}) => prefs[key] ?? defaultValue,
      writePrefValue: (key, value) async => prefs[key] = value,
      trackEvent: (event) async => trackedEvents.add(event),
      sheetLauncher: (context, {required status}) async {
        launchCount += 1;
        return ProfileCompletenessNudgeAction.notNow;
      },
    );

    final context = await _pumpContext(tester);

    app_state.prismUser = _user(id: 'onboarding_user', loggedIn: true, username: 'u1');
    await service.maybeShowNudge(context, sourceContext: 'onboarding_done');

    app_state.prismUser = _user(id: 'dashboard_user', loggedIn: true, username: 'u2');
    await service.maybeShowNudge(context, sourceContext: 'dashboard_entry');

    expect(launchCount, 2);
    expect(
      trackedEvents.whereType<ProfileCompletenessNudgeViewedEvent>().map((e) => e.sourceContext),
      containsAll(<String>['onboarding_done', 'dashboard_entry']),
    );
  });

  testWidgets('complete-now action attempts to open edit profile route', (tester) async {
    app_state.prismUser = _user(id: 'cta_user', loggedIn: true, username: 'u1');

    bool editOpened = false;
    final Map<String, dynamic> prefs = <String, dynamic>{};

    final service = ProfileCompletenessNudgeService(
      isPrefsOpen: () => true,
      readPrefValue: (key, {defaultValue}) => prefs[key] ?? defaultValue,
      writePrefValue: (key, value) async => prefs[key] = value,
      sheetLauncher: (context, {required status}) async => ProfileCompletenessNudgeAction.completeNow,
      openEditProfile: (context) async {
        editOpened = true;
      },
    );

    final context = await _pumpContext(tester);
    await service.maybeShowNudge(context, sourceContext: 'dashboard_entry');

    expect(editOpened, isTrue);
  });
}
