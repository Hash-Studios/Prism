// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/analysis/utilities.dart';
// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/ast/ast.dart';
// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/ast/visitor.dart';
// ignore: depend_on_referenced_packages
import 'package:analyzer/source/line_info.dart';

const Set<String> _uiConstructorNames = <String>{
  'Text',
  'TextSpan',
  'RichText',
  'SelectableText',
  'Tooltip',
  'SnackBarAction',
  'Semantics',
  'GlintState',
};

const Set<String> _uiCallNames = <String>{
  'showToast',
  'showDialog',
  'showCupertinoDialog',
  'showModalBottomSheet',
  'showSnackBar',
  'showAdaptiveDialog',
  'showCupertinoModalPopup',
  'showPrismConfirm',
};

const Set<String> _logCallNames = <String>{'debugPrint', 'log', 'print', 'warning'};

const Set<String> _uiParameterNames = <String>{
  'buttonText',
  'actionLabel',
  'cancelLabel',
  'dismissLabel',
  'confirmLabel',
  'cancelText',
  'confirmText',
  'content',
  'errorText',
  'failureTitle',
  'emptyTitle',
  'emptyBody',
  'emptyActionLabel',
  'emptyText',
  'helperText',
  'hintText',
  'label',
  'labelText',
  'message',
  'placeholder',
  'semanticLabel',
  'subtitle',
  'title',
  'text',
  'tooltip',
  'iconTooltip',
};

const Map<String, Set<String>> _uiNamedArguments = <String, Set<String>>{
  'PrismTextField': <String>{'hint', 'helper', 'error', 'label'},
  'SignInPrompt': <String>{'feature'},
  'CoinGateSpec': <String>{'adErrorMessage', 'spendErrorMessage', 'failureLabel'},
  'ShortcutItem': <String>{'localizedTitle'},
  'ShareCardContent': <String>{'contextLine', 'creatorLine'},
};

class _LiteralFinding {
  const _LiteralFinding({
    required this.file,
    required this.line,
    required this.context,
    required this.literal,
    required this.classification,
  });

  final String file;
  final int line;
  final String context;
  final String literal;
  final String classification;

  Map<String, Object> toJson() => <String, Object>{
    'file': file,
    'line': line,
    'context': context,
    'literal': literal,
    'classification': classification,
  };
}

void main(List<String> args) {
  final bool check = args.contains('--check');
  String root = Directory.current.path;
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--root' && i + 1 < args.length) root = args[++i];
  }

  final Directory project = Directory(root).absolute;
  final Directory lib = Directory('${project.path}/lib');
  if (!File('${project.path}/pubspec.yaml').existsSync() || !lib.existsSync()) {
    stderr.writeln('Expected pubspec.yaml and lib/ under ${project.path}');
    exitCode = 2;
    return;
  }

  final List<_LiteralFinding> findings = _audit(lib, project.path);
  if (args.contains('--summary')) {
    final List<_LiteralFinding> probable = findings
        .where((f) => f.classification == 'probable_ui' || f.classification == 'parse_error')
        .toList();
    for (final _LiteralFinding finding in probable) {
      stdout.writeln('${finding.file}:${finding.line}: ${finding.context}: ${jsonEncode(finding.literal)}');
    }
    stdout.writeln(
      '${probable.length} probable UI literals; ${findings.where((f) => f.classification == 'review').length} indirect literals to review.',
    );
  } else {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(<String, Object>{
        'root': project.path,
        'literalCount': findings.length,
        'probableUiCount': findings.where((f) => f.classification == 'probable_ui').length,
        'parseErrorCount': findings.where((f) => f.classification == 'parse_error').length,
        'findings': findings.map((f) => f.toJson()).toList(),
      }),
    );
  }

  if (check && findings.any((f) => f.classification == 'probable_ui' || f.classification == 'parse_error')) {
    exitCode = 1;
  }
}

