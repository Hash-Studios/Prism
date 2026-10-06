import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'auto_rotate_event.j.dart';
part 'auto_rotate_state.j.dart';
part 'auto_rotate_bloc.j.freezed.dart';

@injectable
class AutoRotateBloc extends Bloc<AutoRotateEvent, AutoRotateState> {
  AutoRotateBloc(this._repository) : super(AutoRotateState.initial()) {
    on<AutoRotateEvent>(
      (event, emit) => event.map<Future<void>>(
        started: (event) => _onStarted(event, emit),
        entitlementChanged: (event) => _onEntitlementChanged(event, emit),
        favouritesChanged: (event) => _onFavouritesChanged(event, emit),
        favouritesSettled: (event) => _onFavouritesSettled(emit),
        toggled: (event) => _onToggled(event, emit),
        intervalChanged: (event) => _onConfigChanged(state.config.copyWith(intervalMinutes: event.minutes), emit),
        targetChanged: (event) => _onConfigChanged(state.config.copyWith(target: event.target), emit),
        shuffleChanged: (event) => _onConfigChanged(state.config.copyWith(shuffle: event.shuffle), emit),
        sourceChanged: (event) => _onSourceChanged(event, emit),
        chargingOnlyChanged: (event) => _onConfigChanged(
          state.config.copyWith(
            chargingOnly: event.chargingOnly,
            activeHoursEnabled: !event.chargingOnly && state.config.activeHoursEnabled,
          ),
          emit,
        ),
        activeHoursEnabledChanged: (event) => _onConfigChanged(
          state.config.copyWith(
            activeHoursEnabled: event.enabled,
            chargingOnly: !event.enabled && state.config.chargingOnly,
          ),
          emit,
        ),
        activeHoursChanged: (event) =>
            _onConfigChanged(state.config.copyWith(activeHoursStart: event.start, activeHoursEnd: event.end), emit),
        rotateNowPressed: (event) => _onRotateNow(event, emit),
        statusRefreshed: (event) => _onStatusRefreshed(emit),
        batteryTipDismissed: (event) async => emit(state.copyWith(showBatteryTip: false)),
      ),
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  /// The native rotation worker caps its playlist at 100 sources.
  static const int _maxSources = 100;
  static const int _maxStatusPolls = 40;
  static const int minWallpapers = 2;

  @visibleForTesting
  Duration favouritesDebounce = const Duration(seconds: 2);
  @visibleForTesting
  Duration statusPollInterval = const Duration(seconds: 3);

  final AutoRotateRepository _repository;
  List<String> _favouriteUrls = const <String>[];
  List<String> _downloadUrls = const <String>[];
  bool _favouritesCapped = false;
  bool _downloadsCapped = false;
  List<String>? _appliedUrls;
  bool _entitlementKnown = false;
  bool _favouritesKnown = false;
  String? _userId;
  Timer? _favouritesTimer;
  Timer? _pollTimer;
  int _pollsLeft = _maxStatusPolls;

  List<String> _activeUrls(AutoRotateConfig config) =>
      config.source == AutoRotateSource.downloads ? _downloadUrls : _favouriteUrls;

  bool _isCapped(AutoRotateSource source) =>
      source == AutoRotateSource.downloads ? _downloadsCapped : _favouritesCapped;

  void _setFavourites(List<String> urls) {
    final Set<String> seen = <String>{};
    final List<String> valid = urls.where(_isValidHttpsUrl).where(seen.add).toList(growable: false);
    _favouritesCapped = valid.length > _maxSources;
    _favouriteUrls = valid.take(_maxSources).toList(growable: false);
  }

  Future<void> _refreshDownloads() async {
    final Set<String> seen = <String>{};
    final List<String> paths = (await _repository.listDownloads())
        .where((path) => path.isNotEmpty)
        .where(seen.add)
        .toList(growable: false);
    _downloadsCapped = paths.length > _maxSources;
    _downloadUrls = paths.take(_maxSources).toList(growable: false);
  }

  Future<void> _loadApplied() async {
    _appliedUrls = await _repository.loadAppliedSources();
  }

  bool _isValidHttpsUrl(String value) {
    if (value.trim() != value) return false;
    final Uri? uri = Uri.tryParse(value);
    return uri != null &&
        uri.isAbsolute &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  bool _sameUrls(List<String> previous, List<String> next) => const ListEquality<String>().equals(previous, next);

  bool get _canRotate => state.isPro && _activeUrls(state.config).length >= minWallpapers;

  bool _urlsMatchApplied(AutoRotateConfig config) => _sameUrls(_appliedUrls ?? const <String>[], _activeUrls(config));

  bool _rotationChanged(AutoRotateConfig previous, AutoRotateConfig next) =>
      previous.intervalMinutes != next.intervalMinutes ||
      previous.target != next.target ||
      previous.shuffle != next.shuffle ||
      previous.source != next.source ||
      previous.chargingOnly != next.chargingOnly ||
      previous.activeHoursEnabled != next.activeHoursEnabled ||
      (next.activeHoursEnabled &&
          (previous.activeHoursStart != next.activeHoursStart || previous.activeHoursEnd != next.activeHoursEnd));

  AutoRotateState _snapshot(AutoRotateConfig config, {AutoRotateStatus? status, bool? isPro, bool? loaded}) =>
      state.copyWith(
        loaded: loaded ?? state.loaded,
        isPro: isPro ?? state.isPro,
        config: config,
        status: status ?? state.status,
        favouriteCount: _favouriteUrls.length,
        downloadCount: _downloadUrls.length,
        sourcesCapped: _isCapped(config.source),
      );

  Future<AutoRotateStatus> _status() async {
    try {
      return await _repository.status();
    } on PlatformException catch (error) {
      return AutoRotateStatus(lastError: error.message ?? error.code);
    }
  }

  @override
  void onChange(Change<AutoRotateState> change) {
    super.onChange(change);
    if (change.currentState.status != change.nextState.status) _schedulePoll(change.nextState.status);
  }

  void _schedulePoll(AutoRotateStatus status) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (isClosed || !status.isRunning || status.totalCount <= 0 || status.cachedCount >= status.totalCount) return;
    if (_pollsLeft <= 0) return;
    _pollsLeft--;
    _pollTimer = Timer(statusPollInterval, () {
      _pollTimer = null;
      if (!isClosed) add(const AutoRotateEvent.statusRefreshed());
    });
  }

  @override
  Future<void> close() {
    _favouritesTimer?.cancel();
    _pollTimer?.cancel();
    return super.close();
  }

  Future<void> _onStarted(_Started event, Emitter<AutoRotateState> emit) async {
    final bool isPro = _entitlementKnown ? state.isPro : event.isPro;
    if (_entitlementKnown && !isPro) {
      _favouriteUrls = const <String>[];
      _favouritesCapped = false;
    } else {
      _setFavourites(event.favouriteUrls);
    }
    _favouritesKnown = true;
    final AutoRotateConfig config = await _repository.loadConfig();
    if (config.source == AutoRotateSource.downloads) await _refreshDownloads();
    await _loadApplied();
    final AutoRotateStatus status = await _status();
    _pollsLeft = _maxStatusPolls;
    emit(_snapshot(config, status: status, isPro: isPro, loaded: true));

    if (!isPro) {
      if (config.enabled || status.isRunning || status.lastError != null) await _disable(emit);
      return;
    }
    if (!config.enabled) {
      if (status.isRunning || status.lastError != null) await _disable(emit);
      return;
    }
    if (!_canRotate) {
      await _disable(emit);
    } else if (!status.isRunning && status.lastError != null) {
      await _disable(emit);
    } else if (!status.isRunning || !_urlsMatchApplied(config)) {
      await _start(config, emit);
    }
  }

  Future<void> _onEntitlementChanged(_EntitlementChanged event, Emitter<AutoRotateState> emit) async {
    final bool accountChanged = _entitlementKnown && _userId != event.userId;
    _entitlementKnown = true;
    _userId = event.userId;
    if (accountChanged || !event.isPro) {
      _favouriteUrls = const <String>[];
      _favouritesCapped = false;
      _favouritesKnown = false;
    }
    final AutoRotateConfig config = await _repository.loadConfig();
    if (config.source == AutoRotateSource.downloads) await _refreshDownloads();
    await _loadApplied();
    final AutoRotateStatus status = await _status();
    emit(_snapshot(config, status: status, isPro: event.isPro, loaded: true));
    final bool somethingToStop = config.enabled || status.isRunning || status.lastError != null;
    if (!event.isPro || accountChanged) {
      if (somethingToStop) await _disable(emit);
    } else if (!config.enabled && somethingToStop) {
      await _disable(emit);
    } else if (!status.isRunning && status.lastError != null) {
      await _disable(emit);
    } else if (_favouritesKnown && config.enabled && _canRotate && status.lastError == null && !status.isRunning) {
      await _start(config, emit);
    }
  }

  Future<void> _onFavouritesChanged(_FavouritesChanged event, Emitter<AutoRotateState> emit) async {
    final List<String> previousUrls = _favouriteUrls;
    final bool wasKnown = _favouritesKnown;
    _setFavourites(event.favouriteUrls);
    _favouritesKnown = true;
    emit(_snapshot(state.config));
    if (!state.loaded) return;
    if (!wasKnown) {
      await _onFavouritesSettled(emit);
      return;
    }
    if (_sameUrls(previousUrls, _favouriteUrls) && state.status.isRunning && _canRotate) return;
    _favouritesTimer?.cancel();
    _favouritesTimer = Timer(favouritesDebounce, () {
      if (!isClosed) add(const AutoRotateEvent.favouritesSettled());
    });
  }

  Future<void> _onFavouritesSettled(Emitter<AutoRotateState> emit) async {
    if (!state.loaded) return;
    if (state.status.isRunning && _canRotate && _urlsMatchApplied(state.config)) return;
    if (!_canRotate && (state.config.enabled || state.status.isRunning || state.status.lastError != null)) {
      await _disable(emit);
      return;
    }
    if (!state.status.isRunning && state.status.lastError != null) {
      await _disable(emit);
      return;
    }
    if (state.config.enabled && _canRotate && state.isPro) {
      await _start(state.config, emit);
    } else if (state.config.enabled || state.status.isRunning || state.status.lastError != null) {
      await _disable(emit);
    }
  }

  Future<void> _onToggled(_Toggled event, Emitter<AutoRotateState> emit) async {
    if (event.enabled) {
      if (!_canRotate || (state.config.enabled && state.status.isRunning)) return;
      await _start(state.config.copyWith(enabled: true), emit, userInitiated: true);
    } else {
      if (!state.config.enabled && !state.status.isRunning && state.status.lastError == null) return;
      await _disable(emit);
    }
  }

  Future<void> _onSourceChanged(_SourceChanged event, Emitter<AutoRotateState> emit) async {
    if (event.source == state.config.source) return;
    if (event.source == AutoRotateSource.downloads) await _refreshDownloads();
    await _onConfigChanged(state.config.copyWith(source: event.source), emit);
  }

  Future<void> _onConfigChanged(AutoRotateConfig next, Emitter<AutoRotateState> emit) async {
    if (next == state.config) return;
    final AutoRotateConfig previous = state.config;
    await _repository.saveConfig(next);
    emit(_snapshot(next));
    if (!next.enabled) return;
    if (!_canRotate) {
      await _disable(emit);
    } else if (!state.status.isRunning || _rotationChanged(previous, next)) {
      await _start(next, emit);
    }
  }

  Future<void> _onRotateNow(_RotateNowPressed event, Emitter<AutoRotateState> emit) async {
    if (!state.config.enabled) return;
    bool rotated = false;
    try {
      rotated = await _repository.rotateNow();
    } on PlatformException {
      rotated = false;
    }
    final AutoRotateStatus status = await _status();
    if (status.isRunning) {
      emit(
        state.copyWith(
          status: AutoRotateStatus(
            isRunning: true,
            nextRunEpochMs: status.nextRunEpochMs,
            lastError: rotated ? status.lastError : status.lastError ?? 'Could not rotate wallpaper now.',
            cachedCount: status.cachedCount,
            totalCount: status.totalCount,
          ),
        ),
      );
      return;
    }
    await _disable(emit);
  }

  Future<void> _onStatusRefreshed(Emitter<AutoRotateState> emit) async {
    final AutoRotateStatus status = await _status();
    if (!state.status.isRunning || !status.isRunning) return;
    if (status == state.status) {
      _schedulePoll(status);
    } else {
      emit(state.copyWith(status: status));
    }
  }

  Future<void> _start(AutoRotateConfig config, Emitter<AutoRotateState> emit, {bool userInitiated = false}) async {
    final bool wasRunning = state.status.isRunning;
    final List<String> urls = _activeUrls(config);
    _pollsLeft = _maxStatusPolls;
    emit(state.copyWith(starting: true, startFailed: false));
    try {
      if (!await _repository.start(config, urls)) {
        await _disable(emit, startFailed: true);
        return;
      }
      final AutoRotateStatus status = await _status();
      if (!status.isRunning) {
        await _disable(emit, startFailed: true);
        return;
      }
      await _repository.saveConfig(config);
      _appliedUrls = urls;
      final bool showTip = userInitiated && !wasRunning && await _repository.consumeBatteryTip();
      emit(
        state.copyWith(
          config: config,
          status: status,
          startFailed: false,
          starting: false,
          showBatteryTip: state.showBatteryTip || showTip,
        ),
      );
      if (!wasRunning && status.isRunning && status.lastError == null) {
        analytics.track(
          AutoRotateEnabledEvent(
            intervalMinutes: config.intervalMinutes,
            target: config.target,
            shuffle: config.shuffle,
            wallpaperCount: urls.length,
          ),
        );
      }
    } on PlatformException {
      await _disable(emit, startFailed: true);
    } finally {
      if (state.starting) emit(state.copyWith(starting: false));
    }
  }

  Future<void> _disable(Emitter<AutoRotateState> emit, {bool startFailed = false}) async {
    final bool wasRunning = state.status.isRunning;
    bool stopped = false;
    try {
      stopped = await _repository.stop();
    } on PlatformException {
      stopped = false;
    }
    if (stopped) _appliedUrls = const <String>[];
    final AutoRotateConfig next = state.config.copyWith(enabled: false);
    await _repository.saveConfig(next);
    final AutoRotateStatus latestStatus = await _status();
    final AutoRotateStatus status = stopped
        ? const AutoRotateStatus()
        : AutoRotateStatus(
            isRunning: state.status.isRunning || latestStatus.isRunning,
            nextRunEpochMs: latestStatus.isRunning ? latestStatus.nextRunEpochMs : state.status.nextRunEpochMs,
            lastError: latestStatus.lastError ?? 'Failed to stop wallpaper rotation.',
          );
    emit(state.copyWith(config: next, status: status, startFailed: startFailed, starting: false));
    if (wasRunning && stopped) {
      analytics.track(const AutoRotateDisabledEvent());
    }
  }
}
