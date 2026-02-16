import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/domain/usecases/setups_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'setups_event.dart';
part 'setups_state.dart';
part 'setups_bloc.freezed.dart';

@injectable
class SetupsBloc extends Bloc<SetupsEvent, SetupsState> {
  SetupsBloc(this._fetchSetupsUseCase) : super(SetupsState.initial()) {
    on<_Started>(_onStarted);
    on<_RefreshRequested>(_onRefreshRequested);
    on<_FetchMoreRequested>(_onFetchMoreRequested);
  }

  final FetchSetupsUseCase _fetchSetupsUseCase;

  Future<void> _onStarted(_Started event, Emitter<SetupsState> emit) {
    return _load(refresh: true, emit: emit);
  }

  Future<void> _onRefreshRequested(
    _RefreshRequested event,
    Emitter<SetupsState> emit,
  ) {
    return _load(refresh: true, emit: emit);
  }

  Future<void> _onFetchMoreRequested(
    _FetchMoreRequested event,
    Emitter<SetupsState> emit,
  ) async {
    if (state.isFetchingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(isFetchingMore: true, actionStatus: ActionStatus.inProgress));
    await _load(refresh: false, emit: emit);
  }

  Future<void> _load({required bool refresh, required Emitter<SetupsState> emit}) async {
    if (refresh) {
      emit(state.copyWith(
        status: LoadStatus.loading,
        actionStatus: ActionStatus.inProgress,
        failure: null,
      ));
    }

    final result = await _fetchSetupsUseCase(FetchSetupsParams(refresh: refresh));

    result.fold(
      onSuccess: (page) {
        final merged = refresh ? page.items : <SetupEntity>[...state.items, ...page.items];
        final uniqueById = <String, SetupEntity>{
          for (final item in merged) item.id: item,
        }.values.toList(growable: false);

        emit(state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          items: uniqueById,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          isFetchingMore: false,
          failure: null,
        ));
      },
      onFailure: (failure) => emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        isFetchingMore: false,
        failure: failure,
      )),
    );
  }
}
