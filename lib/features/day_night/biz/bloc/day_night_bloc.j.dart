import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/domain/repositories/day_night_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'day_night_event.j.dart';
part 'day_night_state.j.dart';
part 'day_night_bloc.j.freezed.dart';

@injectable
class DayNightBloc extends Bloc<DayNightEvent, DayNightState> {
  DayNightBloc(this._repository) : super(DayNightState.initial()) {
    on<DayNightEvent>(
      (event, emit) => event.map<Future<void>>(
        entitlementChanged: (event) => _onEntitlementChanged(event, emit),
        wallPicked: (event) => _applyChange(state.pair.withWall(event.slot, event.wall), emit),
        variantsPicked: (event) =>
            _applyChange(state.pair.copyWith(day: event.day, night: event.night, fromVariants: true), emit),
        timesChanged: (event) => _onTimesChanged(event, emit),
        targetChanged: (event) => _applyChange(state.pair.copyWith(target: event.target), emit),
        toggled: (event) => event.enabled ? _enable(emit) : _turnOff(emit),
        retryPressed: (event) => _enable(emit),
        proLapseAcknowledged: (event) async => emit(state.copyWith(proLapsed: false)),
      ),
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final DayNightRepository _repository;

  Future<void> _onEntitlementChanged(_EntitlementChanged event, Emitter<DayNightState> emit) async {
    final String userId = event.userId.trim();
    if (userId == state.userId) {
      if (state.pair.enabled && !event.isPro) {
        await _lapse(emit, notice: true);
      } else {
        emit(state.copyWith(isPro: event.isPro, loaded: true));
      }
      return;
    }
    final String previousUserId = state.userId;
    final bool wasEnabled = state.pair.enabled;
    if (wasEnabled) await _unpublishQuietly();
    final DayNightPair pair = userId.isEmpty ? DayNightPair() : await _repository.load(ownerId: userId);
    emit(state.copyWith(pair: pair, loaded: true, isPro: event.isPro, userId: userId, issue: null, proLapsed: false));
    if (pair.enabled && !event.isPro) {
      await _lapse(emit, notice: previousUserId.isEmpty, unpublish: !wasEnabled);
    } else if (pair.enabled) {
      try {
        await _repository.publish(pair);
      } catch (error, stackTrace) {
        logger.w(
          'Day and night could not refresh its offline copies.',
          tag: 'DayNightBloc',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _onTimesChanged(_TimesChanged event, Emitter<DayNightState> emit) async {
    final DayNightTimes? times = DayNightTimes.tryCreate(event.dayStart, event.nightStart);
    if (times == null) {
      emit(state.copyWith(issue: DayNightIssue.timesEqual));
      return;
    }
    await _applyChange(state.pair.copyWith(times: times), emit);
  }

  /// Saves a changed pair. An enabled pair is published again, and turned off when its walls cannot be served.
  Future<void> _applyChange(DayNightPair next, Emitter<DayNightState> emit) async {
    final String owner = state.userId;
    if (owner.isEmpty) {
      emit(state.copyWith(pair: next, issue: null));
      return;
    }
    await _repository.save(next, ownerId: owner);
    if (!next.enabled) {
      emit(state.copyWith(pair: next, issue: null));
      return;
    }
    emit(state.copyWith(pair: next, issue: null, preparing: true));
    final DayNightIssue? issue = await _publish(next);
    if (issue == null) {
      emit(state.copyWith(preparing: false, issue: null));
      return;
    }
    await _unpublishQuietly();
    final DayNightPair off = next.copyWith(enabled: false);
    await _repository.save(off, ownerId: owner);
    emit(state.copyWith(pair: off, preparing: false, issue: issue));
    analytics.track(const DayNightDisabledEvent());
  }

  Future<void> _enable(Emitter<DayNightState> emit) async {
    if (!state.isPro || state.userId.isEmpty) return;
    if (!state.pair.isComplete) {
      emit(state.copyWith(issue: DayNightIssue.needsBothWalls));
      return;
    }
    final DayNightPair on = state.pair.copyWith(enabled: true);
    emit(state.copyWith(preparing: true, issue: null));
    final DayNightIssue? issue = await _publish(on);
    if (issue != null) {
      emit(state.copyWith(preparing: false, issue: issue));
      return;
    }
    await _repository.save(on, ownerId: state.userId);
    emit(state.copyWith(pair: on, preparing: false, issue: null));
    analytics.track(DayNightEnabledEvent(target: on.target, fromVariants: on.fromVariants));
  }

  /// Null when the offline copies are ready, otherwise the issue to show.
  Future<DayNightIssue?> _publish(DayNightPair pair) async {
    try {
      await _repository.publish(pair);
      return null;
    } on DayNightPrepareException catch (error) {
      return _issueFor(error);
    } catch (error, stackTrace) {
      logger.w('Day and night publish failed.', tag: 'DayNightBloc', error: error, stackTrace: stackTrace);
      return DayNightIssue.offlineCopyFailed;
    }
  }

  Future<void> _turnOff(Emitter<DayNightState> emit) async {
    await _unpublishQuietly();
    final DayNightPair off = state.pair.copyWith(enabled: false);
    if (state.userId.isNotEmpty) await _repository.save(off, ownerId: state.userId);
    emit(state.copyWith(pair: off, issue: null));
    analytics.track(const DayNightDisabledEvent());
  }

  /// Turns the feature off because Pro ended. [notice] shows the lapse message, which only a returning user needs.
  Future<void> _lapse(Emitter<DayNightState> emit, {required bool notice, bool unpublish = true}) async {
    if (unpublish) await _unpublishQuietly();
    final DayNightPair off = state.pair.copyWith(enabled: false);
    await _repository.save(off, ownerId: state.userId);
    emit(state.copyWith(pair: off, isPro: false, proLapsed: notice));
    analytics.track(const DayNightDisabledEvent());
  }

  Future<void> _unpublishQuietly() async {
    try {
      await _repository.unpublish();
    } catch (error, stackTrace) {
      logger.w(
        'Day and night could not remove its Shortcuts snapshot.',
        tag: 'DayNightBloc',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static DayNightIssue _issueFor(DayNightPrepareException error) => switch (error.failure) {
    DayNightPrepareFailure.needsDownload =>
      error.slot == DayNightSlot.night ? DayNightIssue.needsDownloadNight : DayNightIssue.needsDownloadDay,
    DayNightPrepareFailure.offlineCopyFailed => DayNightIssue.offlineCopyFailed,
  };
}
