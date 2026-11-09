import 'dart:async';
import 'dart:convert';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism_sheet/prism_sheet_route.dart';
import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:Prism/features/session/data/app_session_tracker.dart';
import 'package:flutter/foundation.dart';

typedef _ReadSetting = T Function<T>(String key, T defaultValue);
typedef _WriteSetting = Future<void> Function(String key, Object? value);

/// What one user did with one hint.
class HintRecord {
  const HintRecord({this.views = 0, this.shownAt, this.used = false});

  factory HintRecord.fromJson(Object? json) {
    if (json is! Map) return const HintRecord();
    final Object? shown = json['s'];
    return HintRecord(
      views: json['n'] is int ? json['n'] as int : 0,
      shownAt: shown is int ? DateTime.fromMillisecondsSinceEpoch(shown) : null,
      used: json['u'] == true,
    );
  }

  final int views;
  final DateTime? shownAt;
  final bool used;

  bool get done => shownAt != null || used;

  HintRecord copyWith({int? views, DateTime? shownAt, bool? used}) =>
      HintRecord(views: views ?? this.views, shownAt: shownAt ?? this.shownAt, used: used ?? this.used);

  Map<String, Object?> toJson() => <String, Object?>{
    'n': views,
    if (shownAt != null) 's': shownAt!.millisecondsSinceEpoch,
    if (used) 'u': true,
  };
}

/// Decides when a feature hint shows, and keeps each user's hint records on the device.
///
/// One hint at a time. The [HintBudget], the Show tips switch and the Remote Config keys all gate it.
class FeatureHints extends ChangeNotifier {
  FeatureHints({
    _ReadSetting? read,
    _WriteSetting? write,
    DateTime Function()? clock,
    int Function()? session,
    String Function()? userId,
    String Function(String key)? remoteConfig,
    int Function()? openSheets,
    ValueListenable<bool>? paywallPresenting,
  }) : _read = read ?? _defaultRead,
       _write = write ?? _defaultWrite,
       _clock = clock ?? DateTime.now,
       _session = session ?? (() => _storeReady ? AppSessionTracker.instance.sessionNumber : 0),
       _userId = userId ?? (() => app_state.prismUser.id),
       _remoteConfig = remoteConfig ?? _defaultRemoteConfig,
       _openSheets = openSheets ?? (() => openPrismSheetCount),
       _paywallPresenting = paywallPresenting ?? PaywallOrchestrator.instance.presenting;

  /// Tests swap this for a [FeatureHints] built with fakes.
  static FeatureHints instance = FeatureHints();

  static const String enabledKey = 'hints.enabled';
  static const String lastPromptKey = 'hints.last_prompt_at';
  static const String remoteEnabledKey = 'hints_enabled';
  static const String remoteDisabledIdsKey = 'hints_disabled_ids';
  static String recordsKey(String userId) => 'hints.records.${userId.isEmpty ? 'guest' : userId}';

  final _ReadSetting _read;
  final _WriteSetting _write;
  final DateTime Function() _clock;
  final int Function() _session;
  final String Function() _userId;
  final String Function(String key) _remoteConfig;
  final int Function() _openSheets;
  final ValueListenable<bool> _paywallPresenting;

  HintId? _active;
  String? _activeUserId;
  final Map<String, Map<HintId, HintRecord>> _recordCache = <String, Map<HintId, HintRecord>>{};
  final Map<String, List<DateTime>> _historyCache = <String, List<DateTime>>{};
  bool _disposed = false;
  bool _attached = false;

  /// Starts listening for feature use and for other prompts. Call it once at launch.
  void attach() {
    if (_attached) return;
    _attached = true;
    AnalyticsRuntime.trackListeners.add(_onTracked);
    StartupModalSlot.lastPromptAt.addListener(_onPrompt);
    _paywallPresenting.addListener(_onPaywallChanged);
  }

  String get userId => _userId();

  /// The hint on screen now, if any.
  HintId? get active => _activeUserId == _userId() ? _active : null;

  /// The Show tips switch in Settings.
  bool get enabled => _read<bool>(enabledKey, true);

  Future<void> setEnabled(bool value) async {
    if (!value) _hideActive();
    await _write(enabledKey, value);
    if (!_disposed) notifyListeners();
  }

  /// Lets every hint show again for the current user.
  Future<void> reset() async {
    _hideActive();
    final String uid = _userId();
    final List<DateTime> history = _history(_records());
    await _write(
      '${recordsKey(uid)}.budget',
      jsonEncode(history.map((DateTime at) => at.millisecondsSinceEpoch).toList()),
    );
    _recordCache[uid] = <HintId, HintRecord>{};
    await _write(recordsKey(uid), null);
    if (!_disposed) notifyListeners();
  }

  HintRecord record(HintId id) => _records()[id] ?? const HintRecord();

  /// The surface of [id] was seen. Returns true when its hint should show now. Pass [canShow] false when the control
  /// is off screen or covered: the view still counts.
  bool view(HintId id, {bool canShow = true}) {
    if (_active != null && active == null) _hideActive();
    final Map<HintId, HintRecord> records = _records();
    final List<DateTime> history = _history(records);
    final HintRecord current = records[id] ?? const HintRecord();
    if (current.done) return false;
    final HintRecord viewed = current.copyWith(views: current.views + 1);
    records[id] = viewed;
    final bool show =
        canShow &&
        _active == null &&
        viewed.views >= kHints[id]!.views &&
        _allowedByConfig(id) &&
        _openSheets() == 0 &&
        !_paywallPresenting.value &&
        HintBudget.allows(now: _clock(), session: _session(), shownAt: history, lastPromptAt: _lastPromptAt());
    if (show) {
      final DateTime shownAt = _clock();
      records[id] = viewed.copyWith(shownAt: shownAt);
      history.removeWhere((DateTime at) => shownAt.difference(at) >= HintBudget.week);
      history.add(shownAt);
      unawaited(
        _write(
          '${recordsKey(_userId())}.budget',
          jsonEncode(history.map((DateTime at) => at.millisecondsSinceEpoch).toList()),
        ),
      );
      _active = id;
      _activeUserId = _userId();
      unawaited(analytics.track(HintShownEvent(hintId: id)));
    }
    unawaited(_save(records));
    if (show) notifyListeners();
    return show;
  }

