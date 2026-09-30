import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'auto_rotate_event.j.dart';
part 'auto_rotate_state.j.dart';
part 'auto_rotate_bloc.j.freezed.dart';

@injectable
class AutoRotateBloc extends Bloc<AutoRotateEvent, AutoRotateState> {
  AutoRotateBloc(this._repository) : super(AutoRotateState.initial()) {
    on<_Started>(_onStarted);
    on<_FavouritesChanged>(_onFavouritesChanged);
    on<_Toggled>(_onToggled);
    on<_IntervalChanged>(
      (event, emit) => _onConfigChanged(state.config.copyWith(intervalMinutes: event.minutes), emit),
    );
    on<_TargetChanged>((event, emit) => _onConfigChanged(state.config.copyWith(target: event.target), emit));
    on<_ShuffleChanged>((event, emit) => _onConfigChanged(state.config.copyWith(shuffle: event.shuffle), emit));
    on<_RotateNowPressed>(_onRotateNow);
  }

  /// The native rotation worker caps its playlist at 100 sources.
  static const int _maxSources = 100;
  static const int minWallpapers = 2;

  final AutoRotateRepository _repository;
  List<String> _urls = const <String>[];

  void _setUrls(List<String> urls) {
    _urls = urls.where((url) => url.startsWith('https://')).take(_maxSources).toList(growable: false);
  }

  bool get _canRotate => state.isPro && _urls.length >= minWallpapers;

  Future<void> _onStarted(_Started event, Emitter<AutoRotateState> emit) async {
    _setUrls(event.favouriteUrls);
    final AutoRotateConfig config = await _repository.loadConfig();
    final AutoRotateStatus status = await _repository.status();
    emit(
      state.copyWith(loaded: true, isPro: event.isPro, favouriteCount: _urls.length, config: config, status: status),
    );

    if (!event.isPro) {
      if (status.isRunning || config.enabled) {
        await _disable(emit);
      }
      return;
    }
    if (config.enabled && !_canRotate) {
      await _disable(emit);
    } else if (config.enabled && !status.isRunning) {
      await _start(config, emit);
    }
  }

  Future<void> _onFavouritesChanged(_FavouritesChanged event, Emitter<AutoRotateState> emit) async {
    _setUrls(event.favouriteUrls);
    emit(state.copyWith(favouriteCount: _urls.length));
    if (!state.loaded || !state.config.enabled) return;
    if (_canRotate) {
      await _start(state.config, emit);
    } else {
      await _disable(emit);
    }
  }

  Future<void> _onToggled(_Toggled event, Emitter<AutoRotateState> emit) async {
    if (event.enabled) {
      if (!_canRotate) return;
      await _start(state.config.copyWith(enabled: true), emit);
    } else {
      await _disable(emit);
    }
  }

  Future<void> _onConfigChanged(AutoRotateConfig next, Emitter<AutoRotateState> emit) async {
    await _repository.saveConfig(next);
    emit(state.copyWith(config: next));
    if (next.enabled && _canRotate) {
      await _start(next, emit);
    }
  }

  Future<void> _onRotateNow(_RotateNowPressed event, Emitter<AutoRotateState> emit) async {
    if (!state.config.enabled) return;
    await _repository.rotateNow();
    emit(state.copyWith(status: await _repository.status()));
  }

  Future<void> _start(AutoRotateConfig config, Emitter<AutoRotateState> emit) async {
    final bool wasEnabled = state.config.enabled && state.status.isRunning;
    final bool started = await _repository.start(config, _urls);
    if (!started) {
      await _disable(emit, startFailed: true);
      return;
    }
    await _repository.saveConfig(config);
    emit(state.copyWith(config: config, status: await _repository.status(), startFailed: false));
    if (!wasEnabled) {
      analytics.track(
        AutoRotateEnabledEvent(
          intervalMinutes: config.intervalMinutes,
          target: config.target,
          shuffle: config.shuffle,
          wallpaperCount: _urls.length,
        ),
      );
    }
  }

  Future<void> _disable(Emitter<AutoRotateState> emit, {bool startFailed = false}) async {
    final bool wasEnabled = state.config.enabled;
    await _repository.stop();
    final AutoRotateConfig next = state.config.copyWith(enabled: false);
    await _repository.saveConfig(next);
    emit(state.copyWith(config: next, status: const AutoRotateStatus(), startFailed: startFailed));
    if (wasEnabled) {
      analytics.track(const AutoRotateDisabledEvent());
    }
  }
}
