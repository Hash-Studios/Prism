import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/views/widgets/spatial_tilt_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Widget _app({required Widget home, bool reduceMotion = false, ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
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
  ImageProvider? image,
  ImageProvider? mapProvider,
}) {
  return SpatialTiltView(
    image: image ?? MemoryImage(_png),
    mapUrl: 'https://x/m.png',
    mapProvider: mapProvider ?? MemoryImage(_png),
    tiltSource: tiltSource,
    onMode: onMode,
    child: child,
  );
}

void main() {
  testWidgets('cancels the sensor stream on dispose', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(cancels, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(listens, 2);
  });

  testWidgets('does not start the sensor when opened before the app resumes', (tester) async {
    int listens = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    await tester.pumpWidget(
      _app(
        home: _view(
          tiltSource: () {
            listens++;
            return const Stream<Object?>.empty();
          },
        ),
      ),
    );
    await tester.pump();
    expect(listens, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(listens, 1);
  });

  testWidgets('falls back to drag when the sensor stream errors', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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

  testWidgets('does not restart a failed sensor after background and resume', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    int listens = 0;
    await tester.pumpWidget(
      _app(
        home: _view(
          tiltSource: () {
            listens++;
            return Stream<Object?>.error(PlatformException(code: 'NO_SENSOR'));
          },
        ),
      ),
    );
    await tester.pump();
    expect(listens, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(listens, 1);
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

  testWidgets('stops and resumes the sensor when reduce motion changes while open', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    int listens = 0;
    int cancels = 0;
    Stream<Object?> tiltSource() {
      listens++;
      return StreamController<Object?>(onCancel: () => cancels++).stream;
    }

    await tester.pumpWidget(_app(home: _view(tiltSource: tiltSource)));
    await tester.pump();
    expect(listens, 1);

    await tester.pumpWidget(_app(reduceMotion: true, home: _view(tiltSource: tiltSource)));
    await tester.pump();
    expect(cancels, 1);

    await tester.pumpWidget(_app(home: _view(tiltSource: tiltSource)));
    await tester.pump();
    expect(listens, 2);
  });

  testWidgets('does not resume sensor mode while reduce motion is enabled', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    int listens = 0;
    Stream<Object?> tiltSource() {
      listens++;
      return const Stream<Object?>.empty();
    }

    await tester.pumpWidget(_app(reduceMotion: true, home: _view(tiltSource: tiltSource)));
    await tester.pump();
    expect(listens, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(listens, 0);

    await tester.pumpWidget(_app(home: _view(tiltSource: tiltSource)));
    await tester.pump();
    expect(listens, 1);
  });

  testWidgets('replaces its sensor subscription when the source changes', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    int oldCancels = 0;
    int newListens = 0;
    final StreamController<Object?> oldController = StreamController<Object?>(onCancel: () => oldCancels++);
    Stream<Object?> newSource() {
      newListens++;
      return const Stream<Object?>.empty();
    }

    await tester.pumpWidget(_app(home: _view(tiltSource: () => oldController.stream)));
    await tester.pump();
    await tester.pumpWidget(_app(home: _view(tiltSource: newSource)));
    await tester.pump();

    expect(oldCancels, 1);
    expect(newListens, 1);
  });

  testWidgets('resolves new image and map providers when their sources change', (tester) async {
    final _PendingImageProvider oldImage = _PendingImageProvider();
    final _PendingImageProvider oldMap = _PendingImageProvider();
    final _PendingImageProvider newImage = _PendingImageProvider();
    final _PendingImageProvider newMap = _PendingImageProvider();

    await tester.pumpWidget(
      _app(
        home: _view(tiltSource: () => const Stream<Object?>.empty(), image: oldImage, mapProvider: oldMap),
      ),
    );
    await tester.pump();
    expect(oldImage.loads, greaterThan(0));
    expect(oldMap.loads, 1);

    await tester.pumpWidget(
      _app(
        home: _view(tiltSource: () => const Stream<Object?>.empty(), image: newImage, mapProvider: newMap),
      ),
    );
    await tester.pump();

    expect(newImage.loads, 2);
    expect(newMap.loads, 1);
  });

  testWidgets('disposes replaced and final map image clones', (tester) async {
    final _ControllableImageProvider firstMap = _ControllableImageProvider();
    final _ControllableImageProvider secondMap = _ControllableImageProvider();
    final ui.Image firstFrame = (await tester.runAsync(() => createTestImage(width: 5, height: 5, cache: false)))!;
    final ui.Image secondFrame = (await tester.runAsync(() => createTestImage(width: 7, height: 7, cache: false)))!;
    addTearDown(firstFrame.dispose);
    addTearDown(secondFrame.dispose);

    await tester.pumpWidget(
      _app(
        home: _view(tiltSource: () => const Stream<Object?>.empty(), mapProvider: firstMap),
      ),
    );
    expect(firstMap.completer.listenerCount, greaterThan(0));

    firstMap.completer.emit(firstFrame);
    await tester.pump();
    expect(_spatialTiltViewHandles(firstFrame), hasLength(1));

    firstMap.completer.emit(secondFrame);
    await tester.pump();
    expect(_spatialTiltViewHandles(firstFrame), isEmpty);
    expect(_spatialTiltViewHandles(secondFrame), hasLength(1));

    await tester.pumpWidget(
      _app(
        home: _view(tiltSource: () => const Stream<Object?>.empty(), mapProvider: secondMap),
      ),
    );
    expect(firstMap.completer.listenerCount, 0);
    expect(secondMap.completer.listenerCount, greaterThan(0));
    expect(_spatialTiltViewHandles(firstFrame), isEmpty);
    expect(_spatialTiltViewHandles(secondFrame), isEmpty);

    secondMap.completer.emit(secondFrame);
    await tester.pump();
    expect(_spatialTiltViewHandles(secondFrame), hasLength(1));

    await tester.pumpWidget(_app(home: const SizedBox()));
    expect(secondMap.completer.listenerCount, 0);
    expect(_spatialTiltViewHandles(secondFrame), isEmpty);
  });

  testWidgets('ignores pending image frames after dispose', (tester) async {
    final _PendingImageProvider image = _PendingImageProvider();
    final _PendingImageProvider map = _PendingImageProvider();
    await tester.pumpWidget(
      _app(
        home: _view(tiltSource: () => const Stream<Object?>.empty(), image: image, mapProvider: map),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(_app(home: const SizedBox()));

    final ui.Image decoded = (await tester.runAsync(() => createTestImage(width: 4, height: 4)))!;
    image.complete(ImageInfo(image: decoded.clone()));
    map.complete(ImageInfo(image: decoded.clone()));
    await tester.pump();
    decoded.dispose();

    expect(tester.takeException(), isNull);
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

  testWidgets('drag hint uses inverse surface theme roles', (tester) async {
    const Color background = Color(0xFF123456);
    const Color foreground = Color(0xFFABCDEF);
    final ThemeData theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.pink,
      ).copyWith(inverseSurface: background, onInverseSurface: foreground),
    );
    await tester.pumpWidget(
      _app(
        theme: theme,
        reduceMotion: true,
        home: _view(tiltSource: () => const Stream<Object?>.empty()),
      ),
    );

    final Finder hint = find.ancestor(of: find.text('Drag to tilt'), matching: find.byType(DecoratedBox));
    final DecoratedBox decoration = tester.widget<DecoratedBox>(hint.first);
    final Text label = tester.widget<Text>(find.text('Drag to tilt'));
    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.swipe_rounded));

    expect((decoration.decoration as BoxDecoration).color, background);
    expect(label.style?.color, foreground);
    expect(icon.color, foreground);
  });
}

class _PendingImageProvider extends ImageProvider<int> {
  final Completer<ImageInfo> _image = Completer<ImageInfo>();
  int loads = 0;

  @override
  Future<int> obtainKey(ImageConfiguration configuration) async => identityHashCode(this);

  @override
  ImageStreamCompleter loadImage(int key, ImageDecoderCallback decode) {
    loads++;
    return OneFrameImageStreamCompleter(_image.future);
  }

  void complete(ImageInfo image) => _image.complete(image);
}

List<StackTrace> _spatialTiltViewHandles(ui.Image image) => image
    .debugGetOpenHandleStackTraces()!
    .where((StackTrace trace) => trace.toString().contains('spatial_tilt_view.dart'))
    .toList();

class _ControllableImageProvider extends ImageProvider<int> {
  final _ControllableImageStreamCompleter completer = _ControllableImageStreamCompleter();

  @override
  Future<int> obtainKey(ImageConfiguration configuration) async => identityHashCode(this);

  @override
  ImageStreamCompleter loadImage(int key, ImageDecoderCallback decode) => completer;
}

class _ControllableImageStreamCompleter extends ImageStreamCompleter {
  int _listenerCount = 0;

  int get listenerCount => _listenerCount;

  @override
  void addListener(ImageStreamListener listener) {
    _listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(ImageStreamListener listener) {
    super.removeListener(listener);
    _listenerCount--;
  }

  void emit(ui.Image image) => setImage(ImageInfo(image: image.clone()));
}
