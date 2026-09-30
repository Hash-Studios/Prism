import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/usecases/ads_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'ads_event.j.dart';
part 'ads_state.j.dart';
part 'ads_bloc.j.freezed.dart';

@injectable
class AdsBloc extends Bloc<AdsEvent, AdsState> {
  AdsBloc(this._createRewardedAdUseCase, this._showRewardedAdUseCase) : super(AdsState.initial()) {
    on<_Started>(_onStarted);
    on<_WatchAdRequested>(_onWatchAdRequested);
    on<_TransientStateCleared>(_onTransientStateCleared);
  }

  final CreateRewardedAdUseCase _createRewardedAdUseCase;
  final ShowRewardedAdUseCase _showRewardedAdUseCase;

  Future<void> _onStarted(_Started event, Emitter<AdsState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress));
    final result = await _createRewardedAdUseCase(const NoParams());
    result.fold(
      onSuccess: (ads) =>
          emit(state.copyWith(status: LoadStatus.success, actionStatus: ActionStatus.success, ads: ads, failure: null)),
      onFailure: (failure) =>
          emit(state.copyWith(status: LoadStatus.failure, actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onWatchAdRequested(_WatchAdRequested event, Emitter<AdsState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null, shouldUnlockDownload: false));
    final result = await _showRewardedAdUseCase(const NoParams());
    result.fold(
      onSuccess: (ads) => emit(
        state.copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          ads: ads,
          shouldUnlockDownload: ads.rewardEarned,
          failure: null,
        ),
      ),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  void _onTransientStateCleared(_TransientStateCleared event, Emitter<AdsState> emit) {
    emit(
      state.copyWith(
        actionStatus: ActionStatus.idle,
        shouldUnlockDownload: false,
        ads: state.ads.copyWith(adFailed: false),
        failure: null,
      ),
    );
  }
}
