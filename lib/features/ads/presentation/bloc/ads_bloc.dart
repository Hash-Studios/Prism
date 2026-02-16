import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/usecases/ads_usecases.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'ads_event.dart';
part 'ads_state.dart';
part 'ads_bloc.freezed.dart';

@injectable
class AdsBloc extends Bloc<AdsEvent, AdsState> {
  AdsBloc(
    this._createRewardedAdUseCase,
    this._addRewardUseCase,
    this._resetAdsUseCase,
  ) : super(AdsState.initial()) {
    on<_Started>(_onStarted);
    on<_RewardEarned>(_onRewardEarned);
    on<_ResetRequested>(_onResetRequested);
  }

  final CreateRewardedAdUseCase _createRewardedAdUseCase;
  final AddRewardUseCase _addRewardUseCase;
  final ResetAdsUseCase _resetAdsUseCase;

  Future<void> _onStarted(_Started event, Emitter<AdsState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, actionStatus: ActionStatus.inProgress));
    final result = await _createRewardedAdUseCase(const NoParams());
    result.fold(
      onSuccess: (ads) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        ads: ads,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onRewardEarned(
    _RewardEarned event,
    Emitter<AdsState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _addRewardUseCase(AddRewardParams(rewardAmount: event.rewardAmount));
    result.fold(
      onSuccess: (ads) => emit(state.copyWith(
        actionStatus: ActionStatus.success,
        ads: ads,
        shouldUnlockDownload: ads.downloadCoins >= event.unlockThreshold,
      )),
      onFailure: (failure) => emit(state.copyWith(
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }

  Future<void> _onResetRequested(
    _ResetRequested event,
    Emitter<AdsState> emit,
  ) async {
    final result = await _resetAdsUseCase(const NoParams());
    result.fold(
      onSuccess: (ads) => emit(state.copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.idle,
        shouldUnlockDownload: false,
        ads: ads,
        failure: null,
      )),
      onFailure: (failure) => emit(state.copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: failure,
      )),
    );
  }
}
