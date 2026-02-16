part of 'deep_link_bloc.j.dart';

@freezed
abstract class DeepLinkState with _$DeepLinkState {
  const factory DeepLinkState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required DeepLinkActionEntity? initialAction,
    required DeepLinkActionEntity? latestAction,
    required List<DeepLinkActionEntity> history,
    Failure? failure,
  }) = _DeepLinkState;

  factory DeepLinkState.initial() => const DeepLinkState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        initialAction: null,
        latestAction: null,
        history: <DeepLinkActionEntity>[],
      );
}
