import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/navigation/biz/bloc/navigation_bloc.j.dart';
import 'package:Prism/features/navigation/domain/entities/navigation_stack_entity.dart';
import 'package:Prism/features/navigation/domain/usecases/navigation_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetNavigationStackUseCase extends Mock implements GetNavigationStackUseCase {}

class _MockPushRouteUseCase extends Mock implements PushRouteUseCase {}

class _MockPopRouteUseCase extends Mock implements PopRouteUseCase {}

class _MockResetNavigationUseCase extends Mock implements ResetNavigationUseCase {}

class _MockReplaceNavigationStackUseCase extends Mock implements ReplaceNavigationStackUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const PushRouteParams(routeName: 'Home'));
    registerFallbackValue(const ResetNavigationParams(initialRoute: 'Home'));
    registerFallbackValue(const ReplaceNavigationStackParams(stack: <String>['Home']));
  });

  late _MockGetNavigationStackUseCase getUseCase;
  late _MockPushRouteUseCase pushUseCase;
  late _MockPopRouteUseCase popUseCase;
  late _MockResetNavigationUseCase resetUseCase;
  late _MockReplaceNavigationStackUseCase replaceUseCase;

  setUp(() {
    getUseCase = _MockGetNavigationStackUseCase();
    pushUseCase = _MockPushRouteUseCase();
    popUseCase = _MockPopRouteUseCase();
    resetUseCase = _MockResetNavigationUseCase();
    replaceUseCase = _MockReplaceNavigationStackUseCase();

    when(
      () => getUseCase(const NoParams()),
    ).thenAnswer((_) async => Result.success(const NavigationStackEntity(stack: <String>['Home'])));

    when(
      () => pushUseCase(any()),
    ).thenAnswer((_) async => Result.success(const NavigationStackEntity(stack: <String>['Home', 'Setups'])));

    when(
      () => popUseCase(const NoParams()),
    ).thenAnswer((_) async => Result.success(const NavigationStackEntity(stack: <String>['Home'])));

    when(
      () => resetUseCase(any()),
    ).thenAnswer((_) async => Result.success(const NavigationStackEntity(stack: <String>['Home'])));

    when(
      () => replaceUseCase(any()),
    ).thenAnswer((_) async => Result.success(const NavigationStackEntity(stack: <String>['Home', 'Profile'])));
  });

  blocTest<NavigationBloc, NavigationState>(
    'push and pop update stack and canPop flag',
    build: () => NavigationBloc(getUseCase, pushUseCase, popUseCase, resetUseCase, replaceUseCase),
    act: (bloc) => bloc
      ..add(const NavigationEvent.started())
      ..add(const NavigationEvent.routePushed(routeName: 'Setups'))
      ..add(const NavigationEvent.routePopped()),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.currentRoute, 'Home');
      expect(bloc.state.canPop, isFalse);
    },
  );
}
