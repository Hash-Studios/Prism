import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/usecases/bootstrap_app_usecase.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'startup_event.j.dart';
part 'startup_state.j.dart';
part 'startup_bloc.j.freezed.dart';

/// Compares valid dotted numeric versions part by part, ignoring valid suffixes.
bool isVersionLower(String version, String other) {
  List<int>? parse(String value) {
    final match = RegExp(
      r'^([0-9]+(?:\.[0-9]+)*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
    ).firstMatch(value.trim());
    if (match == null) return null;

    final parts = <int>[];
    for (final component in match.group(1)!.split('.')) {
      final part = int.tryParse(component);
      if (part == null) return null;
      parts.add(part);
    }
    return parts;
  }

  final a = parse(version);
  final b = parse(other);
  if (a == null || b == null) return false;

  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}

@injectable
class StartupBloc extends Bloc<StartupEvent, StartupState> {
  StartupBloc(this._bootstrapAppUseCase) : super(StartupState.initial()) {
    on<_Started>(_onStarted);
    on<_RetryRequested>(_onRetryRequested);
    on<_NotchMeasured>(_onNotchMeasured);
  }

  final BootstrapAppUseCase _bootstrapAppUseCase;

  Future<void> _onStarted(_Started event, Emitter<StartupState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress, failure: null));

    final result = await _bootstrapAppUseCase(const NoParams());

    result.fold(
      onSuccess: (config) {
        final currentVersion = event.currentVersion ?? '';
        final isObsolete = isVersionLower(currentVersion, config.obsoleteAppVersion);

        emit(
          state.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            config: config,
            isObsoleteVersion: isObsolete,
            failure: null,
          ),
        );
      },
      onFailure: (failure) =>
          emit(state.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onRetryRequested(_RetryRequested event, Emitter<StartupState> emit) {
    add(StartupEvent.started(currentVersion: event.currentVersion));
    return Future<void>.value();
  }

  void _onNotchMeasured(_NotchMeasured event, Emitter<StartupState> emit) {
    emit(state.copyWith(notchHeight: event.notchHeight));
  }
}
