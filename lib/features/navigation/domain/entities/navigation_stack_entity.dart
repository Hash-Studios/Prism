class NavigationStackEntity {
  const NavigationStackEntity({required this.stack});

  final List<String> stack;

  String get current => stack.isEmpty ? '' : stack.last;
  bool get canPop => stack.length > 1;
}
