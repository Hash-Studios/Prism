part of 'ads_bloc.dart';

@freezed
abstract class AdsEvent with _$AdsEvent {
  const factory AdsEvent.started() = _Started;
  const factory AdsEvent.rewardEarned({
    required num rewardAmount,
    @Default(10) num unlockThreshold,
  }) = _RewardEarned;
  const factory AdsEvent.resetRequested() = _ResetRequested;
}
