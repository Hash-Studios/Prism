import 'package:flutter/material.dart';

class InheritedDataProvider extends InheritedWidget {
  final ScrollController? scrollController;
  const InheritedDataProvider({
    required super.child,
    this.scrollController,
  });
  @override
  bool updateShouldNotify(InheritedDataProvider oldWidget) => scrollController != oldWidget.scrollController;
  static InheritedDataProvider? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InheritedDataProvider>();
}
