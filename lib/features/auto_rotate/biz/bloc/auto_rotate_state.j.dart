part of 'auto_rotate_bloc.j.dart';

@freezed
abstract class AutoRotateState with _$AutoRotateState {
  const factory AutoRotateState({
    required AutoRotateConfigEntity config,
    required bool isRunning,
    required LoadStatus status,
    required ActionStatus actionStatus,
    required List<String> availableCollections,
    required List<CategoryDefinition> availableCategories,
    Failure? failure,
  }) = _AutoRotateState;

  factory AutoRotateState.initial() => AutoRotateState(
    config: AutoRotateConfigEntity.defaults,
    isRunning: false,
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    availableCollections: const <String>[],
    availableCategories: categoryDefinitions,
  );
}
