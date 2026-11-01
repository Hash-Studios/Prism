import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
part 'wrapped_bloc.j.freezed.dart';

@freezed
sealed class WrappedState with _$WrappedState {
  const factory WrappedState.idle() = WrappedIdle;
  const factory WrappedState.loading(String uid) = WrappedLoading;
  const factory WrappedState.ready(String uid, WrappedYear year) = WrappedReady;
  const factory WrappedState.notEligible(String uid) = WrappedNotEligible;
  const factory WrappedState.failed(String uid) = WrappedFailed;
}

@freezed
sealed class WrappedEvent with _$WrappedEvent {
  /// Loads [uid]'s Wrapped unless it is already loaded or loading. A failed load retries.
  const factory WrappedEvent.load(String uid) = LoadWrapped;
}

/// One per app, so the Home card and the story share a single read. Another uid loads afresh.
@lazySingleton
class WrappedBloc extends Bloc<WrappedEvent, WrappedState> {
  WrappedBloc(this._repository) : super(const WrappedState.idle()) {
    on<LoadWrapped>((event, emit) async {
      if (event.uid.isEmpty) {
        _requestVersion++;
        emit(const WrappedState.idle());
        return;
      }
      final bool current = switch (state) {
        WrappedLoading(:final uid) || WrappedReady(:final uid) || WrappedNotEligible(:final uid) => uid == event.uid,
        _ => false,
      };
      if (current) return;
      final int requestVersion = ++_requestVersion;
      emit(WrappedState.loading(event.uid));
      try {
        final WrappedYear? year = await _repository.fetch(event.uid, wrappedYear);
        if (requestVersion != _requestVersion || state != WrappedState.loading(event.uid)) return;
        emit(year == null ? WrappedState.notEligible(event.uid) : WrappedState.ready(event.uid, year));
      } on Exception {
        if (requestVersion == _requestVersion && state == WrappedState.loading(event.uid)) {
          emit(WrappedState.failed(event.uid));
        }
      }
    });
    if (getIt.isRegistered<SessionRepository>()) {
      final SessionRepository sessions = getIt<SessionRepository>();
      _sessionUid = _userId(sessions.currentUser);
      _sessionChanges = sessions.watchCurrentUser().listen(_sessionChanged);
    }
  }

  final WrappedRepository _repository;
  final StreamController<String> _userChanges = StreamController<String>.broadcast(sync: true);
  StreamSubscription<PrismUsersV2>? _sessionChanges;
  late String _sessionUid;
  int _requestVersion = 0;

  Stream<String> get userChanges => _userChanges.stream;

  void _sessionChanged(PrismUsersV2 user) {
    final String uid = _userId(user);
    final String previous = _sessionUid;
    _sessionUid = uid;
    if (previous == uid) return;
    _requestVersion++;
    add(const WrappedEvent.load(''));
    _userChanges.add(uid);
  }

  String _userId(PrismUsersV2 user) => user.loggedIn ? user.id.trim() : '';

  @override
  Future<void> close() async {
    await _sessionChanges?.cancel();
    await _userChanges.close();
    await super.close();
  }
}
