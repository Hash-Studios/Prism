import 'dart:async';
import 'dart:convert';

import 'package:Prism/features/wallpaper_detail/views/widgets/spatial_tilt_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Widget _app({required Widget home, bool reduceMotion = false}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(body: home),
  );
}

SpatialTiltView _view({
  required Stream<Object?> Function() tiltSource,
  ValueChanged<SpatialTiltMode>? onMode,
  Widget? child,
}) {
  return SpatialTiltView(
    image: MemoryImage(_png),
    mapUrl: 'https://x/m.png',
    mapProvider: MemoryImage(_png),
    tiltSource: tiltSource,
    onMode: onMode,
    child: child,
  );
}

void main() {
  testWidgets('cancels the sensor stream on dispose', (tester) async {
    bool cancelled = false;
    final StreamController<Object?> controller = StreamController<Object?>(
      onCancel: () {
        cancelled = true;
      },
    );
    final List<SpatialTiltMode> modes = <SpatialTiltMode>[];

    await tester.pumpWidget(
      _app(
        home: _view(tiltSource: () => controller.stream, onMode: modes.add),
      ),
    );
    controller.add(<double>[0.1, 0.2]);
    await tester.pump();

    expect(modes, <SpatialTiltMode>[SpatialTiltMode.sensor]);
    expect(cancelled, isFalse);

    await tester.pumpWidget(_app(home: const SizedBox()));
    await tester.pump();

    expect(cancelled, isTrue);
  });

  testWidgets('cancels the sensor when the app goes to the background and listens again on resume', (tester) async {
    int listens = 0;
    int cancels = 0;
    Stream<Object?> tiltSource() {
      listens++;
      return StreamController<Object?>(
        onCancel: () {
          cancels++;
        },
      ).stream;
    }

    await tester.pumpWidget(_app(home: _view(tiltSource: tiltSource)));
    await tester.pump();
    expect(listens, 1);
    expect(cancels, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(cancels, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(listens, 2);
  });

  testWidgets('falls back to drag when the sensor stream errors', (tester) async {
    final List<SpatialTiltMode> modes = <SpatialTiltMode>[];

    await tester.pumpWidget(
      _app(
        home: _view(
          tiltSource: () => Stream<Object?>.error(PlatformException(code: 'NO_SENSOR')),
          onMode: modes.add,
        ),
      ),
    );
    await tester.pump();

    expect(modes, <SpatialTiltMode>[SpatialTiltMode.drag]);
    expect(find.text('Drag to tilt'), findsOneWidget);
  });

  testWidgets('reduce motion uses drag and never listens to the sensor', (tester) async {
    int listens = 0;
    final List<SpatialTiltMode> modes = <SpatialTiltMode>[];

    await tester.pumpWidget(
      _app(
        reduceMotion: true,
        home: _view(
          tiltSource: () {
            listens++;
            return const Stream<Object?>.empty();
          },
          onMode: modes.add,
        ),
      ),
    );
    await tester.pump();

    expect(listens, 0);
    expect(modes, <SpatialTiltMode>[SpatialTiltMode.drag]);
    expect(find.text('Drag to tilt'), findsOneWidget);
  });

  testWidgets('child still gets taps', (tester) async {
    bool tapped = false;
    const Key childKey = ValueKey<String>('child');

    await tester.pumpWidget(
      _app(
        home: _view(
          tiltSource: () => const Stream<Object?>.empty(),
          child: GestureDetector(
            key: childKey,
            behavior: HitTestBehavior.opaque,
            onTap: () {
              tapped = true;
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(childKey));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
