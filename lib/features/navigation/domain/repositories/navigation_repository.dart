import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/navigation/domain/entities/navigation_stack_entity.dart';

abstract class NavigationRepository {
  Future<Result<NavigationStackEntity>> getStack();

  Future<Result<NavigationStackEntity>> push(String routeName);

  Future<Result<NavigationStackEntity>> pop();

  Future<Result<NavigationStackEntity>> reset({required String initialRoute});

  Future<Result<NavigationStackEntity>> replace(List<String> stack);
}
