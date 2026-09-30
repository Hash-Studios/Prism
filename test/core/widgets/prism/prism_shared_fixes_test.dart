import 'dart:math' as math;

import 'package:Prism/core/widgets/prism/prism_toast.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/views/widgets/reject_reason_sheet.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Widget _constrained(Widget child, {required double width, double scale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

Finder _toastFade(String message) => find.ancestor(of: find.text(message), matching: find.byType(FadeTransition)).first;

void main() {
  for (final double scale in <double>[1, 3]) {
    testWidgets('chip and segmented semantic hit targets are at least 44 at scale $scale in a narrow layout', (
      tester,
    ) async {
      await tester.pumpWidget(
        _constrained(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PrismChip(label: 'A long filter label', onTap: _noop),
              const SizedBox(height: 8),
              PrismSegmented<String>(
                values: const <String>['First choice', 'Second choice', 'Third choice'],
                selected: 'First choice',
                labelOf: (value) => value,
                onChanged: _noopString,
              ),
            ],
          ),
          width: 170,
          scale: scale,
        ),
      );

      final Finder targets = find.byWidgetPredicate(
        (Widget widget) => widget is Semantics && widget.properties.button == true,
      );
      expect(targets, findsNWidgets(4));
      for (final Element element in targets.evaluate()) {
        final Rect rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.height, greaterThanOrEqualTo(44));
        expect(rect.width, greaterThanOrEqualTo(44));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reject sheet actions remain reachable in landscape with keyboard inset', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 375);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: const Size(375, 375), viewInsets: const EdgeInsets.only(bottom: 216)),
          child: child!,
        ),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 375), viewInsets: EdgeInsets.only(bottom: 216)),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRejectReasonSheet(context, onSubmit: (_) async => submitted = true),
                child: const Text('Open reject sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open reject sheet'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Low quality'));
    await tester.tap(find.text('Low quality'));
    final Finder rejectButton = find.text('Reject wallpaper').last;
    await tester.ensureVisible(rejectButton);
    expect(tester.getRect(rejectButton).bottom, lessThanOrEqualTo(375 - 216));
    await tester.tap(rejectButton);
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
  });

  testWidgets('three sheet actions remain reachable at scale 2 in portrait with keyboard inset', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(375, 800),
            viewInsets: const EdgeInsets.only(bottom: 216),
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 800),
            viewInsets: EdgeInsets.only(bottom: 216),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPrismSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => PrismSheetBody(
                    title: 'Sign in to Prism',
                    message: 'Keep favourites, uploads and coins on every device.',
                    scrollable: true,
                    actions: <Widget>[
                      for (final String label in <String>['Continue with Apple', 'Continue with Google', 'Not now'])
                        PrismButton(label: label, expand: true, onPressed: () => selected = label),
                    ],
                    child: const SizedBox(height: 180, child: Text('Account details')),
                  ),
                ),
                child: const Text('Open sign in'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sign in'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final String label in <String>['Continue with Apple', 'Continue with Google', 'Not now']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
      expect(selected, label);
    }
  });

  for (final bool useDefaultController in <bool>[true, false]) {
    testWidgets('PrismPage tracks the active tab scroll (default=$useDefaultController)', (tester) async {
      final firstScrollController = ScrollController();
      addTearDown(firstScrollController.dispose);
      final TabController? controller = useDefaultController ? null : TabController(length: 2, vsync: tester);
      if (controller != null) addTearDown(controller.dispose);
      Widget page = PrismPage(
        title: 'Settings',
        showBack: false,
        headerBottom: TabBar(
          controller: controller,
          tabs: const <Widget>[
            Tab(text: 'One'),
            Tab(text: 'Two'),
          ],
        ),
        body: TabBarView(
          controller: controller,
          children: <Widget>[
            _KeptAliveList(controller: firstScrollController),
            ListView(children: const <Widget>[SizedBox(height: 400, child: Text('Other tab'))]),
          ],
        ),
      );
      if (useDefaultController) page = DefaultTabController(length: 2, child: page);
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.drag(find.text('Row 0'), const Offset(0, -160));
      await tester.pumpAndSettle();
      Finder hairline = find.byWidgetPredicate((Widget widget) => widget is AnimatedOpacity && widget.opacity == 1);
      expect(hairline, findsOneWidget);
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      hairline = find.byWidgetPredicate((Widget widget) => widget is AnimatedOpacity && widget.opacity == 0);
      expect(hairline, findsOneWidget);
      firstScrollController.jumpTo(100);
      await tester.pumpAndSettle();
      hairline = find.byWidgetPredicate((Widget widget) => widget is AnimatedOpacity && widget.opacity == 0);
      expect(hairline, findsOneWidget);
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      hairline = find.byWidgetPredicate((Widget widget) => widget is AnimatedOpacity && widget.opacity == 1);
      expect(hairline, findsOneWidget);
    });
  }

  testWidgets('short non-scrollable sheet action is reachable above the keyboard', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 375);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: const Size(375, 375), viewInsets: const EdgeInsets.only(bottom: 216)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPrismSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => PrismSheetBody(
                  title: 'Confirm change',
                  actions: <Widget>[PrismButton(label: 'Confirm', onPressed: () => confirmed = true)],
                ),
              ),
              child: const Text('Open short sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open short sheet'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm'));
    expect(tester.getRect(find.text('Confirm')).bottom, lessThanOrEqualTo(375 - 216));
    await tester.tap(find.text('Confirm'));
    expect(confirmed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PrismHeader grows to show its title at text scale 3', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(3)),
          child: Scaffold(
            body: Column(
              children: <Widget>[
                PrismHeader(title: 'Settings', showBack: false),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.text('Settings')).height, greaterThan(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion makes toast entrance and dismissal immediate', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    showPrismToast(key.currentState!.overlay!, 'Saved');
    await tester.pump();
    expect(tester.widget<FadeTransition>(_toastFade('Saved')).opacity.value, 1);
    await tester.tap(find.text('Saved'));
    await tester.pump();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('toast keeps its entrance and dismissal animation when motion is allowed', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    showPrismToast(key.currentState!.overlay!, 'Saved');
    await tester.pump();
    expect(tester.widget<FadeTransition>(_toastFade('Saved')).opacity.value, lessThan(1));
    await tester.pump(const Duration(milliseconds: 80));
    final double shownOpacity = tester.widget<FadeTransition>(_toastFade('Saved')).opacity.value;
    expect(shownOpacity, greaterThan(0));
    await tester.tap(find.text('Saved'));
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(tester.widget<FadeTransition>(_toastFade('Saved')).opacity.value, greaterThan(0));
  });

  testWidgets('replacing a toast before its first frame leaves only the latest message', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    final OverlayState overlay = key.currentState!.overlay!;
    showPrismToast(overlay, 'First');
    showPrismToast(overlay, 'Latest');
    await tester.pump();
    expect(find.text('First'), findsNothing);
    expect(find.text('Latest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated toast dismissal is safe', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    showPrismToast(key.currentState!.overlay!, 'Dismiss me');
    await tester.pump();
    await tester.tap(find.text('Dismiss me'));
    await tester.tap(find.text('Dismiss me'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Dismiss me'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toast timer and replacement remain safe after its overlay is disposed', (tester) async {
    final firstKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: firstKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    showPrismToast(firstKey.currentState!.overlay!, 'Old overlay');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);

    final secondKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: secondKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    showPrismToast(secondKey.currentState!.overlay!, 'New overlay');
    await tester.pump();
    expect(find.text('New overlay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all tag tones stay readable on page and raised surfaces across themes and accents', (tester) async {
    final List<PrismThemeOption> themes = <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes];
    for (final PrismThemeOption option in themes) {
      final ColorScheme base = option.theme.colorScheme;
      for (final Color accent in <Color>[base.primary, const Color(0xFFE91E63), const Color(0xFF607D8B)]) {
        final ColorScheme scheme = base.copyWith(primary: accent);
        final List<Color> surfaces = <Color>[
          scheme.surface,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
        ];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            themeAnimationDuration: Duration.zero,
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  for (int surfaceIndex = 0; surfaceIndex < surfaces.length; surfaceIndex++)
                    ColoredBox(
                      color: surfaces[surfaceIndex],
                      child: Wrap(
                        children: <Widget>[
                          for (final PrismTone tone in PrismTone.values)
                            PrismTag(label: '$surfaceIndex-${tone.name}', tone: tone),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        for (int surfaceIndex = 0; surfaceIndex < surfaces.length; surfaceIndex++) {
          final Color surface = surfaces[surfaceIndex];
          for (final PrismTone tone in PrismTone.values) {
            final Finder label = find.text('$surfaceIndex-${tone.name}');
            final Color foreground = tester.widget<Text>(label).style!.color!;
            final DecoratedBox tag = tester.widget<DecoratedBox>(
              find.ancestor(of: label, matching: find.byType(DecoratedBox)).first,
            );
            final Color fill = (tag.decoration as BoxDecoration).color!;
            final Color tinted = Color.alphaBlend(fill, surface);
            expect(
              _contrast(foreground, tinted),
              greaterThanOrEqualTo(4.5),
              reason: '${option.id} $tone on $surface with accent $accent',
            );
          }
        }
      }
    }
  });

  testWidgets('long tag labels wrap within a narrow card at text scale 2', (tester) async {
    await tester.pumpWidget(_constrained(const PrismTag(label: 'Wallpaper report'), width: 156, scale: 2));

    final Text label = tester.widget<Text>(find.text('Wallpaper report'));
    expect(label.maxLines, isNotNull);
    expect(label.maxLines, lessThanOrEqualTo(2));
    expect(tester.getSize(find.text('Wallpaper report')).width, lessThanOrEqualTo(140));
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
void _noopString(String _) {}

class _KeptAliveList extends StatefulWidget {
  const _KeptAliveList({required this.controller});

  final ScrollController controller;

  @override
  State<_KeptAliveList> createState() => _KeptAliveListState();
}

class _KeptAliveListState extends State<_KeptAliveList> with AutomaticKeepAliveClientMixin<_KeptAliveList> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView.builder(
      key: const PageStorageKey<String>('first-tab'),
      controller: widget.controller,
      itemCount: 30,
      itemBuilder: (_, index) => SizedBox(height: 60, child: Text('Row $index')),
    );
  }
}
