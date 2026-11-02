import 'dart:io';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Duration> read(WidgetTester tester, {required bool reduce}) async {
    late Duration result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Builder(
          builder: (context) {
            result = context.motion(PrismDurations.base);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('motion returns the duration when animations are on', (tester) async {
    expect(await read(tester, reduce: false), PrismDurations.base);
  });

  testWidgets('motion returns zero when animations are disabled', (tester) async {
    expect(await read(tester, reduce: true), Duration.zero);
  });

  testWidgets('a zero duration jumps the scroll offset', (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpList(tester, controller);

    await controller.animateOrJump(400, duration: Duration.zero, curve: Curves.linear);

    expect(controller.offset, 400);
  });

  testWidgets('a positive duration scrolls to the offset', (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpList(tester, controller);

    controller.animateOrJump(400, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.offset, inInclusiveRange(50, 350));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(controller.offset, closeTo(400, 0.01));
  });

  testWidgets('a zero duration jumps the page', (tester) async {
    final PageController controller = PageController();
    addTearDown(controller.dispose);
    await _pumpPages(tester, controller);

    await controller.animateOrJumpToPage(2, duration: Duration.zero, curve: Curves.linear);

    expect(controller.page, 2);
  });

  testWidgets('a positive duration moves to the page', (tester) async {
    final PageController controller = PageController();
    addTearDown(controller.dispose);
    await _pumpPages(tester, controller);

    controller.animateOrJumpToPage(2, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.page, inInclusiveRange(0.25, 1.75));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(controller.page, closeTo(2, 0.01));
  });

  test('scroll animate calls outside the helper cannot receive a zero duration', () {
    final List<String> violations = <String>[];
    for (final File file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('prism_motion.dart')) continue;
      final String source = _stripComments(file.readAsStringSync());
      violations.addAll(_animateToPageCalls(file.path, source));
      violations.addAll(_animateToCallsThatCanPassZero(file.path, source));
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

Future<void> _pumpList(WidgetTester tester, ScrollController controller) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 200,
        child: ListView.builder(
          controller: controller,
          itemCount: 40,
          itemBuilder: (_, int index) => SizedBox(height: 50, child: Text('$index')),
        ),
      ),
    ),
  );
}

Future<void> _pumpPages(WidgetTester tester, PageController controller) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 200,
        child: PageView(
          controller: controller,
          children: const <Widget>[SizedBox.expand(), SizedBox.expand(), SizedBox.expand()],
        ),
      ),
    ),
  );
}

List<String> _animateToPageCalls(String path, String source) {
  return _calls(path, source, '.animateToPage(', (String _, int _) => true);
}

List<String> _animateToCallsThatCanPassZero(String path, String source) {
  return _calls(path, source, '.animateTo(', (String args, int start) => _durationCanBeZero(source, start, args));
}

List<String> _calls(String path, String source, String method, bool Function(String args, int start) include) {
  final List<String> violations = <String>[];
  var searchFrom = 0;
  while (true) {
    final int start = source.indexOf(method, searchFrom);
    if (start < 0) break;
    final int open = start + method.length - 1;
    final int close = _closeParen(source, open);
    final String args = source.substring(open + 1, close);
    if (include(args, start)) {
      final int line = source.substring(0, start).split('\n').length;
      violations.add('$path:$line $method');
    }
    searchFrom = close + 1;
  }
  return violations;
}

bool _durationCanBeZero(String source, int callStart, String args) {
  final RegExp durationArg = RegExp(r'duration\s*:\s*([^,]+)');
  final Match? match = durationArg.firstMatch(args);
  if (match == null) return false;
  final String expression = match.group(1)!.trim();
  if (expression.contains('context.motion') || expression.contains('Duration.zero')) return true;
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(expression)) return false;
  final int bodyStart = source.lastIndexOf('{', callStart);
  final String body = source.substring(bodyStart < 0 ? 0 : bodyStart, callStart);
  return body.contains('$expression = context.motion') ||
      body.contains('Duration $expression = context.motion') ||
      body.contains('$expression = Duration.zero') ||
      body.contains('Duration $expression = Duration.zero');
}

int _closeParen(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return source.length - 1;
}

String _stripComments(String source) {
  final String withoutBlock = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return withoutBlock.replaceAll(RegExp('//.*'), '');
}
