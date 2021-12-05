import 'package:flutter/material.dart';

class InheritedContainer extends InheritedWidget {
  const InheritedContainer(
      {Key? key, required this.child, required this.controller})
      : super(key: key, child: child);

  final ScrollController controller;
  @override
  // ignore: overridden_fields
  final Widget child;

  static InheritedContainer? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedContainer>();
  }

  @override
  bool updateShouldNotify(InheritedContainer oldWidget) {
    return oldWidget.controller != controller;
  }
}
