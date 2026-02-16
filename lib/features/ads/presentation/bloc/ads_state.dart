part of 'ads_bloc.dart';

@freezed
abstract class AdsState with _$AdsState {
  const factory AdsState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required AdsEntity ads,
    required bool shouldUnlockDownload,
    Failure? failure,
  }) = _AdsState;

  factory AdsState.initial() => const AdsState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        ads: AdsEntity.empty,
        shouldUnlockDownload: false,
      );
}
