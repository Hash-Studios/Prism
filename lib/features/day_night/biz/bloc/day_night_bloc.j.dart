import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/domain/repositories/day_night_repository.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
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
        fixesChanged: (event) async {
          final DayNightWall? wall = state.pair.wallFor(event.slot);
          if (wall == null) return;
          final DayNightWall fixed = wall.withFixes(event.fixes);
          await _applyChange(
            event.slot == DayNightSlot.day ? state.pair.copyWith(day: fixed) : state.pair.copyWith(night: fixed),
            emit,
          );
        },
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

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  Future<void> _onEntitlementChanged(_EntitlementChanged event, Emitter<DayNightState> emit) async {
    final String userId = event.userId.trim();
    if (userId.isEmpty ? app_state.prismUser.loggedIn : !_ownsCurrentUser(userId)) return;
    if (userId == state.userId) {
      if (!state.loaded && userId.isEmpty) await _unpublishQuietly();
      if (userId.isNotEmpty && !_ownsCurrentUser(userId)) return;
      final (bool entitled, DateTime? until) = _entitlement(event, state.pair, trustStored: userId.isNotEmpty);
      if (state.pair.enabled && !entitled) {
        await _lapse(emit, notice: true);
      } else {
        final DayNightPair pair = await _keepPass(state.pair, until, userId);
        if (userId.isNotEmpty && !_ownsCurrentUser(userId)) return;
        emit(state.copyWith(pair: pair, isPro: entitled, loaded: true));
        if (pair.enabled && _repository.runsOnDevice) await _resume(pair, userId, emit);
      }
      return;
    }
    final bool isInitialSession = !state.loaded;
    final bool onDevice = _repository.runsOnDevice;
    if (!onDevice) await _unpublishQuietly();
    if (!_eventOwnerIsCurrent(userId)) return;
    final DayNightPair stored = userId.isEmpty ? DayNightPair() : await _repository.load(ownerId: userId);
    if (!_eventOwnerIsCurrent(userId)) return;
    final (bool entitled, DateTime? until) = _entitlement(event, stored, trustStored: isInitialSession);
    final DayNightPair pair = entitled ? await _keepPass(stored, until, userId) : stored;
    if (!_eventOwnerIsCurrent(userId)) return;
    final bool resume = onDevice && pair.enabled && entitled && isInitialSession;
    if (onDevice && !resume) {
      await _unpublishQuietly();
      if (!_eventOwnerIsCurrent(userId)) return;
    }
    emit(
      state.copyWith(
        pair: pair,
        loaded: true,
        isPro: entitled,
        userId: userId,
        preparing: false,
        issue: null,
        proLapsed: false,
      ),
    );
    if (pair.enabled && !entitled) {
      await _lapse(emit, notice: isInitialSession, unpublish: false);
    } else if (resume) {
      await _resume(pair, userId, emit);
    } else if (pair.enabled) {
      final DayNightIssue? issue = await _publish(pair, ownerId: userId);
      if (!_ownsCurrentUser(userId)) return;
      if (issue != null) {
        await _saveDisabledAfterPublishFailure(pair, userId, issue, emit);
      }
    }
  }

  /// Whether the mode may run, and the pass end to keep. A stored pass that has not ended still counts while the live
  /// passes read empty, as before they load at launch, but only when [trustStored] says the pair is this user's.
  (bool, DateTime?) _entitlement(_EntitlementChanged event, DayNightPair stored, {required bool trustStored}) {
    final DateTime now = clock();
    final DateTime? until = event.isPro ? event.passUntil : (trustStored ? stored.passUntil : null);
    final bool entitled = event.isPro ? until == null || until.isAfter(now) : until?.isAfter(now) ?? false;
    return (entitled, entitled ? until : null);
  }

  Future<DayNightPair> _keepPass(DayNightPair pair, DateTime? until, String owner) async {
    if (pair.passUntil == until || owner.isEmpty) return pair;
    final DayNightPair next = pair.copyWith(passUntil: () => until);
    await _repository.save(next, ownerId: owner);
    return next;
  }

  /// Android: applies the wall for the current time on app open, and starts the device schedule again when it is gone.
  Future<void> _resume(DayNightPair pair, String owner, Emitter<DayNightState> emit) async {
    try {
      pair = await _repository.load(ownerId: owner);
    } catch (error, stackTrace) {
      logger.w(
        'Day and night could not reload its saved pair.',
        tag: 'DayNightBloc',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    if (!_ownsCurrentUser(owner)) return;
    if (pair != state.pair) emit(state.copyWith(pair: pair, preparing: false, issue: null));
    if (!pair.enabled) return;

    DayNightOpenResult result;
    try {
      result = await _repository.applyOnOpen();
    } catch (error, stackTrace) {
      logger.w('Day and night could not apply on open.', tag: 'DayNightBloc', error: error, stackTrace: stackTrace);
      result = (running: false, switched: null);
    }
    if (!_ownsCurrentUser(owner)) return;
    if (result.switched case final DayNightSwitch switched) {
      analytics.track(DayNightSwitchedEvent(slot: switched.slot.name, source: switched.source.wireValue));
    }
    if (result.running) return;
    final DayNightIssue? issue = await _publish(pair, ownerId: owner);
    if (!_ownsCurrentUser(owner)) return;
    if (issue != null) await _saveDisabledAfterPublishFailure(pair, owner, issue, emit);
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
    if (!_ownsCurrentUser(owner)) return;
    await _repository.save(next, ownerId: owner);
    if (!_ownsCurrentUser(owner)) return;
    if (!next.enabled) {
      emit(state.copyWith(pair: next, issue: null));
      return;
    }
    emit(state.copyWith(pair: next, issue: null, preparing: true));
    final DayNightIssue? issue = await _publish(next, ownerId: owner);
    if (!_ownsCurrentUser(owner)) return;
    if (issue == null) {
      emit(state.copyWith(preparing: false, issue: null));
      return;
    }
    await _saveDisabledAfterPublishFailure(next, owner, issue, emit);
  }

  Future<void> _saveDisabledAfterPublishFailure(
    DayNightPair pair,
    String owner,
    DayNightIssue issue,
    Emitter<DayNightState> emit,
  ) async {
    await _unpublishQuietly();
    if (!_ownsCurrentUser(owner)) return;
    final DayNightPair off = pair.copyWith(enabled: false);
    await _repository.save(off, ownerId: owner);
    if (!_ownsCurrentUser(owner)) return;
    emit(state.copyWith(pair: off, preparing: false, issue: issue));
    analytics.track(const DayNightDisabledEvent());
  }

  Future<void> _enable(Emitter<DayNightState> emit) async {
    if (!state.isPro || state.userId.isEmpty || !_ownsCurrentUser(state.userId)) return;
    if (!state.pair.isComplete) {
      emit(state.copyWith(issue: DayNightIssue.needsBothWalls));
      return;
    }
    final DayNightPair on = state.pair.copyWith(enabled: true);
    emit(state.copyWith(preparing: true, issue: null));
    final DayNightIssue? issue = await _publish(on, ownerId: state.userId);
    if (!_ownsCurrentUser(state.userId)) return;
    if (issue != null) {
      emit(state.copyWith(preparing: false, issue: issue));
      return;
    }
    try {
      await _repository.save(on, ownerId: state.userId);
    } catch (error, stackTrace) {
      if (!_ownsCurrentUser(state.userId)) return;
      logger.w(
        'Day and night could not save its enabled state.',
        tag: 'DayNightBloc',
        error: error,
        stackTrace: stackTrace,
      );
      await _unpublishQuietly();
      if (!_ownsCurrentUser(state.userId)) return;
      emit(state.copyWith(preparing: false, issue: DayNightIssue.offlineCopyFailed));
      return;
    }
    if (!_ownsCurrentUser(state.userId)) return;
    emit(state.copyWith(pair: on, preparing: false, issue: null));
    analytics.track(DayNightEnabledEvent(target: on.target, fromVariants: on.fromVariants));
  }

  /// Null when the offline copies are ready, otherwise the issue to show.
  Future<DayNightIssue?> _publish(DayNightPair pair, {required String ownerId}) async {
    if (!_ownsCurrentUser(ownerId)) return null;
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
    final String owner = state.userId;
    if (owner.isNotEmpty && !_ownsCurrentUser(owner)) return;
    await _unpublishQuietly();
    if (owner.isNotEmpty && !_ownsCurrentUser(owner)) return;
    final DayNightPair off = state.pair.copyWith(enabled: false);
    if (owner.isNotEmpty) {
      await _repository.save(off, ownerId: owner);
      if (!_ownsCurrentUser(owner)) return;
    }
    emit(state.copyWith(pair: off, issue: null));
    analytics.track(const DayNightDisabledEvent());
  }

  /// Turns the feature off because Pro ended. [notice] shows the lapse message, which only a returning user needs.
  Future<void> _lapse(Emitter<DayNightState> emit, {required bool notice, bool unpublish = true}) async {
    if (!_ownsCurrentUser(state.userId)) return;
    if (unpublish) await _unpublishQuietly();
    if (!_ownsCurrentUser(state.userId)) return;
    final DayNightPair off = state.pair.copyWith(enabled: false, passUntil: () => null);
    await _repository.save(off, ownerId: state.userId);
    if (!_ownsCurrentUser(state.userId)) return;
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

  bool _ownsCurrentUser(String userId) =>
      userId.isNotEmpty && app_state.prismUser.loggedIn && app_state.prismUser.id.trim() == userId;

  bool _eventOwnerIsCurrent(String userId) => userId.isEmpty ? !app_state.prismUser.loggedIn : _ownsCurrentUser(userId);

  static DayNightIssue _issueFor(DayNightPrepareException error) => switch (error.failure) {
    DayNightPrepareFailure.needsDownload =>
      error.slot == DayNightSlot.night ? DayNightIssue.needsDownloadNight : DayNightIssue.needsDownloadDay,
    DayNightPrepareFailure.offlineCopyFailed => DayNightIssue.offlineCopyFailed,
  };
}
