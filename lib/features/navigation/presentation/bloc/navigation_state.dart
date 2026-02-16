part of 'navigation_bloc.dart';

@freezed
abstract class NavigationState with _$NavigationState {
  const factory NavigationState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required List<String> stack,
    required String currentRoute,
    required bool canPop,
    Failure? failure,
  }) = _NavigationState;

  factory NavigationState.initial() => const NavigationState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        stack: <String>['Home'],
        currentRoute: 'Home',
        canPop: false,
      );
}
