part of 'ads_bloc.j.dart';

@freezed
abstract class AdsEvent with _$AdsEvent {
  const factory AdsEvent.started() = _Started;
  const factory AdsEvent.watchAdRequested() = _WatchAdRequested;
  const factory AdsEvent.transientStateCleared() = _TransientStateCleared;
}
