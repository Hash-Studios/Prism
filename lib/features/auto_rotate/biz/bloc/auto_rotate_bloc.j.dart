import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
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
        toggled: (event) => _onToggled(event, emit),
        intervalChanged: (event) => _onConfigChanged(state.config.copyWith(intervalMinutes: event.minutes), emit),
        targetChanged: (event) => _onConfigChanged(state.config.copyWith(target: event.target), emit),
        shuffleChanged: (event) => _onConfigChanged(state.config.copyWith(shuffle: event.shuffle), emit),
        rotateNowPressed: (event) => _onRotateNow(event, emit),
      ),
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  /// The native rotation worker caps its playlist at 100 sources.
  static const int _maxSources = 100;
  static const int minWallpapers = 2;

  final AutoRotateRepository _repository;
  List<String> _urls = const <String>[];
  bool _entitlementKnown = false;
  bool _favouritesKnown = false;
  String? _userId;

  void _setUrls(List<String> urls) {
    final Set<String> seen = <String>{};
    _urls = urls.where(_isValidHttpsUrl).where(seen.add).take(_maxSources).toList(growable: false);
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

  bool get _canRotate => state.isPro && _urls.length >= minWallpapers;

  Future<AutoRotateStatus> _status() async {
    try {
      return await _repository.status();
    } on PlatformException catch (error) {
      return AutoRotateStatus(lastError: error.message ?? error.code);
    }
  }

  Future<void> _onStarted(_Started event, Emitter<AutoRotateState> emit) async {
    final bool isPro = _entitlementKnown ? state.isPro : event.isPro;
    final List<String> previousUrls = _urls;
    if (_entitlementKnown && !isPro) {
      _urls = const <String>[];
    } else {
      _setUrls(event.favouriteUrls);
    }
    _favouritesKnown = true;
    final AutoRotateConfig config = await _repository.loadConfig();
    final AutoRotateStatus status = await _status();
    final bool urlsChanged = !_sameUrls(previousUrls, _urls);
    final bool configChanged = state.config != config;
    emit(state.copyWith(loaded: true, isPro: isPro, favouriteCount: _urls.length, config: config, status: status));

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
    } else if (!status.isRunning || urlsChanged || configChanged) {
      await _start(config, emit);
    }
  }

  Future<void> _onEntitlementChanged(_EntitlementChanged event, Emitter<AutoRotateState> emit) async {
    final bool accountChanged = _entitlementKnown && _userId != event.userId;
    _entitlementKnown = true;
    _userId = event.userId;
    if (accountChanged || !event.isPro) {
      _urls = const <String>[];
      _favouritesKnown = false;
    }
    final AutoRotateConfig config = await _repository.loadConfig();
    final AutoRotateStatus status = await _status();
    emit(
      state.copyWith(loaded: true, isPro: event.isPro, favouriteCount: _urls.length, config: config, status: status),
    );
    if (!event.isPro || accountChanged || (!config.enabled && (status.isRunning || status.lastError != null))) {
      await _disable(emit);
    } else if (!status.isRunning && status.lastError != null) {
      await _disable(emit);
    } else if (_favouritesKnown && config.enabled && _canRotate && status.lastError == null && !status.isRunning) {
      await _start(config, emit);
    }
  }

  Future<void> _onFavouritesChanged(_FavouritesChanged event, Emitter<AutoRotateState> emit) async {
    final List<String> previousUrls = _urls;
    _setUrls(event.favouriteUrls);
    final bool changed = !_favouritesKnown || !_sameUrls(previousUrls, _urls);
    _favouritesKnown = true;
    if (!changed && state.status.isRunning && _canRotate) return;
    emit(state.copyWith(favouriteCount: _urls.length));
    if (!state.loaded) return;
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
      await _start(state.config.copyWith(enabled: true), emit);
    } else {
      await _disable(emit);
    }
  }

  Future<void> _onConfigChanged(AutoRotateConfig next, Emitter<AutoRotateState> emit) async {
    if (next == state.config) return;
    await _repository.saveConfig(next);
    emit(state.copyWith(config: next));
    if (next.enabled && _canRotate) await _start(next, emit);
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
          ),
        ),
      );
      return;
    }
    await _disable(emit);
  }

  Future<void> _start(AutoRotateConfig config, Emitter<AutoRotateState> emit) async {
    final bool wasRunning = state.status.isRunning;
    try {
      if (!await _repository.start(config, _urls)) {
        await _disable(emit, startFailed: true);
        return;
      }
      final AutoRotateStatus status = await _status();
      if (!status.isRunning) {
        await _disable(emit, startFailed: true);
        return;
      }
      await _repository.saveConfig(config);
      emit(state.copyWith(config: config, status: status, startFailed: false));
      if (!wasRunning && status.isRunning && status.lastError == null) {
        analytics.track(
          AutoRotateEnabledEvent(
            intervalMinutes: config.intervalMinutes,
            target: config.target,
            shuffle: config.shuffle,
            wallpaperCount: _urls.length,
          ),
        );
      }
    } on PlatformException {
      await _disable(emit, startFailed: true);
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
    emit(state.copyWith(config: next, status: status, startFailed: startFailed));
    if (wasRunning && stopped) {
      analytics.track(const AutoRotateDisabledEvent());
    }
  }
}
