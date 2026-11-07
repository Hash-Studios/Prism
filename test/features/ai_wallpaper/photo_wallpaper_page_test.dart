import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/photo_wallpaper_repository.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/photo_job.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/photo_wallpaper_page.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_decoded_image.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/photo_wallpaper_widgets.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/views/widgets/folder_sheet.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
  int encodes = 0;
  bool failEncode = false;
  Future<PhotoSize> Function()? onMeasure;
  final FakeAppAnalytics analytics = FakeAppAnalytics();

  /// Replaces the default success reply for the next job when set.
  Future<Object?> Function(Map<String, Object?> payload)? onCall;

  /// The job lookup after a restart. Unknown by default.
  Future<Object?> Function(Map<String, Object?> payload)? onLookup;
  int lookups = 0;

  /// The pending job saved on the device, as the repository writes it.
  String? pendingJson;
  Future<String?> Function()? onRead;
  Future<void> Function(String? json)? onWrite;
  late _Session session;

  late final PhotoWallpaperRepository repository = PhotoWallpaperRepository(
    () async {
      picks++;
      return _png;
    },
    (Uint8List bytes) async => onMeasure == null ? photo : await onMeasure!(),
    (Uint8List bytes, int longSide) async {
      encodes++;
      if (failEncode) throw const FormatException('photo removed');
      return bytes;
    },
    (Map<String, Object?> payload) {
      payloads.add(payload);
      final Future<Object?> Function(Map<String, Object?> payload)? handler = onCall;
      return handler == null ? Future<Object?>.value(_successMap) : handler(payload);
    },
    (Map<String, Object?> payload) {
      lookups++;
      return onLookup?.call(payload) ?? Future<Object?>.value(<String, Object?>{'state': 'unknown'});
    },
    () async => onRead == null ? pendingJson : await onRead!(),
    (String? json) async {
      if (onWrite != null) await onWrite!(json);
      pendingJson = json;
    },
  );
}

class _FoldersBloc extends Mock implements FoldersBloc {
  _FoldersBloc() {
    when(() => state).thenReturn(FoldersState.initial().copyWith(status: LoadStatus.success, userId: 'user-1'));
    when(() => stream).thenAnswer((_) => const Stream<FoldersState>.empty());
  }
}

class _Assets extends OfflineAssetStore {
  final Completer<File> download = Completer<File>();
  int resolves = 0;

  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) {
    resolves++;
    return download.future;
  }
}

class _ActivityApi extends PrismLiveActivityHostApi {
  final Completer<String?> started = Completer<String?>();
  int cancels = 0;

  @override
  Future<String?> startAiGeneration(AiActivityRequest request) => started.future;

  @override
  Future<void> cancelAiGeneration(String id) async => cancels++;
}

class _Session implements SessionRepository {
  PrismUsersV2 user = app_state.prismUser;
  final StreamController<PrismUsersV2> changes = StreamController<PrismUsersV2>.broadcast(sync: true);

  void switchTo(String? uid) {
    user = app_constants.createGuestPrismUser()
      ..id = uid ?? ''
      ..loggedIn = uid != null;
    changes.add(user);
  }

  @override
  PrismUsersV2 get currentUser => user;

