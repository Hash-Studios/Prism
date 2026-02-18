import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/navigation/domain/entities/navigation_stack_entity.dart';
import 'package:Prism/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GetNavigationStackUseCase implements UseCase<NavigationStackEntity, NoParams> {
  GetNavigationStackUseCase(this._repository);

  final NavigationRepository _repository;

  @override
  Future<Result<NavigationStackEntity>> call(NoParams params) => _repository.getStack();
}

class PushRouteParams {
  const PushRouteParams({required this.routeName});

  final String routeName;
}

@lazySingleton
class PushRouteUseCase implements UseCase<NavigationStackEntity, PushRouteParams> {
  PushRouteUseCase(this._repository);

  final NavigationRepository _repository;

  @override
  Future<Result<NavigationStackEntity>> call(PushRouteParams params) => _repository.push(params.routeName);
}

@lazySingleton
class PopRouteUseCase implements UseCase<NavigationStackEntity, NoParams> {
  PopRouteUseCase(this._repository);

  final NavigationRepository _repository;

  @override
  Future<Result<NavigationStackEntity>> call(NoParams params) => _repository.pop();
}

class ResetNavigationParams {
  const ResetNavigationParams({required this.initialRoute});

  final String initialRoute;
}

@lazySingleton
class ResetNavigationUseCase implements UseCase<NavigationStackEntity, ResetNavigationParams> {
  ResetNavigationUseCase(this._repository);

  final NavigationRepository _repository;

  @override
  Future<Result<NavigationStackEntity>> call(ResetNavigationParams params) =>
      _repository.reset(initialRoute: params.initialRoute);
}

class ReplaceNavigationStackParams {
  const ReplaceNavigationStackParams({required this.stack});

  final List<String> stack;
}

@lazySingleton
class ReplaceNavigationStackUseCase implements UseCase<NavigationStackEntity, ReplaceNavigationStackParams> {
  ReplaceNavigationStackUseCase(this._repository);

  final NavigationRepository _repository;

  @override
  Future<Result<NavigationStackEntity>> call(ReplaceNavigationStackParams params) => _repository.replace(params.stack);
}
