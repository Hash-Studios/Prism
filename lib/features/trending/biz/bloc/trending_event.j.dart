part of 'trending_bloc.j.dart';

@freezed
abstract class TrendingEvent with _$TrendingEvent {
  const factory TrendingEvent.started() = _Started;
  const factory TrendingEvent.refreshRequested() = _RefreshRequested;
  const factory TrendingEvent.startupRetryRequested({required int requestId, required int generation}) =
      _StartupRetryRequested;
  const factory TrendingEvent.blockedCreatorsChanged() = _BlockedCreatorsChanged;
}