List<_LiteralFinding> _audit(Directory lib, String root) {
  final List<File> files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart') && !_isGeneratedOrLocalization(file.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final List<_LiteralFinding> findings = <_LiteralFinding>[];

  for (final File file in files) {
    final String source = file.readAsStringSync();
    final parsed = parseString(content: source, path: file.path, throwIfDiagnostics: false);
    for (final error in parsed.errors) {
      findings.add(
        _LiteralFinding(
          file: file.path.substring(root.length + 1),
          line: parsed.lineInfo.getLocation(error.offset).lineNumber,
          context: error.message,
          literal: '',
          classification: 'parse_error',
        ),
      );
    }
    final CompilationUnit unit = parsed.unit;
    final _StringLiteralVisitor visitor = _StringLiteralVisitor(
      file: file.path.substring(root.length + 1),
      lineInfo: unit.lineInfo,
    );
    unit.accept(visitor);
    findings.addAll(visitor.findings);
  }
  return findings;
}

bool _isGeneratedOrLocalization(String path) {
  final String normalized = path.replaceAll('\\', '/');
  final String name = normalized.split('/').last;
  return name.endsWith('.g.dart') ||
      name.endsWith('.freezed.dart') ||
      name.endsWith('.gr.dart') ||
      name.endsWith('.m.dart') ||
      name.startsWith('app_localizations') ||
      normalized.contains('/lib/l10n/');
}

class _StringLiteralVisitor extends RecursiveAstVisitor<void> {
  _StringLiteralVisitor({required this.file, required this.lineInfo});

