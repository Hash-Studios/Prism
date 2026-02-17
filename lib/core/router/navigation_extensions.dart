import 'package:flutter/widgets.dart';

extension PrismNavigationExtensions on BuildContext {
  @optionalTypeArgs
  Future<T?> pushNamedRoute<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);
  }

  @optionalTypeArgs
  Future<T?> pushNamedAndRemoveUntilRoute<T extends Object?>(
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    return Navigator.of(this).pushNamedAndRemoveUntil<T>(
      newRouteName,
      predicate,
      arguments: arguments,
    );
  }

  @optionalTypeArgs
  Future<T?> pushReplacementNamedRoute<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return Navigator.of(this).pushReplacementNamed<T, TO>(
      routeName,
      result: result,
      arguments: arguments,
    );
  }
}
