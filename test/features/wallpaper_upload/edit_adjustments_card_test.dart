import 'dart:io';

import 'package:Prism/features/wallpaper_upload/views/widgets/edit_adjustments_card.dart';
import 'package:Prism/l10n/l10n.dart';
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
    final RegExp bareSlider = RegExp(r'(?<![\w.])Slider(\.adaptive)?\(');
    final List<String> offenders = <String>[
      for (final FileSystemEntity f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.endsWith('prism_slider.dart') &&
            bareSlider.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty, reason: 'Use PrismSlider: a bare Slider can empty the iOS accessibility tree');
  });
}