  final String file;
  final LineInfo lineInfo;
  final List<_LiteralFinding> findings = <_LiteralFinding>[];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _add(node, node.value);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    _add(node, node.toSource());
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    _add(node, node.toSource());
  }

  void _add(AstNode node, String literal) {
    final (String classification, String context) = _classify(node, literal);
    findings.add(
      _LiteralFinding(
        file: file,
        line: lineInfo.getLocation(node.offset).lineNumber,
        context: context,
        literal: literal,
        classification: classification,
      ),
    );
  }

  (String, String) _classify(AstNode node, String literal) {
    if (literal.trim().isEmpty) return ('non_ui', 'empty text or whitespace separator');
    if (RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://$').hasMatch(literal)) {
      return ('non_ui', 'URL scheme placeholder');
    }
    final RegExp punctuation = RegExp(r'''^[\s\d@,.:;!?%+×/()\[\]#'"\-·…]*$''');
    if (node is StringInterpolation &&
        node.elements.whereType<InterpolationString>().every((part) => punctuation.hasMatch(part.value))) {
      return ('review', 'interpolated values and punctuation');
    }
    if (node is SimpleStringLiteral && punctuation.hasMatch(node.value)) {
      return ('review', 'numeric or punctuation-only text');
    }
    if (node is AdjacentStrings &&
        node.strings.every(
          (part) => switch (part) {
            SimpleStringLiteral() => punctuation.hasMatch(part.value),
            StringInterpolation() => part.elements.whereType<InterpolationString>().every(
              (text) => punctuation.hasMatch(text.value),
            ),
            _ => false,
          },
        )) {
      return ('review', 'adjacent interpolated values and punctuation');
    }
    AstNode? current = node.parent;
    String? namedArgument;
    String? declaration;
    AstNode? namedOwner;
    bool inDirective = false;
    bool crossedOtherCall = false;

    while (current != null) {
      if (current is DefaultFormalParameter && _uiParameterNames.contains(current.parameter.name?.lexeme)) {
        return ('probable_ui', 'UI parameter default');
      }
      if (current is ConstantPattern || current is SwitchCase) {
        return ('non_ui', 'pattern discriminator');
      }
      if (current is BinaryExpression && <String>{'==', '!='}.contains(current.operator.lexeme)) {
        return ('non_ui', 'comparison value');
      }
      if (current is IndexExpression && identical(current.index, node)) {
        return ('non_ui', 'data lookup key');
      }
      if (current is Directive) {
        inDirective = true;
      }
      if (current is NamedExpression && namedArgument == null) {
        namedArgument = current.name.label.name;
        if (current.parent is ArgumentList) {
          final AstNode argumentParent = current.parent!.parent!;
          if (argumentParent is InstanceCreationExpression || argumentParent is MethodInvocation) {
            namedOwner = argumentParent;
          }
        }
      }
      if (current is FunctionDeclaration) declaration ??= current.name.lexeme;
      if (current is MethodDeclaration) declaration ??= current.name.lexeme;
      if (current is EnumConstantDeclaration) {
        declaration ??= current.name.lexeme;
      }
      if (current is VariableDeclaration) declaration ??= current.name.lexeme;

      if (current is InstanceCreationExpression) {
        final String name = current.constructorName.type.name.lexeme;
        if (<String>{'AndroidNotificationDetails', 'AndroidNotificationChannel'}.contains(name) &&
            current.argumentList.arguments.length > 1 &&
            identical(current.argumentList.arguments[1], node)) {
          return ('probable_ui', '$name channel name');
        }
        if (_uiConstructorNames.contains(name) && !crossedOtherCall) {
          return ('probable_ui', '$name constructor');
        }
        if (namedOwner == current &&
            !crossedOtherCall &&
            namedArgument != null &&
            (_uiParameterNames.contains(namedArgument) && _looksLikeUiType(name) ||
                _uiNamedArguments[name]?.contains(namedArgument) == true)) {
          return ('probable_ui', '$name.$namedArgument');
        }
        crossedOtherCall = true;
      }
      if (current is MethodInvocation) {
        final String name = current.methodName.name;
        final String? target = current.target?.toSource();
        if (<String>{'AndroidNotificationDetails', 'AndroidNotificationChannel'}.contains(name) &&
            current.argumentList.arguments.length > 1 &&
            identical(current.argumentList.arguments[1], node)) {
          return ('probable_ui', '$name channel name');
        }
        if (!crossedOtherCall && target == 'toasts' && <String>{'error', 'success', 'info'}.contains(name)) {
          return ('probable_ui', 'toasts.$name');
        }
        if (_logCallNames.contains(name)) {
          return ('non_ui', '$name logging call');
        }
        if (_uiConstructorNames.contains(name) && !crossedOtherCall) {
          return ('probable_ui', '$name constructor');
        }
        if (namedOwner == current &&
            !crossedOtherCall &&
            namedArgument != null &&
            (_uiParameterNames.contains(namedArgument) && _looksLikeUiType(name) ||
                _uiNamedArguments[name]?.contains(namedArgument) == true)) {
          return ('probable_ui', '$name.$namedArgument');
        }
        if (_uiCallNames.contains(name) && !crossedOtherCall) {
          return ('probable_ui', '$name call');
        }
        crossedOtherCall = true;
      }
      if (current is FunctionExpression) break;
      current = current.parent;
    }

    if (inDirective) {
      return ('non_ui', 'directive URI or metadata');
    }
    if (_isProtocolOrPath(literal)) {
      return ('non_ui', 'URI or path literal');
    }
    if (declaration != null) {
      return ('review', 'inside declaration: $declaration');
    }
    return ('review', 'other Dart string literal');
  }

  bool _isProtocolOrPath(String value) =>
      RegExp('^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(value) ||
      value.startsWith('app-settings:') ||
      value.startsWith('mailto:') ||
      value.startsWith('tel:') ||
      value.startsWith('sms:') ||
      value.startsWith('file:') ||
      value.startsWith('assets/') ||
      value.startsWith('package:') ||
      value.startsWith('lib/') ||
      value.startsWith('/');

  bool _looksLikeUiType(String name) =>
      _uiConstructorNames.contains(name) ||
      RegExp(r'^[A-Z]').hasMatch(name) && !RegExp(r'(Result|Failure|Exception|Payload)$').hasMatch(name);
}
