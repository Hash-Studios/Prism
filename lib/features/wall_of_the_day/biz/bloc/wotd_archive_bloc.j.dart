import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wotd_past_pick.dart';
import 'package:Prism/features/wall_of_the_day/domain/usecases/fetch_wotd_archive_usecase.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'wotd_archive_event.j.dart';
part 'wotd_archive_state.j.dart';
part 'wotd_archive_bloc.j.freezed.dart';

@injectable
class WotdArchiveBloc extends Bloc<WotdArchiveEvent, WotdArchiveState> {
  WotdArchiveBloc(this._fetchWotdArchiveUseCase) : super(WotdArchiveState.initial()) {
    on<_Started>((event, emit) => _load(emit));
    on<_RefreshRequested>((event, emit) => _load(emit));
  }

  final FetchWotdArchiveUseCase _fetchWotdArchiveUseCase;
  int _latestRequestId = 0;

  /// Keeps the picks on screen while a refresh runs, and when it fails.
  Future<void> _load(Emitter<WotdArchiveState> emit) async {
    final int requestId = ++_latestRequestId;
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await _fetchWotdArchiveUseCase(const NoParams());
    if (requestId != _latestRequestId) return;
    result.fold(
      onSuccess: (picks) => emit(state.copyWith(status: LoadStatus.success, picks: picks)),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure)),
    );
  }
}
