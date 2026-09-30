import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/version_compare.dart';
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
  }

  final BootstrapAppUseCase _bootstrapAppUseCase;

  Future<void> _onStarted(_Started event, Emitter<StartupState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));

    final result = await _bootstrapAppUseCase(const NoParams());

    result.fold(
      onSuccess: (config) => emit(
        state.copyWith(
          status: LoadStatus.success,
          config: config,
          isObsoleteVersion: isVersionOlder(event.currentVersion ?? '0.0.0', config.obsoleteAppVersion),
        ),
      ),
      onFailure: (_) => emit(state.copyWith(status: LoadStatus.failure)),
    );
  }
}
