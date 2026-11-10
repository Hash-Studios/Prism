import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a tappable row exposes one button with a tap action', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrismRow(title: 'Open settings', onTap: () => taps++),
        ),
      ),
    );

    final SemanticsNode row = tester.getSemantics(find.text('Open settings'));
    expect(row.flagsCollection.isButton, isTrue);
    expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    row.owner!.performAction(row.id, SemanticsAction.tap);
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a switch row keeps the switch role instead of becoming a button', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrismSwitchRow(title: 'Notifications', value: true, onChanged: _ignoreChanged),
        ),
      ),
    );

    final SemanticsNode row = tester.getSemantics(find.text('Notifications'));
    expect(row.flagsCollection.isButton, isFalse);
    expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(_allSemanticsNodes(row).any((node) => node.flagsCollection.isToggled == ui.Tristate.isTrue), isTrue);
    handle.dispose();
  });

  testWidgets('a directly composed switch row preserves its toggle role', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MergeSemantics(
            child: PrismRow(
              title: 'One-handed controls',
              onTap: () {},
              trailing: const Switch(value: true, onChanged: _ignoreChanged),
            ),
          ),
        ),
      ),
    );

    final SemanticsNode row = tester.getSemantics(find.text('One-handed controls'));
    expect(row.flagsCollection.isButton, isFalse);
    expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(_allSemanticsNodes(row).any((node) => node.flagsCollection.isToggled == ui.Tristate.isTrue), isTrue);
    handle.dispose();
  });

  testWidgets('an outer button wrapper with excluded child semantics remains one control', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Semantics(
            button: true,
            label: 'Depth effect',
            excludeSemantics: true,
            onTap: () => taps++,
            child: PrismRow(title: 'Depth effect', onTap: () => taps++),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Depth effect'), findsOneWidget);
    final SemanticsNode row = tester.getSemantics(find.bySemanticsLabel('Depth effect'));
    expect(row.flagsCollection.isButton, isTrue);
    row.owner!.performAction(row.id, SemanticsAction.tap);
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });
}

void _ignoreChanged(bool value) {}

List<SemanticsNode> _allSemanticsNodes(SemanticsNode member) {
  final SemanticsNode root = member.owner!.rootSemanticsNode!;
  final List<SemanticsNode> nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return nodes;
}
