import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/features/personalized_feed/views/widgets/home_feed_tab_bar.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../qa_render/home_render_support.dart';

class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.picked, this.onTuneTap, this.isRefreshing = false});

  final HomeFeedChip initial;
  final List<HomeFeedChip> picked;
  final VoidCallback? onTuneTap;
  final bool isRefreshing;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController controller = TabController(
    length: HomeFeedChip.values.length,
    vsync: this,
    initialIndex: widget.initial.index,
  );
  late HomeFeedChip selected = widget.initial;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: HomeFeedTabBar(
        controller: controller,
        selected: selected,
        onSelected: (chip) {
          widget.picked.add(chip);
          setState(() => selected = chip);
        },
        onTuneTap: widget.onTuneTap,
        isRefreshing: widget.isRefreshing,
      ),
    );
  }
}

int _pixelInk(ByteData pixels, int width, int x, int y) {
  final int at = (y * width + x) * 4;
  final int background = (2 * width + x) * 4;
  int ink = 0;
  for (int channel = 0; channel < 3; channel++) {
    ink += (pixels.getUint8(at + channel) - pixels.getUint8(background + channel)).abs();
  }
  return ink;
}

void main() {
  final PrismThemeOption rose = prismLightThemes.firstWhere((PrismThemeOption option) => option.label == 'Rose');
  final ThemeData theme = withPrismAccent(rose.theme, rose.defaultAccentValue);
  final ColorScheme cs = theme.colorScheme;

  Future<List<HomeFeedChip>> pumpBar(
    WidgetTester tester, {
    HomeFeedChip initial = HomeFeedChip.forYou,
    VoidCallback? onTuneTap,
    bool isRefreshing = false,
    GlobalKey? boundary,
  }) async {
    final List<HomeFeedChip> picked = <HomeFeedChip>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: RepaintBoundary(
          key: boundary,
          child: Align(
            alignment: Alignment.topCenter,
            child: _Host(initial: initial, picked: picked, onTuneTap: onTuneTap, isRefreshing: isRefreshing),
          ),
        ),
      ),
    );
    return picked;
  }

  void setWidth(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<ByteData> capture(WidgetTester tester, double width) async {
    setWidth(tester, width);
    final GlobalKey boundary = GlobalKey();
    await pumpBar(tester, onTuneTap: () {}, boundary: boundary);
    await tester.pump();
    await tester.pump();
    final ByteData? pixels = await tester.runAsync(() async {
      final RenderRepaintBoundary render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await render.toImage();
      return (await image.toByteData())!;
    });
    return pixels!;
  }

  /// How far the pixel is from the bar background, summed over the colour channels, for the rows the labels use.
  double inkIn(ByteData pixels, double width, int fromColumn, int toColumn) {
    int ink = 0;
    for (int y = 8; y < 34; y++) {
      for (int x = fromColumn; x < toColumn; x++) {
        ink += _pixelInk(pixels, width.toInt(), x, y);
      }
    }
    return ink.toDouble();
  }

  /// The darkest single pixel in the columns: a pixel in the middle of a letter stem, if the label is not faded.
  double strongestInk(ByteData pixels, double width, int fromColumn, int toColumn) {
    int strongest = 0;
    for (int y = 8; y < 34; y++) {
      for (int x = fromColumn; x < toColumn; x++) {
        strongest = math.max(strongest, _pixelInk(pixels, width.toInt(), x, y));
      }
    }
    return strongest.toDouble();
  }

  List<String> recordHaptics(WidgetTester tester) {
    const MethodChannel channel = MethodChannel('prism/haptics');
    final bool wasEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    final List<String> events = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'play') events.add(call.arguments! as String);
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      PrismHaptics.enabled = wasEnabled;
    });
    return events;
  }

  Finder tab(String label) => find.widgetWithText(Tab, label);

  Color inkOf(WidgetTester tester, String label) => tester
      .widget<RichText>(find.descendant(of: tab(label), matching: find.byType(RichText)).first)
      .text
      .style!
      .color!;

  testWidgets('the tabs run For you, Following, Trending, Latest, Popular from the left', (tester) async {
    await pumpBar(tester);

    expect(find.byType(Tab), findsNWidgets(5));
    final List<double> lefts = <String>[
      'For you',
      'Following',
      'Trending',
      'Latest',
      'Popular',
    ].map((label) => tester.getTopLeft(find.text(label)).dx).toList();
    expect(lefts, <double>[...lefts]..sort());
    expect(lefts.toSet(), hasLength(5));
  });

  testWidgets('the bar is 44 high and the first label starts 14 px from the edge, under the profile picture', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(tester.getSize(find.byType(HomeFeedTabBar)).height, 44);
    expect(tester.getTopLeft(find.text('For you')).dx, 14);
  });

  testWidgets('every label is 15 pt bold, the chosen one in the text colour and the others in 55% ink', (tester) async {
    await pumpBar(tester, initial: HomeFeedChip.latest);

    for (final String label in <String>['For you', 'Following', 'Trending', 'Latest', 'Popular']) {
      final TextStyle style = tester
          .widget<RichText>(find.descendant(of: tab(label), matching: find.byType(RichText)).first)
          .text
          .style!;
      expect(style.fontSize, 15, reason: label);
      expect(style.fontWeight, FontWeight.w700, reason: label);
    }
    expect(inkOf(tester, 'Latest'), cs.onSurface);
    for (final String label in <String>['For you', 'Following', 'Trending', 'Popular']) {
      expect(inkOf(tester, label), cs.onSurface.withValues(alpha: 0.55), reason: label);
    }
  });

  testWidgets('the underline is a 4 px accent bar as wide as the chosen label, over a hairline at 10% ink', (
    tester,
  ) async {
    await pumpBar(tester, initial: HomeFeedChip.latest);

    final Finder indicator = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_IndicatorPainter',
    );
    final double labelWidth = tester.getSize(find.text('Latest')).width;
    expect(
      tester.renderObject<RenderBox>(indicator),
      paints..something(
        (Symbol method, List<Object?> arguments) =>
            method == #drawRRect &&
            (arguments[0]! as RRect).height == 4 &&
            ((arguments[0]! as RRect).width - labelWidth).abs() < 0.01 &&
            (arguments[1]! as Paint).color.toARGB32() == cs.primary.toARGB32(),
      ),
    );
    final Finder hairline = find.byWidgetPredicate(
      (widget) => widget is ColoredBox && widget.color == cs.onSurface.withValues(alpha: 0.1),
    );
    expect(tester.getRect(hairline), const Rect.fromLTWH(0, 43, 800, 1));
  });

  testWidgets('tapping another tab selects it, moves the underline and plays the selection haptic', (tester) async {
    final List<String> haptics = recordHaptics(tester);
    final List<HomeFeedChip> picked = await pumpBar(tester, onTuneTap: () {});

    await tester.tap(tab('Latest'));
    await tester.pumpAndSettle();

    expect(picked, <HomeFeedChip>[HomeFeedChip.latest]);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 3);
    expect(haptics, <String>['selection']);
  });

  testWidgets('tapping For you while it is chosen opens the feed settings once and nothing else', (tester) async {
    final List<String> haptics = recordHaptics(tester);
    int tuned = 0;
    final List<HomeFeedChip> picked = await pumpBar(tester, onTuneTap: () => tuned++);

    await tester.tap(tab('For you'));
    await tester.pump();

    expect(tuned, 1);
    expect(picked, isEmpty);
    expect(haptics, <String>['tap']);
  });

  testWidgets('tapping For you while another tab is chosen selects For you and does not open the feed settings', (
    tester,
  ) async {
    int tuned = 0;
    final List<HomeFeedChip> picked = await pumpBar(tester, initial: HomeFeedChip.popular, onTuneTap: () => tuned++);

    await tester.tap(tab('For you'));
    await tester.pumpAndSettle();

    expect(picked, <HomeFeedChip>[HomeFeedChip.forYou]);
    expect(tuned, 0);
  });

  testWidgets('tapping a tab other than For you never opens the feed settings', (tester) async {
    int tuned = 0;
    await pumpBar(tester, initial: HomeFeedChip.following, onTuneTap: () => tuned++);

    await tester.tap(tab('Following'));
    await tester.pump();

    expect(tuned, 0);
  });

  testWidgets('For you shows a 60% ink caret while the feed settings can open, and none without them', (tester) async {
    await pumpBar(tester, onTuneTap: () {});

    final Icon caret = tester.widget<Icon>(find.descendant(of: tab('For you'), matching: find.byType(Icon)));
    expect(caret.icon, PrismIcons.dropdownCaret);
    expect(caret.size, 18);
    expect(caret.color, cs.onSurface.withValues(alpha: 0.6));
    expect(find.byIcon(PrismIcons.dropdownCaret), findsOneWidget);

    await pumpBar(tester);
    await tester.pump();

    expect(find.byIcon(PrismIcons.dropdownCaret), findsNothing);
  });

  testWidgets('without a feed settings action, a tap on the chosen For you tab does nothing', (tester) async {
    final List<String> haptics = recordHaptics(tester);
    final List<HomeFeedChip> picked = await pumpBar(tester);

    await tester.tap(tab('For you'));
    await tester.pump();

    expect(picked, isEmpty);
    expect(haptics, isEmpty);
  });

  testWidgets('a screen reader hears the feed settings hint on For you only while it is chosen', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpBar(tester, onTuneTap: () {});

    expect(tester.getSemantics(tab('For you')).hint, 'Double tap to open feed settings');
    expect(tester.getSemantics(tab('Latest')).hint, isEmpty);

    await tester.tap(tab('Latest'));
    await tester.pumpAndSettle();

    expect(tester.getSemantics(tab('For you')).hint, isEmpty);
    handle.dispose();
  });

  testWidgets('a thin Updating bar shows over the hairline only while cached walls refresh', (tester) async {
    await pumpBar(tester, isRefreshing: true);

    expect(find.bySemanticsLabel('Updating'), findsOneWidget);
    expect(tester.getSize(find.byType(LinearProgressIndicator)).height, 2);
    expect(tester.getBottomLeft(find.byType(LinearProgressIndicator)).dy, 44);

    await pumpBar(tester);
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a narrow screen fades the right edge of the tabs while more wait there, and the hairline stays', (
    tester,
  ) async {
    await pumpBar(tester);
    final Rect popular = tester.getRect(find.text('Popular'));
    final int width = ((popular.left + popular.right) / 2).round();
    final ByteData wide = await capture(tester, 800);
    final ByteData narrow = await capture(tester, width.toDouble());

    ByteData cropColumns(ByteData source, int sourceWidth, int from, int to) => ByteData.sublistView(
      Uint8List.fromList(<int>[
        for (int y = 8; y < 34; y++)
          for (int x = from; x < to; x++)
            for (int c = 0; c < 4; c++) source.getUint8((y * sourceWidth + x) * 4 + c),
      ]),
    );

    final double unfaded = inkIn(wide, 800, width - 3, width);
    final double faded = inkIn(narrow, width.toDouble(), width - 3, width);
    expect(unfaded, greaterThan(0), reason: 'the label runs under the screen edge');
    expect(faded, lessThan(unfaded * 0.25));
    final ByteData wideBeforeFade = cropColumns(wide, 800, width - 60, width - 30);
    final ByteData narrowBeforeFade = cropColumns(narrow, width, width - 60, width - 30);
    expect(narrowBeforeFade.buffer.asUint8List(), wideBeforeFade.buffer.asUint8List());
    final int hairline = (43 * width + width - 1) * 4;
    expect(narrow.getUint8(hairline), isNot(narrow.getUint8((20 * width + 2) * 4)), reason: 'the hairline is drawn');
  });

  testWidgets('the fade goes once the tabs are scrolled to the end', (tester) async {
    setWidth(tester, 300);
    final GlobalKey boundary = GlobalKey();
    await pumpBar(tester, onTuneTap: () {}, boundary: boundary);
    await tester.pump();
    await tester.pump();

    await tester.drag(find.byType(TabBar), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(tester.getTopRight(find.text('Popular')).dx, 300 - 8);
    final ByteData pixels = (await tester.runAsync(() async {
      final RenderRepaintBoundary render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await (await render.toImage()).toByteData())!;
    }))!;
    final Rect reference = <String>[
      'Following',
      'Trending',
      'Latest',
    ].map((label) => tester.getRect(find.text(label))).firstWhere((rect) => rect.left >= 0 && rect.right <= 276);
    expect(
      strongestInk(pixels, 300, 287, 292),
      greaterThan(strongestInk(pixels, 300, reference.left.ceil(), reference.right.floor()) * 0.7),
      reason: 'the end of the last label is as dark as another label that is not chosen',
    );
  });

  testWidgets('at 2x text the labels grow to 1.5x only and the bar stays 44 high', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpBar(tester, onTuneTap: () {});

    final RichText label = tester.widget<RichText>(find.descendant(of: tab('Latest'), matching: find.byType(RichText)));

    expect(label.textScaler.scale(15), 22.5);
    expect(tester.getSize(find.byType(HomeFeedTabBar)).height, 44);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the app font, all five tabs fit a 390 pt screen and the last one is whole', (tester) async {
    await tester.runAsync(loadAppFonts);
    setWidth(tester, 390);
    await pumpBar(tester, onTuneTap: () {});
    await tester.pump();
    await tester.pump();

    expect(tester.getTopLeft(find.text('For you')).dx, 14);
    expect(tester.getTopRight(find.text('Popular')).dx, lessThanOrEqualTo(390 - 8));
    final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, 0, reason: 'nothing waits off screen, so nothing fades');
  });
}
