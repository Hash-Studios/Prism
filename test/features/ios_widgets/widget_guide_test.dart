import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:Prism/features/ios_widgets/views/widget_guide_sheet.dart';
import 'package:Prism/features/ios_widgets/views/wotd_widget_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

const String _guideTitle = 'Add Prism widgets';
const String _homeStep1 = 'Touch and hold an empty area of your Home Screen until the apps jiggle.';
const String _homeStep2 = 'Tap Edit, then tap Add Widget.';
const String _homeStep3 = 'Search for Prism, pick a size, then tap Add Widget.';
const String _lockStep1 = 'Touch and hold your Lock Screen, then tap Customize.';
const String _lockStep2 = 'Tap Lock Screen, then tap the widget area under the clock.';
const String _lockStep3 = 'Pick Prism, then tap a widget to add it.';
const String _cardTitle = 'Wall of the Day on your Home Screen';
final TargetPlatformVariant iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: home)),
);

class _SheetHost extends StatelessWidget {
  const _SheetHost();

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => showWidgetGuideSheet(context, source: WidgetGuideSourceValue.settings),
      child: const Text('Open guide'),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAppAnalytics analytics;
  late InMemoryLocalStore store;
  final Future<int?> Function() originalIosVersion = iosMajorVersion;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    store = InMemoryLocalStore();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(store));
    iosMajorVersion = () async => 17;
  });

  tearDown(() async {
    iosMajorVersion = originalIosVersion;
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(_app(const _SheetHost()));
    await tester.tap(find.text('Open guide'));
    await tester.pumpAndSettle();
  }

  testWidgets('guide sheet shows the title and the three Home Screen steps first', (tester) async {
    useTallSurface(tester);
    await openSheet(tester);

    expect(find.text(_guideTitle), findsOneWidget);
    expect(find.text(_homeStep1), findsOneWidget);
    expect(find.text(_homeStep2), findsOneWidget);
    expect(find.text(_homeStep3), findsOneWidget);
    expect(find.text(_lockStep1), findsNothing);
  }, variant: iOS);

  testWidgets('tapping Lock Screen shows the Lock Screen steps', (tester) async {
    useTallSurface(tester);
    await openSheet(tester);

    await tester.tap(find.text('Lock Screen'));
    await tester.pumpAndSettle();

    expect(find.text(_lockStep1), findsOneWidget);
    expect(find.text(_lockStep2), findsOneWidget);
    expect(find.text(_lockStep3), findsOneWidget);
    expect(find.text(_homeStep1), findsNothing);
  }, variant: iOS);

  testWidgets('tapping Done closes the guide sheet', (tester) async {
    useTallSurface(tester);
    await openSheet(tester);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text(_guideTitle), findsNothing);
  }, variant: iOS);

  testWidgets('the phone illustration has a semantics label for the Home Screen', (tester) async {
    useTallSurface(tester);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await openSheet(tester);

    expect(find.bySemanticsLabel('A phone with the Wall of the Day widget on the Home Screen'), findsOneWidget);
    semantics.dispose();
  }, variant: iOS);

  testWidgets('the Wall of the Day card shows on iOS', (tester) async {
    await tester.pumpWidget(_app(const WotdWidgetCard()));
    await tester.pumpAndSettle();

    expect(find.text(_cardTitle), findsOneWidget);
  }, variant: iOS);

  testWidgets('dismissing the card hides it and stores the choice', (tester) async {
    await tester.pumpWidget(_app(const WotdWidgetCard()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text(_cardTitle), findsNothing);
    expect(store.data[PersistenceKeys.settings(PersistenceKeys.wotdWidgetCardDismissed)], isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(const WotdWidgetCard()));
    await tester.pumpAndSettle();

    expect(find.text(_cardTitle), findsNothing);
  }, variant: iOS);

  testWidgets('the Wall of the Day card shows nothing before iOS 17', (tester) async {
    iosMajorVersion = () async => 16;
    await tester.pumpWidget(_app(const WotdWidgetCard()));
    await tester.pumpAndSettle();

    expect(find.text(_cardTitle), findsNothing);
  }, variant: iOS);

  testWidgets('the Wall of the Day card shows nothing on Android', (tester) async {
    await tester.pumpWidget(_app(const WotdWidgetCard()));
    await tester.pumpAndSettle();

    expect(find.text(_cardTitle), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Show me how opens the guide and tracks the Wall of the Day source', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(_app(const WotdWidgetCard()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show me how'));
    await tester.pumpAndSettle();

    expect(find.text(_guideTitle), findsOneWidget);
    final List<WidgetGuideOpenedEvent> opened = analytics.events.whereType<WidgetGuideOpenedEvent>().toList();
    expect(opened, hasLength(1));
    expect(opened.single.source, WidgetGuideSourceValue.wallOfTheDay);
  }, variant: iOS);
}
