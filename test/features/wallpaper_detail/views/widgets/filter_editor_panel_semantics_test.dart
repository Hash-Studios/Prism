import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/filter_editor_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a filter preset exposes and handles its semantic tap action', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      WallpaperFilter? selected;
      const List<int> pixel = <int>[
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
        0,
        0,
        0,
        0x0d,
        0x49,
        0x48,
        0x44,
        0x52,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        0x1f,
        0x15,
        0xc4,
        0x89,
        0,
        0,
        0,
        0x0b,
        0x49,
        0x44,
        0x41,
        0x54,
        8,
        0xd7,
        0x63,
        0xf8,
        0xcf,
        0xc0,
        0xf0,
        0x1f,
        0,
        5,
        0,
        1,
        0xff,
        0x89,
        0x99,
        0x3d,
        0x1d,
        0,
        0,
        0,
        0,
        0x49,
        0x45,
        0x4e,
        0x44,
        0xae,
        0x42,
        0x60,
        0x82,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterEditorPanel(
              thumbProvider: MemoryImage(Uint8List.fromList(pixel)),
              stack: const <WallpaperFilter>[],
              adjustments: WallpaperAdjustments.none,
              effectsAvailable: false,
              kernelThumbFilters: const <KernelEffect, ui.ImageFilter>{},
              onClear: () {},
              onToggle: (filter) => selected = filter,
              onAdjust: (_) {},
            ),
          ),
        ),
      );

      final SemanticsNode preset = tester.getSemantics(find.bySemanticsLabel('AddictiveBlue'));
      expect(preset.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: preset.id),
      );

      expect(selected?.name, colorPresets.first.name);
    } finally {
      semantics.dispose();
    }
  });
}
