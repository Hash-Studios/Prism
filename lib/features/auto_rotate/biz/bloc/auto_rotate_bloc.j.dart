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
        categoryChanged: (event) => _onCategoryChanged(event, emit),
        chargingOnlyChanged: (event) => _onConfigChanged(state.config.copyWith(chargingOnly: event.chargingOnly), emit),
        rotateNowPressed: (event) => _onRotateNow(event, emit),
        statusRefreshed: (event) => _onStatusRefreshed(emit),
        batteryTipDismissed: (event) async => emit(state.copyWith(showBatteryTip: false)),
        proLapseAcknowledged: (event) async => emit(state.copyWith(proLapsed: false)),
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
  List<String> _remoteUrls = const <String>[];
  bool _remoteFailed = false;
  bool _favouritesCapped = false;
  bool _downloadsCapped = false;
  List<String>? _appliedUrls;
  bool _entitlementKnown = false;
  bool _favouritesKnown = false;
  String? _userId;
  Timer? _favouritesTimer;
  Timer? _pollTimer;
  int _pollsLeft = _maxStatusPolls;

  Set<WallpaperTarget> _supportedTargets = const <WallpaperTarget>{
    WallpaperTarget.home,
    WallpaperTarget.lock,
    WallpaperTarget.both,
  };

  bool _isRemote(AutoRotateSource source) =>
      source == AutoRotateSource.category ||
      source == AutoRotateSource.wallOfTheDay ||
      source == AutoRotateSource.history;

  List<String> _activeUrls(AutoRotateConfig config) => switch (config.source) {
    AutoRotateSource.favourites => _favouriteUrls,
    AutoRotateSource.downloads => _downloadUrls,
    AutoRotateSource.category || AutoRotateSource.wallOfTheDay || AutoRotateSource.history => _remoteUrls,
  };

  /// True when the list for the chosen source could not be loaded. A rotation that already runs keeps its own list.
  bool _remoteUnavailable(AutoRotateConfig config) => _isRemote(config.source) && _remoteFailed;

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

  /// Loads the list of a category, Wall of the Day or history source. Keeps the old list and returns false on failure.
  Future<bool> _refreshRemote(AutoRotateConfig config) async {
    List<String>? urls;
    try {
      urls = await _repository.loadRemoteUrls(config.source, category: config.categoryName);
    } catch (_) {
      urls = null;
    }
    if (urls == null) return false;
    final Set<String> seen = <String>{};
    _remoteUrls = urls.where(_isValidHttpsUrl).where(seen.add).take(_maxSources).toList(growable: false);
    return true;
  }

  Future<void> _refreshSource(AutoRotateConfig config) async {
    if (config.source == AutoRotateSource.downloads) await _refreshDownloads();
    if (_isRemote(config.source)) _remoteFailed = !await _refreshRemote(config);
  }

  Future<void> _loadSupportedTargets() async {
    try {
      _supportedTargets = await _repository.supportedTargets();
    } catch (_) {
      // Keep the default: every target.
    }
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
      previous.categoryName != next.categoryName ||
      previous.chargingOnly != next.chargingOnly;

  AutoRotateState _snapshot(AutoRotateConfig config, {AutoRotateStatus? status, bool? isPro, bool? loaded}) =>
      state.copyWith(
        loaded: loaded ?? state.loaded,
        isPro: isPro ?? state.isPro,
        config: config,
        status: status ?? state.status,
        favouriteCount: _favouriteUrls.length,
        downloadCount: _downloadUrls.length,
        remoteCount: _remoteUrls.length,
        loadingSource: false,
        sourceLoadFailed: _remoteUnavailable(config),
        supportedTargets: _supportedTargets,
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
    await _loadSupportedTargets();
    if (isPro || config.source == AutoRotateSource.downloads) await _refreshSource(config);
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
    if (_remoteUnavailable(config) && status.isRunning && status.lastError == null) return;
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
    if (event.isPro && config.enabled && !status.isRunning && _isRemote(config.source)) {
      _remoteFailed = !await _refreshRemote(config);
    }
    emit(_snapshot(config, status: status, isPro: event.isPro, loaded: true));
    final bool somethingToStop = config.enabled || status.isRunning || status.lastError != null;
    if (!event.isPro || accountChanged) {
      if (somethingToStop) await _disable(emit);
      if (!event.isPro && !accountChanged && event.userId.isNotEmpty && (config.enabled || status.isRunning)) {
        emit(state.copyWith(proLapsed: true));
      }
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
    if (_remoteUnavailable(state.config) && state.status.isRunning && state.status.lastError == null) return;
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
      if (state.isPro && _isRemote(state.config.source) && (_remoteFailed || _remoteUrls.isEmpty)) {
        _remoteFailed = !await _refreshRemote(state.config);
        emit(_snapshot(state.config));
      }
      if (!_canRotate || (state.config.enabled && state.status.isRunning)) return;
      await _start(state.config.copyWith(enabled: true), emit, userInitiated: true);
    } else {
      if (!state.config.enabled && !state.status.isRunning && state.status.lastError == null) return;
      await _disable(emit);
    }
  }

  Future<void> _onSourceChanged(_SourceChanged event, Emitter<AutoRotateState> emit) async {
    if (event.source == state.config.source) return;
    await _switchSource(state.config.copyWith(source: event.source), emit);
  }

  Future<void> _onCategoryChanged(_CategoryChanged event, Emitter<AutoRotateState> emit) async {
    final AutoRotateConfig next = state.config.copyWith(
      source: AutoRotateSource.category,
      categoryName: event.category,
    );
    if (next == state.config) return;
    await _switchSource(next, emit);
  }

  /// Loads the list for [next] first. When it cannot be loaded the old source and its rotation stay as they are.
  Future<void> _switchSource(AutoRotateConfig next, Emitter<AutoRotateState> emit) async {
    if (next.source == AutoRotateSource.downloads) await _refreshDownloads();
    if (_isRemote(next.source)) {
      emit(state.copyWith(loadingSource: true, sourceLoadFailed: false));
      final bool loaded = await _refreshRemote(next);
      if (!loaded) {
        emit(state.copyWith(loadingSource: false, sourceLoadFailed: true));
        return;
      }
      _remoteFailed = false;
    }
    await _onConfigChanged(next, emit);
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
    analytics.track(AutoRotateRunResultEvent(result: rotated ? BinaryResultValue.success : BinaryResultValue.failure));
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
            source: config.source.name,
            category: config.source == AutoRotateSource.category ? config.categoryName : null,
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
