part of 'navigation_bloc.j.dart';

@freezed
abstract class NavigationEvent with _$NavigationEvent {
  const factory NavigationEvent.started() = _Started;
  const factory NavigationEvent.routePushed({required String routeName}) = _RoutePushed;
  const factory NavigationEvent.routePopped() = _RoutePopped;
  const factory NavigationEvent.resetRequested({
    @Default('Home') String initialRoute,
  }) = _ResetRequested;
  const factory NavigationEvent.stackReplaced({required List<String> stack}) = _StackReplaced;
}
