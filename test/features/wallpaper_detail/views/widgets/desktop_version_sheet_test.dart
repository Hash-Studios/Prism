import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/desktop_version_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_analytics.dart';

const WallDesktopVariant _desktop = WallDesktopVariant(
  version: '0123456789abcdef',
  thumbnailUrl: 'https://img.prismwalls.com/previews/desktop-x.jpg',
  width: 2560,
  height: 1600,
);

PrismWallpaper _wall({bool withDesktop = true}) => PrismWallpaper(
  core: const WallpaperCore(
    id: 'prism-1',
    source: WallpaperSource.prism,
    fullUrl: 'https://img.test/full.jpg',
    thumbnailUrl: 'https://img.test/thumb.jpg',
    authorName: 'Akshay',
  ),
  desktop: withDesktop ? _desktop : null,
);

final DesktopVersionActionShare _originalShare = DesktopVersionActions.share;
final DesktopVersionActionApply _originalApply = DesktopVersionActions.applyOnTablet;

typedef DesktopVersionActionShare =
    Future<void> Function(BuildContext context, {required String text, required String subject});
typedef DesktopVersionActionApply = Future<void> Function(BuildContext context, PrismWallpaper wall);

Future<void> _pumpApp(WidgetTester tester, Widget home, {Size logical = const Size(390, 844)}) async {
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: kLightTheme,
      themeAnimationDuration: Duration.zero,
      home: Scaffold(body: home),
    ),
  );
  await tester.pump();
}

/// Opens the sheet the way the chip does. The sheet body needs the sheet viewport that [showPrismSheet] provides.
Future<void> _openSheet(
  WidgetTester tester,
  PrismWallpaper wall, {
  bool canSendToComputer = true,
  Size logical = const Size(390, 844),
}) async {
  await _pumpApp(
    tester,
    Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => showDesktopVersionSheet(context, wall, canSendToComputer: canSendToComputer),
          child: const Text('Open'),
        ),
      ),
    ),
    logical: logical,
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// Sets the target platform for one test body. The foundation invariant check runs before tearDown, so reset here.
void _onPlatform(String name, TargetPlatform platform, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    DesktopVersionActions.share = _originalShare;
    DesktopVersionActions.applyOnTablet = _originalApply;
    debugDefaultTargetPlatformOverride = null;
  });

  test('WallDesktopVariant.parse reads a valid map', () {
    final WallDesktopVariant? parsed = WallDesktopVariant.parse(<String, Object?>{
      'v': '0123456789abcdef',
      'thumb': 'https://img.prismwalls.com/previews/desktop-x.jpg',
      'width': 2560,
      'height': 1600,
    });

    expect(parsed, isNotNull);
    expect(parsed!.width, 2560);
    expect(parsed.height, 1600);
    expect(parsed.version, '0123456789abcdef');
  });

  test('WallDesktopVariant.parse rejects bad input', () {
    Map<String, Object?> valid() => <String, Object?>{
      'v': '0123456789abcdef',
      'thumb': 'https://img.prismwalls.com/previews/desktop-x.jpg',
      'width': 2560,
      'height': 1600,
    };

    expect(WallDesktopVariant.parse(valid()..['v'] = 'XYZ'), isNull);
    expect(WallDesktopVariant.parse(valid()..['thumb'] = 'http://img.prismwalls.com/x.jpg'), isNull);
    expect(WallDesktopVariant.parse(valid()..['width'] = 1600), isNull);
    expect(WallDesktopVariant.parse(valid()..['width'] = 1000), isNull);
    expect(WallDesktopVariant.parse('nope'), isNull);
  });

  test('desktopWebPageUrl opens the Desktop tab of the wall page', () {
    expect(desktopWebPageUrl('ABC123').toString(), 'https://prismwalls.com/wallpaper/ABC123#desktop');
  });

  testWidgets('the chip shows its label and tracks one chip-shown event', (tester) async {
    await _pumpApp(tester, DesktopVersionChip(wall: _wall(), canSendToComputer: true));

    expect(find.text('Desktop version'), findsOneWidget);
    final List<DesktopChipShownEvent> shown = analytics.events.whereType<DesktopChipShownEvent>().toList();
    expect(shown, hasLength(1));
    expect(shown.single.eventName, 'desktop_chip_shown');
    expect(shown.single.toWireParameters(), {'content_id': 'prism-1'});
  });

  testWidgets('tapping the chip opens the sheet and tracks it', (tester) async {
    await _pumpApp(tester, DesktopVersionChip(wall: _wall(), canSendToComputer: true));

    await tester.tap(find.text('Desktop version'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(DesktopVersionSheet), matching: find.text('Desktop version')),
      findsOneWidget,
    );
    expect(find.text('The same scene, made wide for a computer screen. 2560 × 1600.'), findsOneWidget);
    expect(find.text('Send to my computer'), findsOneWidget);
    final List<DesktopSheetOpenedEvent> opened = analytics.events.whereType<DesktopSheetOpenedEvent>().toList();
    expect(opened, hasLength(1));
    expect(opened.single.eventName, 'desktop_sheet_opened');
    expect(opened.single.toWireParameters(), {'content_id': 'prism-1'});
  });

  testWidgets('Send to my computer shares the web page link and tracks the send', (tester) async {
    final List<({String text, String subject})> shared = <({String text, String subject})>[];
    DesktopVersionActions.share = (context, {required text, required subject}) async {
      shared.add((text: text, subject: subject));
    };
    await _openSheet(tester, _wall());

    await tester.tap(find.text('Send to my computer'));
    await tester.pump();

    expect(shared, hasLength(1));
    expect(
      shared.single.text,
      'Get this wallpaper for your computer: https://prismwalls.com/wallpaper/prism-1#desktop',
    );
    expect(shared.single.subject, 'Desktop wallpaper from Prism');
    final List<DesktopSendToComputerEvent> sent = analytics.events.whereType<DesktopSendToComputerEvent>().toList();
    expect(sent, hasLength(1));
    expect(sent.single.eventName, 'desktop_send_to_computer');
    expect(sent.single.toWireParameters(), {'content_id': 'prism-1'});
  });

  testWidgets('canSendToComputer false hides Send to my computer', (tester) async {
    await _openSheet(tester, _wall(), canSendToComputer: false);

    expect(find.text('Send to my computer'), findsNothing);
  });

  _onPlatform('a phone-width sheet has no tablet set or save button', TargetPlatform.android, (tester) async {
    await _openSheet(tester, _wall());

    expect(find.text('Set desktop version'), findsNothing);
    expect(find.text('Save desktop version'), findsNothing);
  });

  _onPlatform('a tablet sheet on Android shows Set desktop version and applies the wall', TargetPlatform.android, (
    tester,
  ) async {
    final List<PrismWallpaper> applied = <PrismWallpaper>[];
    DesktopVersionActions.applyOnTablet = (context, wall) async => applied.add(wall);
    final PrismWallpaper wall = _wall();
    await _openSheet(tester, wall, logical: const Size(1024, 1366));

    expect(find.text('Set desktop version'), findsOneWidget);
    expect(find.text('Save desktop version'), findsNothing);

    await tester.tap(find.text('Set desktop version'));
    await tester.pump();

    expect(applied, hasLength(1));
    expect(applied.single, same(wall));
  });

  _onPlatform('a tablet sheet on iOS shows Save desktop version', TargetPlatform.iOS, (tester) async {
    await _openSheet(tester, _wall(), logical: const Size(1024, 1366));

    expect(find.text('Save desktop version'), findsOneWidget);
    expect(find.text('Set desktop version'), findsNothing);
  });
}
