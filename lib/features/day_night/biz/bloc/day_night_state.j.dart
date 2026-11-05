part of 'day_night_bloc.j.dart';

enum DayNightIssue { timesEqual, needsBothWalls, needsDownloadDay, needsDownloadNight, offlineCopyFailed }

@freezed
abstract class DayNightState with _$DayNightState {
  const factory DayNightState({
    required DayNightPair pair,
    @Default(false) bool loaded,
    @Default(false) bool isPro,
    @Default('') String userId,
    @Default(false) bool preparing,
    DayNightIssue? issue,
    @Default(false) bool proLapsed,
  }) = _DayNightState;

  factory DayNightState.initial() => DayNightState(pair: DayNightPair());
}
