import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {ThemeData? theme, double scale = 1, TargetPlatform platform = TargetPlatform.iOS}) =>
    MaterialApp(
      theme: (theme ?? kLightTheme).copyWith(platform: platform),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: app!,
      ),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(key: const Key('capture'), child: child),
        ),
      ),
    );

/// The pre-compact PrismChip's visual subtree from d1fd13bf4^.
Widget _legacyChip(
  BuildContext context, {
  required String label,
  bool selected = false,
  IconData? icon,
  Widget? leading,
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  final Color fg = selected ? cs.surface : cs.onSurface;
  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: PrismSpace.xs),
    decoration: BoxDecoration(
      color: selected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(PrismRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leading != null) ...<Widget>[leading, const SizedBox(width: 6)],
        if (leading == null && icon != null) ...<Widget>[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14, color: fg),
          ),
        ),
      ],
    ),
  );
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester.renderObject(find.byKey(const Key('capture')));
  final ui.Image image = (await tester.runAsync(() => boundary.toImage()))!;
  addTearDown(image.dispose);
  final ByteData bytes = (await tester.runAsync<ByteData?>(() => image.toByteData()))!;
  return bytes.buffer.asUint8List();
}

void main() {
  setUpAll(() async {
    await (FontLoader('Proxima Nova')..addFont(rootBundle.load('assets/fonts/Proxima Nova Bold.otf'))).load();
  });

  testWidgets('default rendering matches the pre-compact chip at both themes and text scales', (tester) async {
    final List<({String name, String label, bool selected, IconData? icon, Widget? leading, double? width})> cases =
        <({String name, String label, bool selected, IconData? icon, Widget? leading, double? width})>[
          (name: 'plain', label: 'Mood', selected: false, icon: null, leading: null, width: null),
          (name: 'icon', label: 'Mood', selected: false, icon: Icons.favorite, leading: null, width: null),
          (
            name: 'leading',
            label: 'Mood',
            selected: false,
            icon: null,
            leading: const CircleAvatar(radius: 5),
            width: null,
          ),
          (name: 'selected', label: 'Mood', selected: true, icon: null, leading: null, width: null),
          (
            name: 'constrained',
            label: 'Long mood label',
            selected: true,
            icon: Icons.favorite,
            leading: null,
            width: 82,
          ),
        ];
    for (final ThemeData theme in <ThemeData>[kLightTheme, kDarkTheme]) {
      for (final double scale in <double>[1, 2]) {
        for (final testCase in cases) {
          Widget scene(Widget chip) => testCase.width == null ? chip : SizedBox(width: testCase.width, child: chip);
          await tester.pumpWidget(
            _host(
              scene(
                PrismChip(
                  label: testCase.label,
                  selected: testCase.selected,
                  icon: testCase.icon,
                  leading: testCase.leading,
                ),
              ),
              theme: theme,
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          final Size actualSize = tester.getSize(find.byKey(const Key('capture')));
          final Uint8List actual = await _pixels(tester);
          await tester.pumpWidget(
            _host(
              Builder(
                builder: (context) => scene(
                  _legacyChip(
                    context,
                    label: testCase.label,
                    selected: testCase.selected,
                    icon: testCase.icon,
                    leading: testCase.leading,
                  ),
                ),
              ),
              theme: theme,
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.getSize(find.byKey(const Key('capture'))), actualSize);
          expect(await _pixels(tester), actual, reason: '${testCase.name}, ${theme.brightness}, scale $scale');
        }
      }
    }
  });

  testWidgets('compact selected and unselected fills use the active theme colors', (tester) async {
    for (final ThemeData theme in <ThemeData>[kLightTheme, kDarkTheme]) {
      for (final bool selected in <bool>[false, true]) {
        await tester.pumpWidget(
          _host(
            PrismChip(label: 'Mood', compact: true, selected: selected),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        final BoxDecoration decoration =
            tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration;
        expect(
          decoration.color,
          selected ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.08),
        );
        expect(
          tester.widget<Text>(find.text('Mood')).style!.color,
          selected ? theme.colorScheme.surface : theme.colorScheme.onSurface,
        );
        final Rect pill = tester.getRect(find.byType(AnimatedContainer));
        expect(tester.getRect(find.text('Mood')).center.dy, closeTo(pill.center.dy, 0.5));
      }
    }
  });

  testWidgets('compact chip meets the platform tap target in a fixed-height row', (tester) async {
    for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.iOS]) {
      var taps = 0;
      final double targetSize = platform == TargetPlatform.android ? 48 : 44;
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: targetSize,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PrismChip(label: 'I', compact: true, onTap: () => taps++),
            ),
          ),
          platform: platform,
        ),
      );
      final Rect target = tester.getRect(find.byType(PrismChip));
      expect(target.height, targetSize, reason: platform.name);
      expect(
        tester.getSize(find.byType(AnimatedContainer)).width,
        greaterThanOrEqualTo(targetSize),
        reason: platform.name,
      );
      await tester.tapAt(Offset(target.center.dx, target.top + 1));
      await tester.tapAt(Offset(target.center.dx, target.bottom - 1));
      expect(taps, 2, reason: platform.name);
    }
  });

  testWidgets('a 2x query-style chip keeps its glyphs inside the pill on Android and iOS', (tester) async {
    for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.iOS]) {
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.centerLeft,
            child: PrismChip(label: 'Recent query', icon: Icons.history_rounded, onTap: () {}),
          ),
          scale: 2,
          platform: platform,
        ),
      );
      await tester.pumpAndSettle();

      final RenderParagraph paragraph = tester.renderObject(find.text('Recent query'));
      final Finder pill = find.byType(AnimatedContainer);
      final Rect pillBounds = tester.getRect(pill);
      final Rect textBounds = tester.getRect(find.text('Recent query'));
      expect(paragraph.didExceedMaxLines, isFalse, reason: platform.name);
      final TextPainter painter = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.size.width);
      final List<ui.LineMetrics> lines = painter.computeLineMetrics();
      painter.dispose();
      expect(lines, hasLength(1), reason: platform.name);
      expect(lines.single.height, lessThanOrEqualTo(paragraph.size.height), reason: platform.name);
      expect(textBounds.top, greaterThanOrEqualTo(pillBounds.top), reason: platform.name);
      expect(textBounds.bottom, lessThanOrEqualTo(pillBounds.bottom), reason: platform.name);
    }
  });

  testWidgets('chip exposes button, label, selected state and tap semantics', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.iOS]) {
        for (final bool selected in <bool>[false, true]) {
          await tester.pumpWidget(
            _host(
              PrismChip(label: 'Nature', compact: true, selected: selected, onTap: () {}),
              platform: platform,
            ),
          );
          await tester.pumpAndSettle();
          expect(Theme.of(tester.element(find.byType(PrismChip))).platform, platform);
          final SemanticsData data = tester.getSemantics(find.bySemanticsLabel('Nature')).getSemanticsData();
          expect(data.label, 'Nature');
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.flagsCollection.isSelected, selected ? ui.Tristate.isTrue : ui.Tristate.isFalse);
          expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
          final double target = platform == TargetPlatform.android ? 48 : 44;
          expect(data.rect.height, target);
          expect(data.rect.width, greaterThanOrEqualTo(target));
        }
      }
    } finally {
      semantics.dispose();
    }
  });
}
