import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/features/hints/data/feature_hints.dart';
import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

List<Map<String, Object?>> paramsOf(FakeAppAnalytics analytics, String name) => analytics.events
    .where((AnalyticsEvent event) => event.eventName == name)
    .map((AnalyticsEvent event) => event.toWireParameters())
    .toList();

void main() {
  late Map<String, Object?> store;
  late DateTime clockNow;
  late int session;
  late String uid;
  late Map<String, String> remote;
  late int sheets;
  late FakeAppAnalytics analytics;
  late FeatureHints hints;
  late ValueNotifier<bool> paywall;

  FeatureHints makeHints() => FeatureHints(
    read: <T>(String key, T defaultValue) {
      final Object? value = store[key];
      return value is T ? value : defaultValue;
    },
    write: (String key, Object? value) async {
      if (value == null) {
        store.remove(key);
      } else {
        store[key] = value;
      }
    },
    clock: () => clockNow,
    session: () => session,
    userId: () => uid,
    remoteConfig: (String key) => remote[key] ?? '',
    openSheets: () => sheets,
    paywallPresenting: paywall,
  );

  setUp(() {
    StartupModalSlot.reset();
    store = <String, Object?>{};
    clockNow = DateTime(2026, 11, 9, 12);
    session = 3;
    uid = 'user';
    remote = <String, String>{};
    sheets = 0;
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    paywall = ValueNotifier<bool>(false);
    hints = makeHints();
  });

  tearDown(() {
    hints.dispose();
    paywall.dispose();
    StartupModalSlot.reset();
    AnalyticsRuntime.reset();
  });

  test('photoSearch needs 3 views', () {
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isTrue);
  });

  test('variantDots shows on the first view', () {
    expect(hints.view(HintId.variantDots), isTrue);
  });

  test('canShow false still counts the view', () {
    expect(hints.view(HintId.photoSearch, canShow: false), isFalse);
    expect(hints.view(HintId.photoSearch, canShow: false), isFalse);
    expect(hints.view(HintId.photoSearch, canShow: false), isFalse);
    expect(hints.view(HintId.photoSearch), isTrue);
  });

  test('a shown hint never shows again, even after dismiss', () {
    expect(hints.view(HintId.variantDots), isTrue);
    expect(hints.record(HintId.variantDots).shownAt, clockNow);

    hints.dismiss(HintId.variantDots, HintDismissMethod.gotIt);
    expect(hints.view(HintId.variantDots), isFalse);

    clockNow = clockNow.add(const Duration(days: 2));
    expect(hints.view(HintId.variantDots), isFalse);
  });

  test('only one hint is active at a time', () {
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isTrue);
    expect(hints.active, HintId.photoSearch);

    expect(hints.view(HintId.variantDots), isFalse);
    expect(hints.active, HintId.photoSearch);
  });

  test('budget: a second hint waits a day after one shows', () {
    expect(hints.view(HintId.variantDots), isTrue);
    hints.dismiss(HintId.variantDots, HintDismissMethod.gotIt);

    expect(hints.view(HintId.followCategory), isFalse);
    expect(hints.view(HintId.followCategory), isFalse);

    clockNow = clockNow.add(const Duration(hours: 25));
    expect(hints.view(HintId.followCategory), isTrue);
  });

  test('an open sheet blocks showing a hint', () {
    sheets = 1;
    expect(hints.view(HintId.variantDots), isFalse);
  });

  test('setEnabled(false) blocks showing and hides the active hint', () async {
    expect(hints.view(HintId.variantDots), isTrue);

    await hints.setEnabled(false);
    await settle();

    expect(hints.active, isNull);
    expect(hints.enabled, isFalse);
    expect(paramsOf(analytics, 'hint_dismissed'), <Map<String, Object?>>[
      <String, Object?>{'hint_id': 'variant_dots', 'method': 'interrupted'},
    ]);

    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
  });

  test('reset clears only the current user records', () async {
    expect(hints.view(HintId.variantDots), isTrue);
    hints.dismiss(HintId.variantDots, HintDismissMethod.gotIt);

    uid = 'other';
    expect(hints.view(HintId.variantDots), isTrue);
    hints.dismiss(HintId.variantDots, HintDismissMethod.gotIt);

    uid = 'user';
    await hints.reset();

    expect(store.containsKey(FeatureHints.recordsKey('user')), isFalse);
    expect(store.containsKey(FeatureHints.recordsKey('other')), isTrue);
    expect(hints.record(HintId.variantDots).shownAt, isNull);

    clockNow = clockNow.add(const Duration(hours: 25));
    expect(hints.view(HintId.variantDots), isTrue);
  });

  test('remote config hints_enabled false blocks all hints', () {
    remote['hints_enabled'] = 'false';
    expect(hints.view(HintId.variantDots), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
  });

  test('remote config hints_disabled_ids blocks the listed hints and allows the rest', () {
    remote['hints_disabled_ids'] = 'photo_search, folder_hold';

    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);

    expect(hints.view(HintId.folderHold), isFalse);
    expect(hints.view(HintId.folderHold), isFalse);
    expect(hints.view(HintId.folderHold), isFalse);

    expect(hints.view(HintId.variantDots), isTrue);
  });

  test('records are stored per user, and as guest for an empty uid', () {
    expect(hints.view(HintId.variantDots), isTrue);
    expect(store.containsKey('hints.records.user'), isTrue);

    uid = '';
    expect(hints.view(HintId.followCategory), isFalse);
    expect(store.containsKey('hints.records.guest'), isTrue);
  });

  test('a prompt hides the active hint, stores the time and starts the cooldown', () async {
    clockNow = DateTime.now();
    hints.attach();

    expect(hints.view(HintId.variantDots), isTrue);

    StartupModalSlot.markPromptShown();
    await settle();

    expect(hints.active, isNull);
    expect(store['hints.last_prompt_at'], isA<int>());
    expect(paramsOf(analytics, 'hint_dismissed'), <Map<String, Object?>>[
      <String, Object?>{'hint_id': 'variant_dots', 'method': 'interrupted'},
    ]);

    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
  });

  test('feature use after a hint shows is tracked once and marks the hint used', () async {
    hints.attach();

    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isTrue);

    await AnalyticsRuntime.instance.track(const PhotoSearchStartedEvent(signedIn: true, searchId: 'search-1'));
    await settle();

    expect(paramsOf(analytics, 'hint_feature_used'), <Map<String, Object?>>[
      <String, Object?>{'hint_id': 'photo_search'},
    ]);
    expect(hints.record(HintId.photoSearch).used, isTrue);
  });

  test('feature use more than a day after the hint shows is not tracked but still marks used', () async {
    hints.attach();

    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isTrue);
    hints.dismiss(HintId.photoSearch, HintDismissMethod.gotIt);

    clockNow = clockNow.add(const Duration(hours: 25));
    await AnalyticsRuntime.instance.track(const PhotoSearchStartedEvent(signedIn: true, searchId: 'search-2'));
    await settle();

    expect(paramsOf(analytics, 'hint_feature_used'), isEmpty);
    expect(hints.record(HintId.photoSearch).used, isTrue);
  });

  test('a hint whose feature was already used never shows', () async {
    hints.attach();

    await AnalyticsRuntime.instance.track(const PhotoSearchStartedEvent(signedIn: false, searchId: 'search-3'));
    await settle();

    expect(hints.record(HintId.photoSearch).used, isTrue);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.active, isNull);
  });

  test('dismiss with gotIt tracks hint_dismissed', () async {
    expect(hints.view(HintId.variantDots), isTrue);

    hints.dismiss(HintId.variantDots, HintDismissMethod.gotIt);
    await settle();

    expect(hints.active, isNull);
    expect(paramsOf(analytics, 'hint_dismissed'), <Map<String, Object?>>[
      <String, Object?>{'hint_id': 'variant_dots', 'method': 'got_it'},
    ]);
  });
  test('reset retains the daily budget after restart', () async {
    expect(hints.view(HintId.variantDots), isTrue);
    await hints.reset();
    hints.dispose();
    hints = makeHints();

    expect(hints.view(HintId.variantDots), isFalse);
    clockNow = clockNow.add(const Duration(days: 1));
    expect(hints.view(HintId.variantDots), isTrue);
  });

  test('reset retains the weekly budget after restart', () async {
    expect(hints.view(HintId.variantDots), isTrue);
    for (int i = 0; i < 2; i++) {
      clockNow = clockNow.add(const Duration(days: 1));
      await hints.reset();
      expect(hints.view(HintId.variantDots), isTrue);
    }
    await hints.reset();
    clockNow = clockNow.add(const Duration(days: 1));
    hints.dispose();
    hints = makeHints();
    expect(hints.view(HintId.variantDots), isFalse);
  });

  test('pending persistence does not lose views or used records', () async {
    hints.dispose();
    final Completer<void> writes = Completer<void>();
    hints = FeatureHints(
      read: <T>(String key, T fallback) => store[key] is T ? store[key] as T : fallback,
      write: (String key, Object? value) async {
        await writes.future;
        store[key] = value;
      },
      clock: () => clockNow,
      session: () => 3,
      userId: () => uid,
      remoteConfig: (_) => '',
      openSheets: () => 0,
    );
    hints.attach();
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isTrue);
    await AnalyticsRuntime.instance.track(const PhotoSearchStartedEvent(signedIn: true, searchId: 'pending'));
    expect(hints.record(HintId.photoSearch).views, 3);
    expect(hints.record(HintId.photoSearch).used, isTrue);
    expect(hints.record(HintId.photoSearch).shownAt, clockNow);
    writes.complete();
    await settle();
  });

  test('account switch invalidates the active hint without blocking the new user', () {
    expect(hints.view(HintId.variantDots), isTrue);
    uid = 'other';
    expect(hints.active, isNull);
    expect(hints.view(HintId.variantDots), isTrue);
    expect(hints.record(HintId.variantDots).views, 1);
  });

  test('feature use closes its active hint', () async {
    hints.attach();
    hints.view(HintId.photoSearch);
    hints.view(HintId.photoSearch);
    expect(hints.view(HintId.photoSearch), isTrue);
    await AnalyticsRuntime.instance.track(const PhotoSearchStartedEvent(signedIn: true, searchId: 'close'));
    expect(hints.active, isNull);
  });

  test('clock rollback does not attribute future hint impressions', () async {
    hints.attach();
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isFalse);
    expect(hints.view(HintId.photoSearch), isTrue);
    clockNow = clockNow.subtract(const Duration(minutes: 1));
    await AnalyticsRuntime.instance.track(const PhotoSearchStartedEvent(signedIn: true, searchId: 'rollback'));
    await settle();
    expect(paramsOf(analytics, 'hint_feature_used'), isEmpty);
  });

  test('settings writes completing after disposal do not notify listeners', () async {
    hints.dispose();
    final Completer<void> writes = Completer<void>();
    hints = FeatureHints(read: <T>(String key, T fallback) => fallback, write: (_, _) => writes.future);
    final Future<void> update = hints.setEnabled(false);
    hints.dispose();
    hints = makeHints();
    writes.complete();
    await expectLater(update, completes);
  });

  test('reset completing after disposal does not notify listeners', () async {
    hints.dispose();
    final Completer<void> writes = Completer<void>();
    hints = FeatureHints(read: <T>(String key, T fallback) => fallback, write: (_, _) => writes.future);
    final Future<void> reset = hints.reset();
    hints.dispose();
    hints = makeHints();
    writes.complete();
    await expectLater(reset, completes);
  });

  test('native paywall interrupts a hint and blocks views beyond the prompt cooldown', () {
    hints.attach();
    expect(hints.view(HintId.variantDots), isTrue);
    paywall.value = true;
    expect(hints.active, isNull);
    clockNow = clockNow.add(const Duration(days: 1));
    expect(hints.view(HintId.folderSections), isFalse);
    paywall.value = false;
    expect(hints.view(HintId.folderSections), isTrue);
  });
  test('old account dismissal cannot close the new account hint', () {
    expect(hints.view(HintId.variantDots), isTrue);
    final String owner = hints.userId;
    uid = 'other';
    expect(hints.view(HintId.variantDots), isTrue);
    hints.dismiss(HintId.variantDots, HintDismissMethod.interrupted, userId: owner);
    expect(hints.active, HintId.variantDots);
  });
}
