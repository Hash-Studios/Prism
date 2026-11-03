import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/filter_editor_panel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('crop tab stays within a 320 px viewport with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: _PanelHost(crop: CropSpec.initial(sourceWidth: 1200, sourceHeight: 2400, phoneAspect: 9 / 19.5)),
        ),
      ),
    );

    await tester.tap(find.text('Crop'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(MediaQuery.textScalerOf(tester.element(find.text('Free'))).scale(10), 20);
    expect(find.text('Free'), findsOneWidget);
    expect(find.byTooltip('Rotate 90°'), findsOneWidget);
  });
}

class _PanelHost extends StatefulWidget {
  const _PanelHost({required this.crop});

  final CropSpec crop;

  @override
  State<_PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends State<_PanelHost> with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FilterEditorPanel(
    controller: _controller,
    thumbProvider: const AssetImage(''),
    stack: const <WallpaperFilter>[],
    adjustments: WallpaperAdjustments.none,
    effectsAvailable: false,
    kernelThumbFilters: const <KernelEffect, ui.ImageFilter>{},
    onClear: () {},
    onToggle: (_) {},
    onAdjust: (_) {},
    crop: widget.crop,
    onCropPreset: (_) {},
    onRotate: () {},
    onCropReset: () {},
  );
}
