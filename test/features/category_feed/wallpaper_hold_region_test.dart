import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/gesture_hint.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_hold_region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  Future<void> pumpRegion(
    WidgetTester tester,
    List<WallpaperQuickAction> actions, {
    Alignment alignment = Alignment.center,
    bool reduceMotion = false,
    VoidCallback? onTap,
    bool showLess = true,
    bool resetOriginal = false,
    bool saveToFolder = false,
    bool? isPinned,
    Object identity = 'wall',
    Size tileSize = const Size(160, 200),
    double textScale = 1,
    String? dayNightLabel,
    Brightness brightness = Brightness.light,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize,
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(
            alignment: alignment,
            child: SizedBox(
              width: tileSize.width,
              height: tileSize.height,
              child: WallpaperHoldRegion(
                identity: identity,
                favouriteLabel: 'Favourite',
                shareLabel: 'Share',
                showLessLabel: showLess ? 'See less' : null,
                resetOriginalLabel: resetOriginal ? 'Reset to original variation' : null,
                saveToFolderLabel: saveToFolder ? 'Save to folder' : null,
                pinLabel: isPinned == null ? null : 'Pin to top',
                unpinLabel: 'Unpin',
                readIsPinned: isPinned == null ? null : () => isPinned,
                dayNightLabel: dayNightLabel,
                onAction: actions.add,
                preview: const ColoredBox(key: ValueKey('preview'), color: Colors.blue),
                child: GestureDetector(
                  onTap: onTap,
                  child: const ColoredBox(key: ValueKey('source'), color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<TestGesture> hold(WidgetTester tester, {bool settle = true}) async {
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('source'))));
    await tester.pump(const Duration(milliseconds: 600));
    if (settle) await tester.pump(const Duration(milliseconds: 180));
    return gesture;
  }

  testWidgets('nested Navigator dims the outer app and drag uses root coordinates', (tester) async {
    final actions = <WallpaperQuickAction>[];
    final semantics = tester.ensureSemantics();
    bool outerSemanticsVisible() =>
        tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!.toStringDeep().contains('Outer app');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 70, top: 50),
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => Center(
                        child: SizedBox(
                          width: 160,
                          height: 200,
                          child: WallpaperHoldRegion(
                            identity: 'nested',
                            favouriteLabel: 'Favourite',
                            shareLabel: 'Share',
                            onAction: actions.add,
                            preview: const ColoredBox(color: Colors.blue),
                            child: const ColoredBox(key: ValueKey('source'), color: Colors.blue),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(label: 'Outer app', child: const SizedBox(height: 100, width: 100)),
            ],
          ),
        ),
      ),
    );
    expect(outerSemanticsVisible(), isTrue);
    final gesture = await hold(tester);
    final barrier = find.byKey(const ValueKey<String>('wallpaper-hold-scrim'));
    expect(tester.getRect(barrier), const Rect.fromLTWH(0, 0, 800, 600));
    expect(outerSemanticsVisible(), isFalse);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Share')));
    await tester.pump();
    expect(find.text('Share'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(actions, [WallpaperQuickAction.share]);
    expect(outerSemanticsVisible(), isTrue);
    semantics.dispose();
  });

  testWidgets('opening the hold menu marks the hold hint as seen', (tester) async {
    GestureHints.resetForTest();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    addTearDown(() async {
      GestureHints.resetForTest();
      await getIt.unregister<SettingsLocalDataSource>();
    });
    expect(GestureHints.seen(GestureHint.holdToSave).value, isFalse);
    await pumpRegion(tester, []);
    final gesture = await hold(tester);
    expect(GestureHints.seen(GestureHint.holdToSave).value, isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} theme ${brightness == Brightness.light ? 'washes toward the page' : 'keeps a dark scrim'}',
      (tester) async {
        await pumpRegion(tester, [], brightness: brightness);
        final gesture = await hold(tester);
        final ColorScheme cs = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
        final Color scrim = tester.widget<ColoredBox>(find.byKey(const ValueKey<String>('wallpaper-hold-scrim'))).color;
        final Color expected = brightness == Brightness.light ? cs.surface : cs.scrim;
        expect(scrim.withValues(alpha: 1), expected.withValues(alpha: 1));
        expect(scrim.a, brightness == Brightness.light ? closeTo(0.82, 0.01) : closeTo(0.72, 0.01));
        await gesture.up();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('the lifted tile casts a soft shadow and the hovered label sits large above the ring', (tester) async {
    await pumpRegion(tester, []);
    final gesture = await hold(tester);
    final DecoratedBox lift = tester.widget(find.byKey(const ValueKey<String>('wallpaper-hold-lift-shadow')));
    expect((lift.decoration as BoxDecoration).boxShadow!.single.color.a, greaterThan(0.1));

    final double ringTop = <String>[
      'Favourite',
      'Share',
      'See less',
    ].map((label) => tester.getRect(find.bySemanticsLabel(label)).top).reduce((a, b) => a < b ? a : b);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Share')));
    await tester.pump();
    final Rect label = tester.getRect(find.byKey(const ValueKey<String>('wallpaper-hold-label')));
    expect(label.bottom, lessThanOrEqualTo(ringTop));
    final Text text = tester.widget(find.text('Share'));
    expect(text.style!.fontSize, greaterThanOrEqualTo(20));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('painted carousel corners, separate targets and large label fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final portrait = size.height > size.width;
      tester.view.padding = portrait
          ? const FakeViewPadding(top: 44, bottom: 34)
          : const FakeViewPadding(left: 44, right: 34);
      addTearDown(tester.view.reset);
      await pumpRegion(tester, [], tileSize: size, textScale: 3);
      final gesture = await hold(tester, settle: false);
      final preview = tester.renderObject<RenderBox>(find.byKey(const ValueKey('preview')));
      final safe = Rect.fromLTRB(
        portrait ? 12 : 56,
        portrait ? 56 : 12,
        size.width - (portrait ? 12 : 46),
        size.height - (portrait ? 46 : 12),
      ).inflate(0.001);
      for (var frame = 0; frame < 6; frame++) {
        for (final corner in [
          Offset.zero,
          Offset(preview.size.width, 0),
          Offset(0, preview.size.height),
          preview.size.bottomRight(Offset.zero),
        ]) {
          expect(safe.contains(preview.localToGlobal(corner)), isTrue);
        }
        await tester.pump(const Duration(milliseconds: 40));
      }
      final targets = [
        'Favourite',
        'Share',
        'See less',
      ].map((label) => tester.getRect(find.bySemanticsLabel(label))).toList();
      for (var i = 0; i < targets.length; i++) {
        expect(safe.contains(targets[i].topLeft), isTrue);
        expect(safe.contains(targets[i].bottomRight), isTrue);
        for (var j = i + 1; j < targets.length; j++) {
          expect((targets[i].center - targets[j].center).distance, greaterThanOrEqualTo(48));
        }
      }
      await gesture.moveTo(targets.first.center);
      await tester.pump();
      final label = tester.getRect(find.text('Favourite'));
      expect(safe.contains(label.topLeft), isTrue);
      expect(safe.contains(label.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
      await gesture.up();
      await tester.pump();
    });
  }

  for (final inside in [true, false]) {
    testWidgets('second pointer ${inside ? 'inside' : 'outside'} source cancels the hold', (tester) async {
      final actions = <WallpaperQuickAction>[];
      await pumpRegion(tester, actions);
      final gesture = await hold(tester);
      await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Favourite')));
      final second = await tester.startGesture(
        inside ? tester.getCenter(find.byKey(const ValueKey('source'))) : const Offset(10, 10),
        pointer: 2,
      );
      await tester.pump();
      await second.up();
      await gesture.up();
      await tester.pump();
      expect(actions, isEmpty);
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    });
  }

  testWidgets('activation impacts and only a new nonnull hover plays selection', (tester) async {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('prism/haptics'), (call) async {
      calls.add(call.arguments);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('prism/haptics'), null),
    );
    await pumpRegion(tester, []);
    final gesture = await hold(tester);
    expect(calls, ['impact']);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Favourite')));
    await tester.pump();
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();
    await gesture.moveTo(const Offset(10, 10));
    await tester.pump();
    expect(calls, ['impact', 'selection']);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Share')));
    await tester.pump();
    expect(calls, ['impact', 'selection', 'selection']);
    await gesture.up();
    await tester.pump();
  });

  for (final entry in <String, WallpaperQuickAction>{
    'Favourite': WallpaperQuickAction.favourite,
    'Share': WallpaperQuickAction.share,
    'See less': WallpaperQuickAction.showLess,
    'Reset to original variation': WallpaperQuickAction.resetOriginal,
  }.entries) {
    testWidgets('hold drag highlights ${entry.key}, release commits once after close', (tester) async {
      final actions = <WallpaperQuickAction>[];
      await pumpRegion(tester, actions, resetOriginal: entry.value == WallpaperQuickAction.resetOriginal);
      final gesture = await hold(tester);
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: find.byKey(const ValueKey('source')), matching: find.byType(Opacity)).first,
            )
            .opacity,
        0,
      );
      await gesture.moveTo(tester.getCenter(find.bySemanticsLabel(entry.key)));
      await tester.pump();
      expect(find.text(entry.key), findsOneWidget);
      expect(actions, isEmpty);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump();
      expect(actions, <WallpaperQuickAction>[entry.value]);
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    });
  }

  testWidgets('day and night is the last hold action when labelled', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(
      tester,
      actions,
      showLess: false,
      resetOriginal: true,
      saveToFolder: true,
      isPinned: false,
      dayNightLabel: 'Day and night',
    );
    final gesture = await hold(tester);
    final Finder dayNight = find.bySemanticsLabel('Day and night');
    expect(dayNight, findsOneWidget);
    expect(find.byIcon(Icons.contrast_rounded), findsOneWidget);
    await gesture.moveTo(tester.getCenter(dayNight));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(actions, <WallpaperQuickAction>[WallpaperQuickAction.dayNight]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('day and night is absent from the hold ring without a label', (tester) async {
    await pumpRegion(
      tester,
      <WallpaperQuickAction>[],
      showLess: false,
      resetOriginal: true,
      saveToFolder: true,
      isPinned: false,
    );
    await hold(tester);
    expect(find.bySemanticsLabel('Day and night'), findsNothing);
    expect(find.byIcon(Icons.contrast_rounded), findsNothing);
  });

  testWidgets('pin is a reachable sixth hold action', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions, resetOriginal: true, saveToFolder: true, isPinned: false);
    final gesture = await hold(tester);
    final Finder pin = find.bySemanticsLabel('Pin to top');
    expect(pin, findsOneWidget);
    await gesture.moveTo(tester.getCenter(pin));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(actions, <WallpaperQuickAction>[WallpaperQuickAction.pin]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('release outside and pointer cancellation never dispatch', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    var gesture = await hold(tester);
    await gesture.moveTo(const Offset(20, 20));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(actions, isEmpty);
    gesture = await hold(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Favourite')));
    await gesture.cancel();
    await tester.pump();
    expect(actions, isEmpty);
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
  });

  testWidgets('release outside reverses the lift before removing the overlay', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    final gesture = await hold(tester);
    await gesture.moveTo(const Offset(10, 10));
    await gesture.up();
    await tester.pump();
    final scrim = find.byKey(const ValueKey<String>('wallpaper-hold-scrim'));
    final double openedAlpha = tester.widget<ColoredBox>(scrim).color.a;
    await tester.pump(const Duration(milliseconds: 60));
    final double exitingAlpha = tester.widget<ColoredBox>(scrim).color.a;
    expect(exitingAlpha, lessThan(openedAlpha));
    expect(exitingAlpha, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('wallpaper-hold-scrim')), findsNothing);
    expect(actions, isEmpty);
  });

  testWidgets('release in the same frame as the hold timeout cleans up an initially exiting overlay', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    final Offset position = tester.getCenter(find.byKey(const ValueKey('source')));
    await tester.startGesture(position, pointer: 499);
    var released = false;
    Timer(const Duration(milliseconds: 501), () {
      GestureBinding.instance.handlePointerEvent(
        PointerUpEvent(pointer: 499, position: position, timeStamp: const Duration(milliseconds: 501)),
      );
      released = true;
    });

    // The long-press timer inserts the overlay at 500 ms; release at 501 ms, before that frame builds it.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 180));

    expect(released, isTrue);
    expect(find.byKey(const ValueKey<String>('wallpaper-hold-scrim')), findsNothing);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: find.byKey(const ValueKey('source')), matching: find.byType(Opacity)).first,
          )
          .opacity,
      1,
    );
    expect(actions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('release during entrance reverses continuously from the sampled visual state', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    final gesture = await hold(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 80));

    final scrim = find.byKey(const ValueKey<String>('wallpaper-hold-scrim'));
    final double scrimBefore = tester.widget<ColoredBox>(scrim).color.a;
    final transformsBefore = tester
        .widgetList<Transform>(
          find.ancestor(of: find.byKey(const ValueKey('preview')), matching: find.byType(Transform)),
        )
        .map((transform) => transform.transform)
        .toList();
    final double actionOpacityBefore = tester
        .widget<Opacity>(find.ancestor(of: find.bySemanticsLabel('Favourite'), matching: find.byType(Opacity)).first)
        .opacity;

    await gesture.moveTo(const Offset(10, 10));
    await gesture.up();
    await tester.pump();

    expect(tester.widget<ColoredBox>(scrim).color.a, closeTo(scrimBefore, 0.01));
    final transformsAfter = tester
        .widgetList<Transform>(
          find.ancestor(of: find.byKey(const ValueKey('preview')), matching: find.byType(Transform)),
        )
        .map((transform) => transform.transform)
        .toList();
    expect(transformsAfter, hasLength(transformsBefore.length));
    for (var index = 0; index < transformsBefore.length; index++) {
      expect(transformsAfter[index].entry(0, 0), closeTo(transformsBefore[index].entry(0, 0), 0.001));
      expect(transformsAfter[index].entry(0, 1), closeTo(transformsBefore[index].entry(0, 1), 0.001));
      expect(transformsAfter[index].entry(1, 3), closeTo(transformsBefore[index].entry(1, 3), 0.1));
    }
    final double actionOpacityAfter = tester
        .widget<Opacity>(find.ancestor(of: find.bySemanticsLabel('Favourite'), matching: find.byType(Opacity)).first)
        .opacity;
    expect(actionOpacityAfter, closeTo(actionOpacityBefore, 0.01));

    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('wallpaper-hold-scrim')), findsNothing);
    expect(actions, isEmpty);
  });

  testWidgets('forced lifecycle cleanup interrupts an animated dismissal', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    final gesture = await hold(tester);
    await gesture.moveTo(const Offset(10, 10));
    await gesture.up();
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('wallpaper-hold-scrim')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('wallpaper-hold-scrim')), findsNothing);
    expect(actions, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('forced cleanup before the closing frame suppresses queued action dispatch', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    final gesture = await hold(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Share')));
    await gesture.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(actions, isEmpty);
    expect(find.byKey(const ValueKey<String>('wallpaper-hold-scrim')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('reduced-motion action dispatches once even though its overlay closes immediately', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions, reduceMotion: true);
    final gesture = await hold(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Share')));
    await gesture.up();
    await tester.pump();
    expect(actions, <WallpaperQuickAction>[WallpaperQuickAction.share]);
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
  });

  testWidgets('lifecycle cancellation suppresses reduced-motion action after overlay removal', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions, reduceMotion: true);
    final gesture = await hold(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Share')));
    await gesture.up();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(actions, isEmpty);
    expect(find.byKey(const ValueKey<String>('wallpaper-hold-scrim')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('ordinary tap and pre-hold drag stay with child and scroll', (tester) async {
    final actions = <WallpaperQuickAction>[];
    var taps = 0;
    await pumpRegion(tester, actions, onTap: () => taps++);
    await tester.tap(find.byKey(const ValueKey('source')));
    await tester.pump();
    expect(taps, 1);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('source'))));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    expect(actions, isEmpty);
  });

  for (final alignment in <Alignment>[
    Alignment.topLeft,
    Alignment.topRight,
    Alignment.bottomLeft,
    Alignment.bottomRight,
  ]) {
    testWidgets('targets fit at $alignment and circular hit tests reject corners', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final actions = <WallpaperQuickAction>[];
      await pumpRegion(tester, actions, alignment: alignment, resetOriginal: true);
      final gesture = await hold(tester);
      for (final label in <String>['Favourite', 'Share', 'See less', 'Reset to original variation']) {
        final rect = tester.getRect(find.bySemanticsLabel(label));
        expect(rect.width, 48);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(480));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      final rect = tester.getRect(find.bySemanticsLabel('Favourite'));
      await gesture.moveTo(rect.topLeft + const Offset(1, 1));
      await gesture.up();
      await tester.pump();
      expect(actions, isEmpty);
    });
  }

  testWidgets('unchanged view metrics preserve the hold and drag action', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    final gesture = await hold(tester);
    tester.binding.handleMetricsChanged();
    await tester.pump();
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Share')));
    await gesture.up();
    await tester.pump();
    expect(actions, [WallpaperQuickAction.share]);
  });

  for (final metric in ['size', 'pixel ratio', 'safe area', 'keyboard inset']) {
    testWidgets('changed view $metric cancels without dispatching the hovered action', (tester) async {
      addTearDown(tester.view.reset);
      final actions = <WallpaperQuickAction>[];
      await pumpRegion(tester, actions);
      final gesture = await hold(tester);
      await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Share')));
      switch (metric) {
        case 'size':
          tester.view.physicalSize = tester.view.physicalSize + const Offset(0, 100);
        case 'pixel ratio':
          tester.view.devicePixelRatio = tester.view.devicePixelRatio + 0.5;
        case 'safe area':
          tester.view.viewPadding = const FakeViewPadding(top: 44);
        case 'keyboard inset':
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      }
      await tester.pump();
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
      await gesture.up();
      await tester.pump();
      expect(actions, isEmpty);
    });
  }

  testWidgets('back, second pointer, lifecycle and disposal cancel', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    var gesture = await hold(tester);
    await Navigator.of(tester.element(find.byType(WallpaperHoldRegion))).maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    await gesture.up();
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    gesture = await hold(tester);
    final second = await tester.startGesture(const Offset(10, 10), pointer: 2);
    await tester.pump();
    await second.up();
    await gesture.up();
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    gesture = await hold(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await gesture.up();
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    gesture = await hold(tester);
    await tester.pumpWidget(const SizedBox());
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(actions, isEmpty);
  });

  testWidgets('reduced motion has no tilt and optional action is absent', (tester) async {
    await pumpRegion(tester, <WallpaperQuickAction>[], reduceMotion: true, showLess: false);
    final gesture = await hold(tester);
    expect(find.bySemanticsLabel('See less'), findsNothing);
    final rotations = tester.widgetList<Transform>(
      find.ancestor(of: find.byKey(const ValueKey('preview')), matching: find.byType(Transform)),
    );
    expect(rotations.map((transform) => transform.transform.entry(0, 1)), everyElement(closeTo(0, 0.000001)));
    await gesture.up();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('recycling a source cancels rather than dispatching on the replacement', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    final gesture = await hold(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Favourite')));
    await pumpRegion(tester, actions, identity: 'replacement');
    await gesture.up();
    await tester.pump();
    expect(actions, isEmpty);
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
  });

  testWidgets('semantic long press leaves labelled actions open and semantic activation commits', (tester) async {
    final semantics = tester.ensureSemantics();
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    final node = tester.getSemantics(
      find.descendant(of: find.byType(WallpaperHoldRegion), matching: find.byType(Semantics)).first,
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.longPress), isTrue);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.longPress, viewId: tester.view.viewId, nodeId: node.id),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Share'), findsOneWidget);
    final action = tester.getSemantics(find.bySemanticsLabel('Share'));
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: action.id),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(actions, <WallpaperQuickAction>[WallpaperQuickAction.share]);
    expect(find.bySemanticsLabel('Share'), findsNothing);
    semantics.dispose();
  });

  for (final axis in Axis.values) {
    testWidgets('$axis scroll wins before the hold and moving the source cancels an active hold', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final actions = <WallpaperQuickAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              scrollDirection: axis,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  height: 200,
                  child: WallpaperHoldRegion(
                    identity: 'scroll',
                    favouriteLabel: 'Favourite',
                    shareLabel: 'Share',
                    onAction: actions.add,
                    preview: const ColoredBox(color: Colors.blue),
                    child: const ColoredBox(key: ValueKey('source'), color: Colors.blue),
                  ),
                ),
                const SizedBox(width: 1600, height: 1600),
              ],
            ),
          ),
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey('source')),
        axis == Axis.vertical ? const Offset(0, -120) : const Offset(-120, 0),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.offset, greaterThan(0));
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
      controller.jumpTo(0);
      await tester.pump();
      final gesture = await hold(tester);
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
      controller.jumpTo(30);
      await tester.pump();
      await gesture.up();
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
      expect(actions, isEmpty);
    });
  }
}
