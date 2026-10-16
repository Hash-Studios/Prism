part of 'trending_bloc.j.dart';

/// One list: the week or all time.
@freezed
abstract class TrendingSection with _$TrendingSection {
  const factory TrendingSection({required LoadStatus status, required List<PrismWallpaper> walls, Failure? failure}) =
      _TrendingSection;

  factory TrendingSection.initial() => const TrendingSection(status: LoadStatus.initial, walls: <PrismWallpaper>[]);
}

@freezed
abstract class TrendingState with _$TrendingState {
  const factory TrendingState({
    required TrendingRange range,
    required TrendingSection week,
    required TrendingSection allTime,
  }) = _TrendingState;

  const TrendingState._();

  factory TrendingState.initial() =>
      TrendingState(range: TrendingRange.week, week: TrendingSection.initial(), allTime: TrendingSection.initial());

  TrendingSection section(TrendingRange range) => switch (range) {
    TrendingRange.week => week,
    TrendingRange.allTime => allTime,
  };

  /// The list of the selected [range].
  TrendingSection get current => section(range);

  TrendingState withSection(TrendingRange range, TrendingSection section) => switch (range) {
    TrendingRange.week => copyWith(week: section),
    TrendingRange.allTime => copyWith(allTime: section),
  };
}
