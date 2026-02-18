part of 'quick_actions_bloc.j.dart';

@freezed
abstract class QuickActionsState with _$QuickActionsState {
  const factory QuickActionsState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required QuickActionEntity? latestAction,
    required List<QuickActionEntity> history,
    Failure? failure,
  }) = _QuickActionsState;

  factory QuickActionsState.initial() => const QuickActionsState(
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    latestAction: null,
    history: <QuickActionEntity>[],
  );
}