  @override
  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 value) async {
    user = value;
    changes.add(user);
    return Result.success(
      SessionEntity(userId: user.id, loggedIn: user.loggedIn, premium: user.premium, subscriptionTier: 'free'),
    );
  }

  @override
  Stream<PrismUsersV2> watchCurrentUser() => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  FoldersBloc? folders,
  ValueNotifier<PhotoSize>? screenSize,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  AnalyticsRuntime.instance = harness.analytics;
  addTearDown(AnalyticsRuntime.reset);

  app_state.prismUser = app_constants.createGuestPrismUser()
    ..id = 'user-1'
    ..loggedIn = true
    ..premium = isPro;
  addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
  CoinsService.instance.balanceNotifier.value = balance;
  harness.session = _Session();
  getIt.registerSingleton<SessionRepository>(harness.session);
  addTearDown(() async {
    await getIt.unregister<SessionRepository>();
    await harness.session.changes.close();
  });

  await tester.pumpWidget(
    BlocProvider<FoldersBloc>.value(
      value: folders ?? _FoldersBloc(),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screenSize == null
            ? PhotoWallpaperPage(repository: harness.repository, isPro: isPro, screenSize: const PhotoSize(1080, 2340))
            : ValueListenableBuilder<PhotoSize>(
                valueListenable: screenSize,
                builder: (_, PhotoSize size, _) =>
                    PhotoWallpaperPage(repository: harness.repository, isPro: isPro, screenSize: size),
              ),
      ),
    ),
  );
  await tester.pump();
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
    harness.onLookup = (_) async => _successMap;
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
    expect(harness.payloads, hasLength(2));
    expect(harness.lookups, 1);
    expect(harness.payloads.map((Map<String, Object?> payload) => payload['requestId']).toSet(), hasLength(1));
  });

  testWidgets('a charged job with a pending refund retries with the same request ID', (tester) async {
    final _Harness harness = _Harness();
    harness.onCall = (Map<String, Object?> _) async => harness.payloads.length == 1
        ? <String, Object?>{'state': 'failed', 'reason': 'provider_error', 'refunded': false}
        : _successMap;
    harness.onLookup = (_) async => _successMap;
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));
    CoinsService.instance.balanceNotifier.value = 0;
    await tester.pump();
    expect(find.text('Extend · 75 coins'), findsOneWidget);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));
    expect(harness.payloads, hasLength(1));
    expect(harness.lookups, 1);
    expect(find.text('Before'), findsOneWidget);
  });

  testWidgets('an unrecognized job response keeps the same request ID for retry', (tester) async {
    final _Harness harness = _Harness();
    harness.onCall = (Map<String, Object?> _) async =>
        harness.payloads.length == 1 ? <String, Object?>{'state': 'running'} : _successMap;
    harness.onLookup = (_) async => _successMap;
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));
    CoinsService.instance.balanceNotifier.value = 0;
    await tester.pump();
    expect(find.text('Extend · 75 coins'), findsOneWidget);

    await tester.tap(find.byKey(_runKey));
    await _waitUntilGone(tester, find.byKey(_runKey));
    expect(harness.payloads, hasLength(1));
    expect(harness.lookups, 1);
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
    expect(find.text('This usually takes under a minute.'), findsOneWidget);
    expect(find.byKey(_runKey), findsNothing);

    pending.complete(_successMap);
    await tester.pump();
    await _waitUntilGone(tester, find.text('Extending your photo'));

    expect(find.text('Extending your photo'), findsNothing);
  });

  testWidgets('a stale draft placement callback cannot change a running job or its comparison photo', (tester) async {
    final _Harness harness = _Harness();
    await _pumpPage(tester, harness);
    await _pickPhoto(tester);
    final PhotoPlacementFrame draft = tester.widget<PhotoPlacementFrame>(find.byType(PhotoPlacementFrame));
    final Completer<void> saved = Completer<void>();
    harness.onWrite = (_) => saved.future;
    await tester.tap(find.byKey(_runKey));
    await tester.pump();

    draft.onChanged(draft.placement.alignedTo(0));
    await tester.pump();
    saved.complete();
    await _settle(tester);

    expect(_top(harness.payloads.single), 765);
    final PhotoInCanvas before = tester.widget<PhotoInCanvas>(
      find.descendant(of: find.byKey(_compareKey), matching: find.byType(PhotoInCanvas)),
    );
    expect(before.placement.top, 765);
  });

  testWidgets('a finished upscale keeps its job mode when a new screen size would plan Extend', (tester) async {
    final _Harness harness = _Harness(photo: const PhotoSize(540, 1170));
    final ValueNotifier<PhotoSize> size = ValueNotifier<PhotoSize>(const PhotoSize(1080, 2340));
    addTearDown(size.dispose);
    final _Assets assets = _Assets();
    OfflineAssetStore.testOverride = assets;
    addTearDown(() => OfflineAssetStore.testOverride = null);
    await _pumpPage(tester, harness, screenSize: size);
    await _pickPhoto(tester);
    await tester.tap(find.byKey(_runKey));
    await _settle(tester);
    size.value = const PhotoSize(720, 1728);
    await tester.pump();
    expect(planPhotoJob(harness.photo, size.value), PhotoJobMode.extend);

    await tester.tap(find.text('Set as wallpaper'));
    await tester.pump();

    final PhotoJobResultSetEvent event = harness.analytics.events.whereType<PhotoJobResultSetEvent>().single;
    expect(event.toWireParameters()['mode'], 'upscale');
    await tester.pumpWidget(const SizedBox());
    assets.download.complete(File('/tmp/unused-result.jpg'));
    await tester.pump();
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
    await _pumpPage(tester, _Harness(), size: const Size(640, 1334), devicePixelRatio: 2, textScale: 2);
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
      'refunded': true,
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

  group('recovery after the app closed during a job', () {
    String pending(String userId) => jsonEncode(
      const PendingPhotoJob(
        userId: 'user-1',
        requestId: 'req-00000042',
        mode: PhotoJobMode.extend,
        target: PhotoJobTarget.phone,
      ).toJson()..['userId'] = userId,
    );

    testWidgets('running a job saves it on the device first and clears it when the job ends', (tester) async {
      final _Harness harness = _Harness();
      String? savedDuringCall;
      harness.onCall = (Map<String, Object?> payload) async {
        savedDuringCall = harness.pendingJson;
        return _successMap;
      };
      await _pumpPage(tester, harness);
      await _pickPhoto(tester);
      await tester.tap(find.byKey(_runKey));
      await _settle(tester);

      final Object? stored = jsonDecode(savedDuringCall!);
      final PendingPhotoJob? saved = PendingPhotoJob.fromJson(stored is List<dynamic> ? stored.single : stored);
      expect(saved?.requestId, harness.payloads.single['requestId']);
      expect(saved?.mode, PhotoJobMode.extend);
      expect(harness.pendingJson, isNull);
    });

    testWidgets('a job that finished while the app was closed shows its result, with no new charge', (tester) async {
      final _Harness harness = _Harness()..pendingJson = pending('user-1');
      harness.onLookup = (Map<String, Object?> payload) async {
        expect(payload['requestId'], 'req-00000042');
        return _successMap;
      };
      await _pumpPage(tester, harness);
      await _settle(tester);

      expect(harness.lookups, 1);
      expect(harness.payloads, isEmpty);
      expect(find.byKey(_compareKey), findsNothing);
      expect(find.text('Set as wallpaper'), findsOneWidget);
      expect(find.text('Use another photo'), findsOneWidget);
      expect(harness.pendingJson, isNull);
    });

    testWidgets('a job that failed while the app was closed shows the refund and offers a new photo', (tester) async {
      final _Harness harness = _Harness()..pendingJson = pending('user-1');
      harness.onLookup = (Map<String, Object?> payload) async => <String, Object?>{
        'state': 'failed',
        'reason': 'timeout',
        'refunded': true,
        'cost': 75,
      };
      await _pumpPage(tester, harness);
      await _settle(tester);

      expect(find.textContaining('Your 75 coins were returned.'), findsOneWidget);
      expect(find.text('Choose a photo'), findsOneWidget);
      expect(harness.pendingJson, isNull);
    });

    testWidgets('a job still running keeps its saved id, so Try again asks the server again', (tester) async {
      final _Harness harness = _Harness()..pendingJson = pending('user-1');
      harness.onLookup = (Map<String, Object?> payload) async => <String, Object?>{'jobId': 'x', 'state': 'running'};
      await _pumpPage(tester, harness);
      await _settle(tester);

      expect(find.text('Still working on your last photo.'), findsOneWidget);
      expect(harness.pendingJson, isNotNull);
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(harness.lookups, 2);
    });

    testWidgets("another account's saved job is ignored", (tester) async {
      final _Harness harness = _Harness()..pendingJson = pending('someone-else');
      await _pumpPage(tester, harness);
      await _settle(tester);

      expect(harness.lookups, 0);
      expect(find.text('Choose a photo'), findsOneWidget);
    });

    testWidgets('a recovered result is not shown after the signed-in account changes', (tester) async {
      final _Harness harness = _Harness()..pendingJson = pending('user-1');
      final Completer<Object?> lookup = Completer<Object?>();
      harness.onLookup = (_) => lookup.future;
      await _pumpPage(tester, harness);
      await tester.pump();
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'user-2'
        ..loggedIn = true;
      lookup.complete(_successMap);
      await _settle(tester);

      expect(find.text('Set as wallpaper'), findsNothing);
      expect(harness.pendingJson, isNotNull);
    });

    for (final String? nextUser in <String?>[null, 'user-2']) {
      testWidgets('a visible recovered result is removed on session change to $nextUser', (tester) async {
        final _Harness harness = _Harness()..pendingJson = pending('user-1');
        harness.onLookup = (_) async => _successMap;
        await _pumpPage(tester, harness);
        await _settle(tester);
        expect(find.text('Set as wallpaper'), findsOneWidget);

        harness.session.switchTo(nextUser);
        await _settle(tester);

        expect(find.text('Set as wallpaper'), findsNothing);
        expect(find.text('Save to folder'), findsNothing);
        if (nextUser != null) expect(find.text('Choose a photo'), findsOneWidget);
      });
    }

    testWidgets('an A-B-A session change cannot publish an old recovered result', (tester) async {
      final _Harness harness = _Harness()..pendingJson = pending('user-1');
      final Completer<Object?> old = Completer<Object?>();
      harness.onLookup = (_) =>
          harness.lookups == 1 ? old.future : Future<Object?>.value(<String, Object?>{'state': 'running'});
      await _pumpPage(tester, harness);
      await tester.pump();
      harness.session.switchTo('user-2');
      await tester.pump();
      harness.session.switchTo('user-1');
      await tester.pump();
      old.complete(_successMap);
      await _settle(tester);

      expect(find.text('Set as wallpaper'), findsNothing);
      expect(harness.pendingJson, isNotNull);
    });

    testWidgets('picking waits for the saved job read before allowing replacement', (tester) async {
      final _Harness harness = _Harness();
      final Completer<String?> read = Completer<String?>();
      harness.onRead = () => read.future;
      harness.onLookup = (_) async => <String, Object?>{'state': 'running'};
      await _pumpPage(tester, harness);
      expect(tester.widget<GlintState>(find.byType(GlintState)).onAction, isNull);
      expect(harness.picks, 0);

      harness.pendingJson = pending('user-1');
      read.complete(harness.pendingJson);
      await _settle(tester);
      expect(harness.lookups, 1);
      expect(find.text('Still working on your last photo.'), findsOneWidget);
      expect(harness.payloads, isEmpty);
    });

    testWidgets('a failed pending save stops before the paid callable and permits a safe retry', (tester) async {
      final _Harness harness = _Harness();
      await _pumpPage(tester, harness);
      await _pickPhoto(tester);
      harness.onWrite = (_) async => throw StateError('disk full');
      await tester.tap(find.byKey(_runKey));
      await _settle(tester);
      expect(harness.payloads, isEmpty);
      expect(tester.takeException(), isNull);
      expect(find.text('Extending your photo'), findsNothing);

      harness.onWrite = null;
      await tester.tap(find.byKey(_runKey));
      await _settle(tester);
      await tester.tap(find.byKey(_runKey));
      await _settle(tester);
      expect(harness.payloads, hasLength(1));
      expect(find.text('Set as wallpaper'), findsOneWidget);
    });

    testWidgets('a refunded network failure is final and clears the saved request', (tester) async {
      final _Harness harness = _Harness()..pendingJson = pending('user-1');
      harness.onLookup = (_) async => <String, Object?>{
        'state': 'failed',
        'reason': 'network',
        'charged': true,
        'refunded': true,
        'cost': 75,
      };
      await _pumpPage(tester, harness);
      await _settle(tester);

      expect(harness.pendingJson, isNull);
      expect(find.text('Choose a photo'), findsOneWidget);
    });

    testWidgets('an uncertain paid job cannot be replaced by another photo or target', (tester) async {
      final _Harness harness = _Harness()..onCall = (_) async => throw StateError('connection dropped');
      await _pumpPage(tester, harness);
      await _pickPhoto(tester);
      await tester.tap(find.byKey(_runKey));
      await _settle(tester);
      final String? saved = harness.pendingJson;
      await tester.tap(find.text('Choose another photo').last);
      await _settle(tester);
      expect(harness.picks, 1);
      expect(harness.pendingJson, saved);
      expect(harness.payloads, hasLength(2));
      expect(find.text('Desktop version'), findsNothing);
    });

    testWidgets('retry looks up a dispatched request even when the source can no longer be encoded', (tester) async {
      final _Harness harness = _Harness()..onCall = (_) async => throw StateError('connection dropped');
      harness.onLookup = (_) async => <String, Object?>{'state': 'running'};
      await _pumpPage(tester, harness);
      await _pickPhoto(tester);
      await tester.tap(find.byKey(_runKey));
      await _settle(tester);
      final String? saved = harness.pendingJson;
      harness.failEncode = true;

      await tester.tap(find.byKey(_runKey));
      await _settle(tester);

      expect(harness.encodes, 1);
      expect(harness.lookups, 1);
      expect(harness.payloads, hasLength(2));
      expect(harness.pendingJson, saved);
      expect(find.text('Still working on your last photo.'), findsOneWidget);
    });

    testWidgets('Run is disabled while a replacement photo is being measured', (tester) async {
      final _Harness harness = _Harness();
      await _pumpPage(tester, harness);
      await _pickPhoto(tester);
      final Completer<PhotoSize> measured = Completer<PhotoSize>();
      harness.onMeasure = () => measured.future;
      final PrismButton originalRun = tester.widget<PrismButton>(find.byKey(_runKey));
      await tester.tap(find.text('Choose another photo'));
      await tester.pump();
      expect(tester.widget<PrismButton>(find.byKey(_runKey)).onPressed, isNull);
      originalRun.onPressed!();
      await tester.pump();
      measured.complete(const PhotoSize(540, 1170));
      await _settle(tester);

      expect(harness.payloads, isEmpty);
      expect(harness.pendingJson, isNull);
      expect(find.text('Upscale · 10 coins'), findsOneWidget);
    });

    testWidgets('a save conflict recovers the actual stored request rather than the unsent candidate', (tester) async {
      final _Harness harness = _Harness();
      await _pumpPage(tester, harness);
      await _pickPhoto(tester);
      harness.pendingJson = pending('user-1');
      harness.onLookup = (payload) async {
        expect(payload['requestId'], 'req-00000042');
        return _successMap;
      };
      await tester.tap(find.byKey(_runKey));
      await _settle(tester);
      expect(harness.payloads, isEmpty);

      await tester.tap(find.byKey(_runKey));
      await _settle(tester);
      expect(harness.lookups, 1);
      expect(harness.payloads, isEmpty);
      expect(find.text('Before'), findsNothing);
      expect(find.text('Set as wallpaper'), findsOneWidget);
    });

    testWidgets('rapid recovery retries start only one lookup and cannot replace the result with a stale reply', (
      tester,
    ) async {
      final _Harness harness = _Harness()..pendingJson = pending('user-1');
      harness.onLookup = (_) async => <String, Object?>{'state': 'running'};
      await _pumpPage(tester, harness);
      await _settle(tester);
      final VoidCallback retry = tester.widget<GlintState>(find.byType(GlintState)).onAction!;
      final Completer<Object?> reply = Completer<Object?>();
      harness.onLookup = (_) => reply.future;

      retry();
      retry();
      await tester.pump();
      expect(harness.lookups, 2);
      reply.complete(_successMap);
      await _settle(tester);
      expect(find.text('Set as wallpaper'), findsOneWidget);
    });

    testWidgets('a failed final clear is retried before starting over', (tester) async {
      final _Harness harness = _Harness()..pendingJson = pending('user-1');
      harness.onLookup = (_) async => _successMap;
      harness.onWrite = (_) async => throw StateError('disk full');
      await _pumpPage(tester, harness);
      await _settle(tester);
      expect(harness.pendingJson, isNotNull);
      harness.onWrite = null;

      await tester.tap(find.text('Use another photo'));
      await _settle(tester);
      expect(harness.pendingJson, isNull);
      await tester.tap(find.text('Use another photo'));
      await _settle(tester);
      expect(find.text('Choose a photo'), findsOneWidget);
      expect(harness.payloads, isEmpty);
    });

    testWidgets('an A-B-A switch during Live Activity startup cannot dispatch the old paid job', (tester) async {
      final _Harness harness = _Harness();
      final _ActivityApi activity = _ActivityApi();
      final PrismLiveActivityHostApi previousApi = LiveActivityChannel.api;
      final bool Function() previousSupported = LiveActivityChannel.isSupportedPlatform;
      LiveActivityChannel.api = activity;
      LiveActivityChannel.isSupportedPlatform = () => true;
      addTearDown(() {
        LiveActivityChannel.api = previousApi;
        LiveActivityChannel.isSupportedPlatform = previousSupported;
      });
      await _pumpPage(tester, harness);
      await _pickPhoto(tester);
      await tester.tap(find.byKey(_runKey));
      await tester.pump();
      harness.session.switchTo('user-2');
      harness.session.switchTo('user-1');
      activity.started.complete('activity-1');
      await _settle(tester);

      expect(harness.payloads, isEmpty);
      expect(activity.cancels, 1);
    });

    testWidgets('a restored desktop upscale has all actions and preserves mode, target and folder metadata', (
      tester,
    ) async {
      final _Harness harness = _Harness()
        ..pendingJson = jsonEncode(
          const PendingPhotoJob(
            userId: 'user-1',
            requestId: 'req-00000042',
            mode: PhotoJobMode.upscale,
            target: PhotoJobTarget.desktop,
          ).toJson(),
        );
      harness.onLookup = (_) async => <String, Object?>{..._successMap, 'width': 2560, 'height': 1600};
      final _Assets assets = _Assets();
      OfflineAssetStore.testOverride = assets;
      addTearDown(() => OfflineAssetStore.testOverride = null);
      await _pumpPage(tester, harness);
      await _settle(tester);
      expect(find.text('Before'), findsNothing);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Save to folder'), findsOneWidget);
      await tester.tap(find.text('Set as wallpaper'));
      await tester.pump();
      final PhotoJobResultSetEvent event = harness.analytics.events.whereType<PhotoJobResultSetEvent>().single;
      expect(event.toWireParameters(), <String, Object?>{
        'mode': 'upscale',
        'target': 'desktop',
        'platform': 'android',
      });
      expect(assets.resolves, 1);

      await tester.tap(find.text('Save to folder'));
      await tester.pump();
      await _settle(tester);
      final FolderSheet folder = tester.widget<FolderSheet>(find.byType(FolderSheet));
      final PrismFavouriteWall saved = folder.wall as PrismFavouriteWall;
      expect(saved.wallpaper.aiModel, PhotoJobMode.upscale.model);
      expect(saved.wallpaper.core.width, 2560);
      expect(saved.wallpaper.core.height, 1600);
      await tester.pumpWidget(const SizedBox());
      assets.download.complete(File('/tmp/unused-result.jpg'));
      await tester.pump();
    });

    testWidgets('stale Download and folder callbacks cannot act after an A-B-A session change', (tester) async {
      int downloads = 0;
      const BasicMessageChannel<Object?> downloadChannel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
        PrismMediaHostApi.pigeonChannelCodec,
      );
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(downloadChannel, (_) async {
        downloads++;
        return <Object?>[null];
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(downloadChannel, null),
      );
      final _Harness harness = _Harness()..pendingJson = pending('user-1');
      harness.onLookup = (_) async => _successMap;
      final _Assets assets = _Assets();
      OfflineAssetStore.testOverride = assets;
      addTearDown(() => OfflineAssetStore.testOverride = null);
      await _pumpPage(tester, harness);
      await _settle(tester);
      final PrismButton folder = tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Save to folder'));
      await tester.tap(find.text('Download'));
      await tester.pump();
      harness.session.switchTo('user-2');
      harness.session.switchTo('user-1');
      folder.onPressed!();
      assets.download.complete(File('/tmp/unused-result.jpg'));
      await _settle(tester);

      expect(find.byType(FolderSheet), findsNothing);
      expect(find.text('Set as wallpaper'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(downloads, 0);
    });

    testWidgets('switching accounts removes the old result pixels on the first frame', (tester) async {
      final _Harness harness = _Harness()..pendingJson = pending('user-1');
      harness.onLookup = (_) async => _successMap;
      await _pumpPage(tester, harness);
      await _settle(tester);
      expect(find.byType(AiDecodedImage), findsOneWidget);

      harness.session.switchTo('user-2');
      await tester.pump();

      expect(find.byType(AiDecodedImage), findsNothing);
    });
  });
}
