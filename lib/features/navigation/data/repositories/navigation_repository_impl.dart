import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/navigation/domain/entities/navigation_stack_entity.dart';
import 'package:Prism/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: NavigationRepository)
class NavigationRepositoryImpl implements NavigationRepository {
  List<String> _navStack = <String>['Home'];

  NavigationStackEntity _entity() => NavigationStackEntity(stack: List<String>.from(_navStack));

  @override
  Future<Result<NavigationStackEntity>> getStack() async {
    return Result.success(_entity());
  }

  @override
  Future<Result<NavigationStackEntity>> push(String routeName) async {
    if (routeName.trim().isEmpty) {
      return Result.error(const ValidationFailure('Route name cannot be empty'));
    }
    _navStack.add(routeName);
    return Result.success(_entity());
  }

  @override
  Future<Result<NavigationStackEntity>> pop() async {
    if (_navStack.length > 1) {
      _navStack.removeLast();
    }
    return Result.success(_entity());
  }

  @override
  Future<Result<NavigationStackEntity>> reset({required String initialRoute}) async {
    if (initialRoute.trim().isEmpty) {
      return Result.error(const ValidationFailure('Initial route cannot be empty'));
    }
    _navStack = <String>[initialRoute];
    return Result.success(_entity());
  }

  @override
  Future<Result<NavigationStackEntity>> replace(List<String> stack) async {
    if (stack.isEmpty) {
      return Result.error(const ValidationFailure('Stack cannot be empty'));
    }
    _navStack = List<String>.from(stack);
    return Result.success(_entity());
  }
}
