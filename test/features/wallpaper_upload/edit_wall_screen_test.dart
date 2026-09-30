import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/edit_wall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<File> makeImage(WidgetTester tester) async {
    final Directory dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('prism-edit-wall-')))!;
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final File image = File('${dir.path}/pixel.png');
    await tester.runAsync(
      () => image.writeAsBytes(
        base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC'),
      ),
    );
    return image;
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final File image = await makeImage(tester);
    await tester.pumpWidget(MaterialApp(home: EditWallScreen(image: image)));
    await tester.pump();
  }

  testWidgets('shows the crop shapes, the three adjustments and one Save action', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Edit wallpaper'), findsOneWidget);
    for (final String label in <String>['9:18', '9:16', '9:21', '9:19.5']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Saturation'), findsOneWidget);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Contrast'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.byTooltip('Flip'), findsOneWidget);
    expect(find.byTooltip('Rotate left'), findsOneWidget);
    expect(find.byTooltip('Rotate right'), findsOneWidget);
    expect(find.byTooltip('Reset adjustments'), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset puts the adjustments back to their defaults', (tester) async {
    await pumpScreen(tester);

    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pump();
    expect(find.text('1.00'), findsNWidgets(1));

    await tester.tap(find.byTooltip('Reset adjustments'));
    await tester.pump();

    expect(find.text('1.00'), findsNWidgets(2));
    expect(find.text('0.00'), findsOneWidget);
  });

  testWidgets('leaving after an edit asks before discarding', (tester) async {
    await pumpScreen(tester);

    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard your edits?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit wallpaper'), findsOneWidget);
  });
}
