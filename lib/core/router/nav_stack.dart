import 'package:Prism/logger/logger.dart';

List<String> navStack = <String>['Home'];

String get currentNavStackEntry => navStack.isEmpty ? 'Home' : navStack.last;

void logNavStack() {
  logger.d(navStack.toString());
}

void pushNavStack(String pageName) {
  navStack.add(pageName);
  logNavStack();
}

void popNavStackIfPossible() {
  if (navStack.length > 1) {
    navStack.removeLast();
  }
  logNavStack();
}

void popNavStack() {
  if (navStack.isNotEmpty) {
    navStack.removeLast();
  }
  logNavStack();
}

void resetNavStack({String root = 'Home'}) {
  navStack = <String>[root];
  logNavStack();
}

void replaceNavStack(List<String> stack) {
  navStack = stack.isEmpty ? <String>['Home'] : List<String>.from(stack);
  logNavStack();
}
