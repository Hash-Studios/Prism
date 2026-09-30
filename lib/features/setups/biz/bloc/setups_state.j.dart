part of 'setups_bloc.j.dart';

@freezed
abstract class SetupsState with _$SetupsState {
  const factory SetupsState({
    required LoadStatus status,
    required List<SetupEntity> items,
    required bool hasMore,
    required bool isFetchingMore,
  }) = _SetupsState;

  factory SetupsState.initial() =>
      const SetupsState(status: LoadStatus.initial, items: <SetupEntity>[], hasMore: true, isFetchingMore: false);
}
