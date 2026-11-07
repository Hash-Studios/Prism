import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/photo_wallpaper_repository.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/photo_job.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/photo_wallpaper_page.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/photo_wallpaper_widgets.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

/// A 1 x 1 PNG. The picker and the measure step are faked, so the bytes only need to decode.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

const Map<String, Object?> _successMap = <String, Object?>{
  'jobId': 'pj_x',
  'state': 'succeeded',
  'imageUrl': 'https://example.com/r.jpg',
  'width': 1080,
  'height': 2340,
  'watermarked': true,
};

const ValueKey<String> _runKey = ValueKey<String>('photo-run');
const ValueKey<String> _placementKey = ValueKey<String>('photo-placement');
const ValueKey<String> _compareKey = ValueKey<String>('photo-compare');

/// Fakes for the repository seams. [photo] is what `measure` reports for every picked photo.
class _Harness {
  _Harness({this.photo = const PhotoSize(4000, 3000)});

  final PhotoSize photo;
  final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
  int picks = 0;

  /// Replaces the default success reply for the next job when set.
  Future<Object?> Function(Map<String, Object?> payload)? onCall;

  late final PhotoWallpaperRepository repository = PhotoWallpaperRepository(
    () async {
      picks++;
      return _png;
    },
    (Uint8List bytes) async => photo,
    (Uint8List bytes, int longSide) async => bytes,
    (Map<String, Object?> payload) {
      payloads.add(payload);
      final Future<Object?> Function(Map<String, Object?> payload)? handler = onCall;
      return handler == null ? Future<Object?>.value(_successMap) : handler(payload);
    },
  );
}

int _top(Map<String, Object?> payload) => (payload['placement']! as Map<Object?, Object?>)['top']! as int;

/// Lets the AnimatedSwitcher hand-off and the job future finish. The breathing pulse repeats, so no pumpAndSettle.
Future<void> _settle(WidgetTester tester) => tester.pump(const Duration(seconds: 2));

