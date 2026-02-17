import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/router/nav_stack.dart' as legacy_nav;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/navigation/domain/entities/navigation_stack_entity.dart';
import 'package:Prism/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: NavigationRepository)
class NavigationRepositoryImpl implements NavigationRepository {
  NavigationStackEntity _entity() => NavigationStackEntity(stack: List<String>.from(legacy_nav.navStack));

  @override
  Future<Result<NavigationStackEntity>> getStack() async {
    return Result.success(_entity());
  }

  @override
  Future<Result<NavigationStackEntity>> push(String routeName) async {
    if (routeName.trim().isEmpty) {
      return Result.error(const ValidationFailure('Route name cannot be empty'));
    }
    legacy_nav.pushNavStack(routeName);
    return Result.success(_entity());
  }

  @override
  Future<Result<NavigationStackEntity>> pop() async {
    legacy_nav.popNavStackIfPossible();
    return Result.success(_entity());
  }

  @override
  Future<Result<NavigationStackEntity>> reset({required String initialRoute}) async {
    if (initialRoute.trim().isEmpty) {
      return Result.error(const ValidationFailure('Initial route cannot be empty'));
    }
    legacy_nav.resetNavStack(root: initialRoute);
    return Result.success(_entity());
  }

  @override
  Future<Result<NavigationStackEntity>> replace(List<String> stack) async {
    if (stack.isEmpty) {
      return Result.error(const ValidationFailure('Stack cannot be empty'));
    }
    legacy_nav.replaceNavStack(stack);
    return Result.success(_entity());
  }
}
