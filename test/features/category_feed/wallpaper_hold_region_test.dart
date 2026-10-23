import 'package:Prism/features/category_feed/views/widgets/wallpaper_hold_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpRegion(
    WidgetTester tester,
    List<WallpaperQuickAction> actions, {
    Alignment alignment = Alignment.center,
    bool reduceMotion = false,
    VoidCallback? onTap,
    bool showLess = true,
    Object identity = 'wall',
    Size tileSize = const Size(160, 200),
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
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
    final barrier = find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color.a == 0.72);
    expect(tester.getRect(barrier), const Rect.fromLTWH(0, 0, 800, 600));
    expect(outerSemanticsVisible(), isFalse);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Share')));
    await tester.pump();
    expect(find.text('Share'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(actions, [WallpaperQuickAction.share]);
    expect(outerSemanticsVisible(), isTrue);
    semantics.dispose();
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
  }.entries) {
    testWidgets('hold drag highlights ${entry.key}, release commits once after close', (tester) async {
      final actions = <WallpaperQuickAction>[];
      await pumpRegion(tester, actions);
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
      expect(actions, <WallpaperQuickAction>[entry.value]);
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    });
  }

  testWidgets('release outside and pointer cancellation never dispatch', (tester) async {
    final actions = <WallpaperQuickAction>[];
    await pumpRegion(tester, actions);
    var gesture = await hold(tester);
    await gesture.moveTo(const Offset(20, 20));
    await gesture.up();
    await tester.pump();
    expect(actions, isEmpty);
    gesture = await hold(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Favourite')));
    await gesture.cancel();
    await tester.pump();
    expect(actions, isEmpty);
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
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
      await pumpRegion(tester, actions, alignment: alignment);
      final gesture = await hold(tester);
      for (final label in <String>['Favourite', 'Share', 'See less']) {
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
