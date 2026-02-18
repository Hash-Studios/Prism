part of 'setups_bloc.j.dart';

@freezed
abstract class SetupsState with _$SetupsState {
  const factory SetupsState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required List<SetupEntity> items,
    required bool hasMore,
    required String? nextCursor,
    required bool isFetchingMore,
    Failure? failure,
  }) = _SetupsState;

  factory SetupsState.initial() => const SetupsState(
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    items: <SetupEntity>[],
    hasMore: true,
    nextCursor: null,
    isFetchingMore: false,
  );
}