/// Pumps in 100 ms steps (up to 5 s) until [finder] finds nothing, then one more step for the new frame.
Future<void> _waitUntilGone(WidgetTester tester, Finder finder) async {
  for (int i = 0; i < 50 && finder.evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pumpPage(
  WidgetTester tester,
  _Harness harness, {
  bool isPro = false,
  int balance = 500,
  Size size = const Size(1080, 2340),
  double devicePixelRatio = 3,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  AnalyticsRuntime.instance = FakeAppAnalytics();
  addTearDown(AnalyticsRuntime.reset);

  app_state.prismUser = app_constants.createGuestPrismUser()
    ..id = 'user-1'
    ..loggedIn = true
    ..premium = isPro;
  addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
  CoinsService.instance.balanceNotifier.value = balance;

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PhotoWallpaperPage(repository: harness.repository, isPro: isPro, screenSize: const PhotoSize(1080, 2340)),
    ),
  );
  await tester.pump();
}

/// Drags from the top part of the frame, which stays clear of the bottom bar, far up the screen.
Future<void> _dragFrameUp(WidgetTester tester) async {
  final Rect frame = tester.getRect(find.byKey(_placementKey));
  await tester.dragFrom(Offset(frame.center.dx, frame.top + frame.height * 0.2), const Offset(0, -2000));
  await _settle(tester);
}

Future<void> _pickPhoto(WidgetTester tester) async {
  // At 2x text the empty state list is taller than the screen. Scroll until the button is on screen.
  await tester.ensureVisible(find.text('Choose a photo'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Choose a photo'));
  await _waitUntilGone(tester, find.text('Choose a photo'));
}

void main() {
  testWidgets('empty state offers a photo and the fal.ai privacy note', (tester) async {
    final _Harness harness = _Harness();
    await _pumpPage(tester, harness);

    expect(find.text('Choose a photo'), findsOneWidget);
    expect(find.textContaining('fal.ai'), findsOneWidget);
  });

  testWidgets('choosing a photo calls pick and plans an extend for a landscape photo', (tester) async {
    final _Harness harness = _Harness();
    await _pumpPage(tester, harness);

    await _pickPhoto(tester);

    expect(harness.picks, 1);
    expect(find.text('Extend to fit your screen'), findsOneWidget);
  });

  testWidgets('extend shows the cost on the run button', (tester) async {
    await _pumpPage(tester, _Harness());
    await _pickPhoto(tester);

    expect(find.text('Extend · 75 coins'), findsOneWidget);
    expect(find.byKey(_runKey), findsOneWidget);
  });

  testWidgets('a small phone-shaped photo plans an upscale at 10 coins', (tester) async {
    await _pumpPage(tester, _Harness(photo: const PhotoSize(540, 1170)));
    await _pickPhoto(tester);

    expect(find.text('Upscale'), findsOneWidget);
    expect(find.text('Upscale · 10 coins'), findsOneWidget);
  });

  testWidgets('Pro pays half the extend cost, rounded up', (tester) async {
    await _pumpPage(tester, _Harness(), isPro: true);
    await _pickPhoto(tester);

    expect(find.text('Extend · 38 coins'), findsOneWidget);
  });

  testWidgets('a short balance turns the run button into Get coins', (tester) async {
    await _pumpPage(tester, _Harness(), balance: 20);
    await _pickPhoto(tester);

    expect(find.text('Get coins · need 55'), findsOneWidget);
    expect(find.text('Extend · 75 coins'), findsNothing);
  });

  testWidgets('a pending retry stays available when the original charge leaves a short balance', (tester) async {
    final _Harness harness = _Harness()
      ..onCall = (Map<String, Object?> _) async => throw StateError('connection dropped');
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));
    expect(harness.payloads, hasLength(2));

    CoinsService.instance.balanceNotifier.value = 0;
    await tester.pump();
    expect(find.text('Extend · 75 coins'), findsOneWidget);
    expect(find.text('Get coins · need 75'), findsNothing);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));
    expect(harness.payloads, hasLength(4));
    expect(harness.payloads.map((Map<String, Object?> payload) => payload['requestId']).toSet(), hasLength(1));
  });

  testWidgets('a charged job with a pending refund retries with the same request ID', (tester) async {
    final _Harness harness = _Harness();
    harness.onCall = (Map<String, Object?> _) async => harness.payloads.length == 1
        ? <String, Object?>{'state': 'failed', 'reason': 'provider_error', 'refunded': false}
        : _successMap;
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));
    CoinsService.instance.balanceNotifier.value = 0;
    await tester.pump();
    expect(find.text('Extend · 75 coins'), findsOneWidget);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));
    expect(harness.payloads, hasLength(2));
    expect(harness.payloads[0]['requestId'], harness.payloads[1]['requestId']);
    expect(find.text('Before'), findsOneWidget);
  });

  testWidgets('an unrecognized job response keeps the same request ID for retry', (tester) async {
    final _Harness harness = _Harness();
    harness.onCall = (Map<String, Object?> _) async =>
        harness.payloads.length == 1 ? <String, Object?>{'state': 'running'} : _successMap;
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));
    CoinsService.instance.balanceNotifier.value = 0;
    await tester.pump();
    expect(find.text('Extend · 75 coins'), findsOneWidget);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));
    expect(harness.payloads, hasLength(2));
    expect(harness.payloads[0]['requestId'], harness.payloads[1]['requestId']);
    expect(find.text('Before'), findsOneWidget);
  });

  testWidgets('a photo that already fits shows no run button', (tester) async {
    await _pumpPage(tester, _Harness(photo: const PhotoSize(1080, 2340)));
    await _pickPhoto(tester);

    expect(find.text('This photo already fits your screen'), findsOneWidget);
    expect(find.byKey(_runKey), findsNothing);
  });

  testWidgets('a photo too narrow for the server placement limit is rejected before the call', (tester) async {
    final _Harness harness = _Harness(photo: const PhotoSize(4096, 128));
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);
    await tester.tap(find.text('Desktop version'));
    await _settle(tester);

    await tester.tap(find.byKey(_runKey));
    await _settle(tester);

    expect(harness.payloads, isEmpty);
    expect(find.text("This photo can't be opened. Choose another photo."), findsOneWidget);
  });

  testWidgets('Desktop version plans an extend to a desktop screen', (tester) async {
    await _pumpPage(tester, _Harness());
    await _pickPhoto(tester);

    await tester.tap(find.text('Desktop version'));
    await _settle(tester);

    expect(find.text('Extend to fit a desktop screen'), findsOneWidget);
  });

  testWidgets('dragging the frame up moves the photo to the top of the canvas', (tester) async {
    final _Harness harness = _Harness();
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);

    expect(find.text('Place your photo'), findsOneWidget);
    expect(find.text('Reset position'), findsNothing);

    await _dragFrameUp(tester);
    expect(find.text('Reset position'), findsOneWidget);

    await tester.tap(find.byKey(_runKey));
    await _settle(tester);

    expect(harness.payloads, hasLength(1));
    expect(_top(harness.payloads.single), 0);
  });

  testWidgets('Reset position puts the photo back in the centre', (tester) async {
    final _Harness harness = _Harness();
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);

    await _dragFrameUp(tester);
    await tester.tap(find.text('Reset position'));
    await _settle(tester);

    expect(find.text('Reset position'), findsNothing);
    await tester.tap(find.byKey(_runKey));
    await _settle(tester);

    expect(_top(harness.payloads.single), 765);
  });

  testWidgets('while the job runs, the progress copy shows and the run button is gone', (tester) async {
    final _Harness harness = _Harness();
    final Completer<Object?> pending = Completer<Object?>();
    harness.onCall = (Map<String, Object?> payload) => pending.future;
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);

    await tester.tap(find.byKey(_runKey));
    await _settle(tester);

    expect(find.text('Extending your photo'), findsOneWidget);
    expect(find.text('This can take up to a minute.'), findsOneWidget);
    expect(find.byKey(_runKey), findsNothing);

    pending.complete(_successMap);
    await tester.pump();
    await _waitUntilGone(tester, find.text('Extending your photo'));

    expect(find.text('Extending your photo'), findsNothing);
  });

  testWidgets('a finished job shows Before and After with the result actions', (tester) async {
    await _pumpPage(tester, _Harness());
    await _pickPhoto(tester);

    await tester.tap(find.byKey(_runKey));
    await _settle(tester);

    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
    expect(find.byKey(_compareKey), findsOneWidget);
    expect(find.text('Set as wallpaper'), findsOneWidget);
    expect(find.text('Save to folder'), findsOneWidget);
    expect(find.text('Use another photo'), findsOneWidget);
  });

  testWidgets('the Before side shows the photo where the user placed it, with the empty canvas around it', (
    tester,
  ) async {
    final _Harness harness = _Harness();
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);
    await _dragFrameUp(tester);

    await tester.tap(find.byKey(_runKey));
    await _settle(tester);

    final Finder before = find.descendant(of: find.byKey(_compareKey), matching: find.byType(PhotoInCanvas));
    expect(before, findsOneWidget);
    final PhotoPlacement placed = tester.widget<PhotoInCanvas>(before).placement;
    expect(placed.top, 0);
    expect(placed.toJson(), harness.payloads.single['placement']);
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('the Before side keeps its theme canvas shade and is opaque in $brightness mode', (tester) async {
      await _pumpPage(tester, _Harness(), brightness: brightness);
      await _pickPhoto(tester);
      await tester.tap(find.byKey(_runKey));
      await _settle(tester);

      final Finder canvas = find.descendant(
        of: find.descendant(of: find.byKey(_compareKey), matching: find.byType(PhotoInCanvas)),
        matching: find.byType(ColoredBox),
      );
      final ColorScheme cs = Theme.of(tester.element(find.byKey(_compareKey))).colorScheme;
      final Color oldDraftCanvas = Color.alphaBlend(cs.onSurface.withValues(alpha: 0.06), cs.surface);
      final Color actual = tester.widget<ColoredBox>(canvas.first).color;
      expect(actual.a, 1.0);
      expect(actual, oldDraftCanvas);
    });
  }

  testWidgets('result actions wrap their labels on a narrow screen with large text', (tester) async {
    await _pumpPage(
      tester,
      _Harness(),
      size: const Size(640, 1334),
      devicePixelRatio: 2,
      textScale: 2,
    );
    await _pickPhoto(tester);
    await tester.tap(find.byKey(_runKey));
    await _settle(tester);

    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Save to folder'), findsOneWidget);
    for (final String label in <String>['Download', 'Save to folder']) {
      final Finder text = find.text(label);
      expect(tester.renderObject<RenderParagraph>(text).didExceedMaxLines, isFalse, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a blocked output shows the refund line and Try again', (tester) async {
    final _Harness harness = _Harness();
    harness.onCall = (Map<String, Object?> payload) async => <String, Object?>{
      'state': 'failed',
      'reason': 'unsafe_output',
      'refunded': true,
    };
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);

    await tester.tap(find.byKey(_runKey));
    await _settle(tester);

    expect(find.textContaining('The result was blocked'), findsOneWidget);
    expect(find.textContaining('Your 75 coins were returned.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('an unsafe input shows the refusal and Choose another photo', (tester) async {
    final _Harness harness = _Harness();
    harness.onCall = (Map<String, Object?> payload) async => <String, Object?>{
      'state': 'failed',
      'reason': 'unsafe_input',
      'refunded': false,
    };
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);

    await tester.tap(find.byKey(_runKey));
    await _settle(tester);

    expect(find.textContaining("This photo can't be used"), findsOneWidget);
    expect(find.descendant(of: find.byType(GlintState), matching: find.text('Choose another photo')), findsOneWidget);
  });

  testWidgets('the refund message uses the actual server charge instead of the client price', (tester) async {
    final _Harness harness = _Harness();
    harness.onCall = (Map<String, Object?> _) async => <String, Object?>{
      'state': 'failed',
      'reason': 'unsafe_output',
      'cost': 38,
      'refunded': true,
    };
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);
    expect(find.text('Extend · 75 coins'), findsOneWidget);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));

    expect(find.textContaining('Your 38 coins were returned.'), findsOneWidget);
    expect(find.textContaining('Your 75 coins were returned.'), findsNothing);
  });

  testWidgets('large text on a small screen lays out without overflow', (tester) async {
    await _pumpPage(tester, _Harness(), size: const Size(750, 1334), devicePixelRatio: 2, textScale: 2);
    await _pickPhoto(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Extend · 75 coins'), findsOneWidget);
  });

  testWidgets('the placement frame and the compare view expose their semantics', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpPage(tester, _Harness());
    await _pickPhoto(tester);

    final Finder placement = find.bySemanticsLabel('Photo position in the frame');
    expect(placement, findsOneWidget);
    final List<String?> actionLabels = tester
        .getSemantics(placement)
        .getSemanticsData()
        .customSemanticsActionIds!
        .map<String?>((int id) => CustomSemanticsAction.getAction(id)?.label)
        .toList();
    expect(actionLabels, <String?>['Move to start', 'Move to centre', 'Move to end']);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));

    expect(find.bySemanticsLabel('Before and after. Swipe up or down to compare.'), findsOneWidget);
    final SemanticsData compare = tester
        .getSemantics(find.bySemanticsLabel('Before and after. Swipe up or down to compare.'))
        .getSemanticsData();
    expect(compare.value, '50%');
    expect(compare.flagsCollection.isSlider, isTrue);
    expect(compare.hasAction(SemanticsAction.increase), isTrue);
    expect(compare.hasAction(SemanticsAction.decrease), isTrue);
    handle.dispose();
  });
}
