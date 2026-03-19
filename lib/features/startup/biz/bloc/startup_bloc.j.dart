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
        final currentVersion = event.currentVersion ?? '0.0.0';
        final isObsolete =
            int.parse(currentVersion.replaceAll('.', '')) < int.parse(config.obsoleteAppVersion.replaceAll('.', ''));

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
