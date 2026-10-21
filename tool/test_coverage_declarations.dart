import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class _ExecutableSource extends GeneralizingAstVisitor<void> {
  bool found = false;

  @override
  void visitFunctionBody(FunctionBody node) {
    if (node is! EmptyFunctionBody) found = true;
    super.visitFunctionBody(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (node.factoryKeyword != null && node.redirectedConstructor != null && node.body is EmptyFunctionBody) return;
    found = true;
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.initializer != null && !(node.parent! as VariableDeclarationList).isConst) found = true;
    super.visitVariableDeclaration(node);
  }
}

void main(List<String> paths) {
  final List<String> declarations = <String>[];
  for (final String path in paths) {
    final result = parseString(content: File(path).readAsStringSync(), throwIfDiagnostics: false);
    if (result.errors.isNotEmpty) continue;
    final visitor = _ExecutableSource();
    result.unit.accept(visitor);
    if (!visitor.found) declarations.add(path);
  }
  stdout.writeln(jsonEncode(declarations));
}
