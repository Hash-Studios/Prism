import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/profile_completeness/services/profile_completeness_nudge_service.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_nudge_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_user_fixture.dart';

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

class _Harness {
  _Harness({this.answer = ProfileCompletenessNudgeAction.notNow, this.session = 3, this.slotFree = true}) {
    service = ProfileCompletenessNudgeService(
      readPrefValue: (key, {defaultValue = false}) => prefs[key] ?? defaultValue,
      writePrefValue: (key, value) async => prefs[key] = value,
      trackEvent: (event) async => events.add(event),
      sheetLauncher: (context, {required status}) async {
        launchCount += 1;
        return answer;
      },
      openEditProfile: (context) async => editOpened = true,
      sessionNumber: () => session,
      claimStartupSlot: () {
        slotClaims += 1;
        return slotFree;
      },
    );
  }

  final ProfileCompletenessNudgeAction answer;
  final int session;
  final bool slotFree;
  int slotClaims = 0;
  final Map<String, bool> prefs = <String, bool>{};
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];
  int launchCount = 0;
  bool editOpened = false;
  late final ProfileCompletenessNudgeService service;
}

void main() {
  testWidgets('does not show modal for logged-out users', (tester) async {
    app_state.prismUser = profileUser(id: 'logged_out_user', loggedIn: false, premium: true);
    final harness = _Harness();

    await harness.service.maybeShowNudge(await _pumpContext(tester), sourceContext: 'dashboard_entry');

    expect(harness.launchCount, 0);
    expect(harness.events, isEmpty);
  });

  testWidgets('shows the modal to signed-in users on the free plan', (tester) async {
    app_state.prismUser = profileUser(id: 'free_user', username: 'creator_01');
    final harness = _Harness();

    await harness.service.maybeShowNudge(await _pumpContext(tester), sourceContext: 'dashboard_entry');

    expect(harness.launchCount, 1);
  });

  testWidgets('does not show modal for already complete users', (tester) async {
    app_state.prismUser = profileUser(
      id: 'complete_user',
      premium: true,
      profilePhoto: 'https://example.com/photo.png',
      username: 'creator_01',
      bio: 'hello',
      links: const <String, String>{'github': 'https://github.com/creator'},
    );
    final harness = _Harness();

    await harness.service.maybeShowNudge(await _pumpContext(tester), sourceContext: 'dashboard_entry');

    expect(harness.launchCount, 0);
  });

  testWidgets('shows once per user and persists shown flag', (tester) async {
    app_state.prismUser = profileUser(id: 'incomplete_user', premium: true, username: 'creator_01');
    final harness = _Harness();

    final context = await _pumpContext(tester);
    await harness.service.maybeShowNudge(context, sourceContext: 'dashboard_entry');
    await harness.service.maybeShowNudge(context, sourceContext: 'dashboard_entry');

    expect(harness.launchCount, 1);
    expect(harness.prefs[harness.service.shownPrefKeyForUser('incomplete_user')], isTrue);
  });

  testWidgets('tracks the view and the tapped action', (tester) async {
    app_state.prismUser = profileUser(id: 'tracked_user', premium: true, username: 'creator_01');
    final harness = _Harness();

    await harness.service.maybeShowNudge(await _pumpContext(tester), sourceContext: 'dashboard_entry');

    final viewed = harness.events.whereType<ProfileCompletenessNudgeViewedEvent>().single;
    expect((viewed.sourceContext, viewed.progressPercent, viewed.missingStepsCount), ('dashboard_entry', 25, 3));
    final tapped = harness.events.whereType<ProfileCompletenessActionTappedEvent>().single;
    expect((tapped.action, tapped.progressPercent), ('not_now', 25));
    expect(harness.editOpened, isFalse);
  });

  testWidgets('complete-now action attempts to open edit profile route', (tester) async {
    app_state.prismUser = profileUser(id: 'cta_user', premium: true, username: 'u1');
    final harness = _Harness(answer: ProfileCompletenessNudgeAction.completeNow);

    await harness.service.maybeShowNudge(await _pumpContext(tester), sourceContext: 'dashboard_entry');

    expect(harness.editOpened, isTrue);
  });

  testWidgets('waits for the third session', (tester) async {
    app_state.prismUser = profileUser(id: 'new_user', username: 'creator_01');
    final context = await _pumpContext(tester);

    final second = _Harness(session: 2);
    await second.service.maybeShowNudge(context, sourceContext: 'dashboard_entry');
    expect(second.launchCount, 0);
    expect(second.prefs, isEmpty);

    final third = _Harness();
    await third.service.maybeShowNudge(context, sourceContext: 'dashboard_entry');
    expect(third.launchCount, 1);
  });

  testWidgets('stays away while another startup sheet holds the slot, and tries again later', (tester) async {
    app_state.prismUser = profileUser(id: 'busy_user', username: 'creator_01');
    final context = await _pumpContext(tester);

    final busy = _Harness(slotFree: false);
    await busy.service.maybeShowNudge(context, sourceContext: 'dashboard_entry');
    expect(busy.slotClaims, 1);
    expect(busy.launchCount, 0);
    expect(busy.prefs, isEmpty);
    expect(busy.events, isEmpty);
  });

  testWidgets('does not claim the slot when it has nothing to show', (tester) async {
    app_state.prismUser = profileUser(id: 'logged_out_user', loggedIn: false);
    final harness = _Harness();

    await harness.service.maybeShowNudge(await _pumpContext(tester), sourceContext: 'dashboard_entry');

    expect(harness.slotClaims, 0);
  });
}
