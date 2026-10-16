part of 'trending_bloc.j.dart';

@freezed
abstract class TrendingEvent with _$TrendingEvent {
  const factory TrendingEvent.started() = _Started;
  const factory TrendingEvent.rangeSelected(TrendingRange range) = _RangeSelected;
  const factory TrendingEvent.refreshRequested() = _RefreshRequested;
}
