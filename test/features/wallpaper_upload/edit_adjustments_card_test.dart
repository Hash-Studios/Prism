import 'dart:io';

import 'package:Prism/features/wallpaper_upload/views/widgets/edit_adjustments_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

SemanticsOwner _owner(WidgetTester tester) => tester.binding.renderViews.first.owner!.semanticsOwner!;

List<SemanticsNode> _allNodes(WidgetTester tester) {
  final List<SemanticsNode> nodes = <SemanticsNode>[];
  bool visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren(visit);
    return true;
  }

  visit(_owner(tester).rootSemanticsNode!);
  return nodes;
}

class _BareSliderVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'Slider') found = true;
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String? target = node.target?.toSource();
    if (node.methodName.name == 'Slider' ||
        (node.methodName.name == 'adaptive' && target?.split('.').last == 'Slider')) {
      found = true;
    }
    super.visitMethodInvocation(node);
  }
}

bool _hasBareSlider(String source) {
  final _BareSliderVisitor visitor = _BareSliderVisitor();
  parseString(content: source).unit.accept(visitor);
  return visitor.found;
}

bool _hasBareSliderFile(String path, String source) =>
    path != 'lib/core/widgets/prism/prism_slider.dart' && _hasBareSlider(source);

List<String> _bareSliderFiles() => <String>[
  for (final FileSystemEntity file in Directory('lib').listSync(recursive: true))
    if (file is File && file.path.endsWith('.dart') && _hasBareSliderFile(file.path, file.readAsStringSync()))
      file.path,
];

void main() {
  testWidgets('edit sliders send no grafted traversal node, which empties the iOS tree', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final List<double> saturation = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EditAdjustmentsCard(
              cropRatio: EditCropRatio.r9x16,
              onCropRatio: (_) {},
              onFlip: () {},
              onRotate: (_) {},
              saturation: 1,
              brightness: 0,
              contrast: 1,
              onSaturation: saturation.add,
              onBrightness: (_) {},
              onContrast: (_) {},
            ),
          ),
        ),
      ),
    );

    final List<SemanticsNode> nodes = _allNodes(tester);
    expect(
      nodes.where((n) => n.getSemanticsData().traversalChildIdentifier != null).map((n) => n.id),
      isEmpty,
      reason: 'Slider value indicators graft an OverlayPortal node (flutter/flutter#194541)',
    );

    final SemanticsNode slider = nodes.singleWhere((n) => n.label == 'Saturation 1.00');
    final SemanticsData data = slider.getSemanticsData();
    expect(data.flagsCollection.isSlider, isTrue);
    expect(data.value, '1.00');
    expect(data.increasedValue, '1.04');
    expect(data.decreasedValue, '0.96');

    _owner(tester).performAction(slider.id, SemanticsAction.increase);
    expect(saturation, <double>[1.04]);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('lib uses PrismSlider, not a bare Material Slider', () {
    expect(_bareSliderFiles(), isEmpty, reason: 'Use PrismSlider: a bare Slider can empty the iOS accessibility tree');
  });

  group('bare Slider source guard', () {
    test('finds regular, adaptive, const, spaced, and import-prefixed constructors', () {
      const List<String> sources = <String>[
        'void build() { final widget = Slider(value: 0); }',
        'void build() { final widget = Slider.adaptive(value: 0); }',
        'void build() { const widget = Slider(value: 0); }',
        'void build() { const widget = Slider.adaptive(value: 0); }',
        'void build() { final widget = Slider (value: 0); }',
        'void build() { final widget = Slider.adaptive (value: 0); }',
        'void build() { final widget = Slider /* value indicator */ (value: 0); }',
        'void build() { final widget = Slider /* platform */ .adaptive(value: 0); }',
        'void build() { final widget = material.Slider(value: 0); }',
        'void build() { final widget = material.Slider.adaptive (value: 0); }',
        'void build() { final widget = const material.Slider.adaptive(value: 0); }',
      ];

      for (final String source in sources) {
        expect(_hasBareSlider(source), isTrue, reason: 'Guard missed: $source');
      }
    });

    test('ignores carousel and channel slider types', () {
      expect(_hasBareSlider('void build() { final widget = CarouselSlider(items: const []); }'), isFalse);
      expect(_hasBareSlider('void build() { final widget = _ChannelSlider(value: 0); }'), isFalse);
    });

    test('ignores Slider text in comments and string literals', () {
      const String source = '''
// Slider(value: 0)
const copy = 'Slider.adaptive(value: 0)';
''';
      expect(_hasBareSlider(source), isFalse);
    });

    test('exempts only the PrismSlider implementation file', () {
      const String source = 'void build() { final widget = Slider(value: 0); }';

      expect(_hasBareSliderFile('lib/core/widgets/prism/prism_slider.dart', source), isFalse);
      expect(_hasBareSliderFile('lib/features/example/prism_slider.dart', source), isTrue);
    });
  });
}