  void dismiss(HintId id, HintDismissMethod method, {String? userId}) {
    if (_disposed || _active != id || (userId != null && userId != _activeUserId)) return;
    _active = null;
    _activeUserId = null;
    unawaited(analytics.track(HintDismissedEvent(hintId: id, method: method)));
    notifyListeners();
  }

  bool _allowedByConfig(HintId id) {
    if (!enabled) return false;
    final String remoteEnabled = _remoteConfig(remoteEnabledKey).trim().toLowerCase();
    if (remoteEnabled == 'false' || remoteEnabled == '0') return false;
    final Iterable<String> off = _remoteConfig(remoteDisabledIdsKey).split(',').map((String s) => s.trim());
    return !off.contains(id.key);
  }

  DateTime? _lastPromptAt() {
    final DateTime? live = StartupModalSlot.lastPromptAt.value;
    final int stored = _read<int>(lastPromptKey, 0);
    final DateTime? saved = stored == 0 ? null : DateTime.fromMillisecondsSinceEpoch(stored);
    if (live == null) return saved;
    if (saved == null) return live;
    return live.isAfter(saved) ? live : saved;
  }

  void _onPaywallChanged() {
    if (_paywallPresenting.value) _hideActive();
  }

  void _onPrompt() {
    final DateTime? at = StartupModalSlot.lastPromptAt.value;
    if (at == null) return;
    unawaited(_write(lastPromptKey, at.millisecondsSinceEpoch));
    _hideActive();
  }

  void _hideActive() {
    final HintId? id = _active;
    if (id != null) dismiss(id, HintDismissMethod.interrupted);
  }

  void _onTracked(AnalyticsEvent event) {
    for (final Hint hint in kHints.values) {
      if (hint.usedEvent != event.eventName) continue;
      final Map<HintId, HintRecord> records = _records();
      final HintRecord current = records[hint.id] ?? const HintRecord();
      if (current.used) continue;
      final DateTime? shownAt = current.shownAt;
      final Duration? age = shownAt == null ? null : _clock().difference(shownAt);
      if (age != null && !age.isNegative && age < HintBudget.day) {
        unawaited(analytics.track(HintFeatureUsedEvent(hintId: hint.id)));
      }
      records[hint.id] = current.copyWith(used: true);
      unawaited(_save(records));
      if (active == hint.id) _hideActive();
    }
  }

  List<DateTime> _history(Map<HintId, HintRecord> records) {
    return _historyCache.putIfAbsent(_userId(), () {
      final Set<int> times = records.values.map((HintRecord r) => r.shownAt?.millisecondsSinceEpoch).nonNulls.toSet();
      try {
        final Object? saved = jsonDecode(_read<String>('${recordsKey(_userId())}.budget', '[]'));
        if (saved is List) times.addAll(saved.whereType<int>());
      } on FormatException {
        // Keep the history still available in the hint records.
      }
      return times.map(DateTime.fromMillisecondsSinceEpoch).toList();
    });
  }

  Map<HintId, HintRecord> _records() {
    final String uid = _userId();
    if (_recordCache.containsKey(uid)) return _recordCache[uid]!;
    final Map<HintId, HintRecord> records = <HintId, HintRecord>{};
    _recordCache[uid] = records;
    try {
      final Object? decoded = jsonDecode(_read<String>(recordsKey(_userId()), '{}'));
      if (decoded is Map) {
        for (final HintId id in HintId.values) {
          if (decoded.containsKey(id.key)) records[id] = HintRecord.fromJson(decoded[id.key]);
        }
      }
    } on FormatException {
      return records;
    }
    return records;
  }

  Future<void> _save(Map<HintId, HintRecord> records) => _write(
    recordsKey(_userId()),
    jsonEncode(<String, Object?>{
      for (final MapEntry<HintId, HintRecord> e in records.entries) e.key.key: e.value.toJson(),
    }),
  );

  @override
  void dispose() {
    _disposed = true;
    AnalyticsRuntime.trackListeners.remove(_onTracked);
    StartupModalSlot.lastPromptAt.removeListener(_onPrompt);
    _paywallPresenting.removeListener(_onPaywallChanged);
    super.dispose();
  }

  /// False before DI is set up, and in tests that do not register the settings store. Then no hint shows.
  static bool get _storeReady => getIt.isRegistered<SettingsLocalDataSource>();

  static T _defaultRead<T>(String key, T defaultValue) {
    if (!_storeReady) return defaultValue;
    return getIt<SettingsLocalDataSource>().get<T>(key, defaultValue: defaultValue);
  }

  static Future<void> _defaultWrite(String key, Object? value) async {
    if (!_storeReady) return;
    final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
    return value == null ? settings.delete(key) : settings.set(key, value);
  }

  static String _defaultRemoteConfig(String key) => FirebaseInit.remoteConfigIfInitialized?.getString(key) ?? '';
}
