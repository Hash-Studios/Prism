import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/rating/rate_prompt_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Harness {
  _Harness({this.available = true, this.slotFree = true, this.requestThrows = false}) {
    service = RatePromptService(
      read: <T>(String key, T defaultValue) => (store[key] as T?) ?? defaultValue,
      write: (String key, Object? value) async => store[key] = value,
      clock: () => now,
      firstLaunchAt: () => firstLaunch,
      appVersion: () => version,
      claimStartupSlot: () {
        claims += 1;
        return slotFree;
      },
      isReviewAvailable: () async => available,
      requestReview: () async {
        order.add('request');
        if (requestThrows) throw StateError('store down');
      },
      wait: (Duration duration) async => order.add('wait:${duration.inSeconds}'),
      track: (AnalyticsEvent event) async => events.add(event),
    );
  }

  final bool available;
  final bool slotFree;
  final bool requestThrows;
  final Map<String, Object?> store = <String, Object?>{};
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];
  final List<String> order = <String>[];
  DateTime now = DateTime.utc(2026, 3, 20);
  DateTime firstLaunch = DateTime.utc(2026, 3);
  String version = '3.4.0';
  int claims = 0;
  late final RatePromptService service;

  int get requests => order.where((String step) => step == 'request').length;

  Future<void> actions(int count, [RatePromptTrigger trigger = RatePromptTrigger.wallpaperSet]) async {
    for (var i = 0; i < count; i++) {
      await service.maybePrompt(trigger);
    }
  }
}

void main() {
  test('happy path waits, then requests the native review and tracks shown and requested', () async {
    final h = _Harness();

    await h.actions(2);
    expect(h.requests, 0);
    expect(h.claims, 0);

    await h.service.maybePrompt(RatePromptTrigger.favourite);

    expect(h.order, <String>['wait:2', 'request']);
    expect(h.events.whereType<RatePromptShownEvent>().single.trigger, 'favourite');
    expect(h.events.whereType<RatePromptResultEvent>().single.result, 'requested');
    expect(h.store[RatePromptService.lastAskAtKey], h.now.toIso8601String());
    expect(h.store[RatePromptService.askVersionKey], '3.4.0');
  });

  test('does not request the card when the store says it is unavailable', () async {
    final h = _Harness(available: false);

    await h.actions(3);

    expect(h.requests, 0);
    expect(h.events.whereType<RatePromptResultEvent>().single.result, 'unavailable');
    expect(h.events.whereType<RatePromptShownEvent>(), hasLength(1));
  });

  test('blocks a young install', () async {
    final h = _Harness()..firstLaunch = DateTime.utc(2026, 3, 17);

    await h.actions(3);
    expect(h.requests, 0);
    expect(h.claims, 0);

    h.now = DateTime.utc(2026, 3, 22);
    await h.service.maybePrompt(RatePromptTrigger.wallpaperSet);
    expect(h.requests, 1);
  });

  test('blocks for 3 days after a failure, then allows', () async {
    final h = _Harness();
    await h.service.recordFailure();
    expect(h.store[RatePromptService.lastFailureAtKey], h.now.toIso8601String());

    await h.actions(3);
    expect(h.requests, 0);

    h.now = h.now.add(const Duration(days: 3));
    await h.service.maybePrompt(RatePromptTrigger.download);
    expect(h.requests, 1);
  });

  test('a failure older than 3 days does not block', () async {
    final h = _Harness();
    h.store[RatePromptService.lastFailureAtKey] = h.now.subtract(const Duration(days: 4)).toIso8601String();

    await h.actions(3);

    expect(h.requests, 1);
  });

  test('leaves 90 days between asks', () async {
    final h = _Harness();
    await h.actions(3);
    expect(h.requests, 1);

    h.version = '3.5.0';
    h.now = h.now.add(const Duration(days: 89));
    await h.service.maybePrompt(RatePromptTrigger.wallpaperSet);
    expect(h.requests, 1);

    h.now = h.now.add(const Duration(days: 1));
    await h.service.maybePrompt(RatePromptTrigger.wallpaperSet);
    expect(h.requests, 2);
    expect(h.store[RatePromptService.askVersionKey], '3.5.0');
  });

  test('asks once per app version', () async {
    final h = _Harness();
    await h.actions(3);
    h.now = h.now.add(const Duration(days: 120));

    await h.service.maybePrompt(RatePromptTrigger.wallpaperSet);

    expect(h.requests, 1);
  });

  test('legacy done flag blocks forever', () async {
    final h = _Harness();
    h.store[RatePromptService.doneKey] = true;

    await h.actions(3);
    h.version = '9.9.9';
    h.now = h.now.add(const Duration(days: 400));
    await h.service.maybePrompt(RatePromptTrigger.wallpaperSet);

    expect(h.requests, 0);
    expect(h.claims, 0);
  });

  test('does not ask in a session that already showed a startup sheet', () async {
    final h = _Harness(slotFree: false);

    await h.actions(3);

    expect(h.claims, 1);
    expect(h.requests, 0);
    expect(h.store.containsKey(RatePromptService.lastAskAtKey), isFalse);
  });

  test('swallows errors from requestReview', () async {
    final h = _Harness(requestThrows: true);

    await h.actions(3);

    expect(h.requests, 1);
    expect(h.events.whereType<RatePromptResultEvent>(), isEmpty);
  });

  test('recordFailure never throws', () async {
    final service = RatePromptService(
      write: (String key, Object? value) async => throw StateError('disk full'),
      clock: DateTime.now,
    );

    await service.recordFailure();
  });
}
