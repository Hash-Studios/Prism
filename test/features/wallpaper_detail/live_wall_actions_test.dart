import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/live_wall_actions.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

final AppLocalizationsEn l10n = AppLocalizationsEn();

const WallLive live = WallLive(videoUrl: 'https://cdn.example.com/wall.mp4');
final File video = File('/tmp/prism_live_test.mp4');

void captureToasts(WidgetTester tester, List<MethodCall> toasts) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (
    call,
  ) async {
    toasts.add(call);
    return true;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    ),
  );
}

bool toasted(List<MethodCall> toasts, String message) =>
    toasts.any((call) => call.method == 'showToast' && (call.arguments as Map)['msg'] == message);

Future<void> pumpWidget(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  setUp(() {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(AnalyticsRuntime.reset);

  group('LiveSetButton', () {
    for (final LiveApplyStatus status in LiveApplyStatus.values) {
      testWidgets('records a successful set only when the native result is $status', (tester) async {
        int recorded = 0;
        await pumpWidget(
          tester,
          LiveSetButton(
            live: live,
            wallId: 'wall-1',
            download: (_) async => video,
            apply: (_) async => LiveApplyOutcome(status),
            onSet: () => Future<void>.sync(() => recorded++),
          ),
        );

        await tester.tap(find.text(l10n.liveWallSetLive));
        await tester.pumpAndSettle();

        expect(recorded, status == LiveApplyStatus.applied ? 1 : 0);
      });
    }

    testWidgets('a failed accounting callback does not relabel a native success as failure', (tester) async {
      int recorded = 0;
      await pumpWidget(
        tester,
        LiveSetButton(
          live: live,
          wallId: 'wall-1',
          download: (_) async => video,
          apply: (_) async => const LiveApplyOutcome(LiveApplyStatus.applied),
          onSet: () {
            recorded++;
            return Future<void>.error(StateError('receipt unavailable'), StackTrace.empty);
          },
        ),
      );

      await tester.tap(find.text(l10n.liveWallSetLive));
      await tester.pumpAndSettle();

      expect(find.text(l10n.wallpaperLiveApplied), findsOneWidget);
      expect(find.text(l10n.liveWallSetFailed), findsNothing);
      expect(recorded, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an apply already started records the original wall after the button is disposed', (tester) async {
      final Completer<LiveApplyOutcome> pending = Completer<LiveApplyOutcome>();
      int recorded = 0;
      await pumpWidget(
        tester,
        LiveSetButton(
          live: live,
          wallId: 'wall-1',
          download: (_) async => video,
          apply: (_) => pending.future,
          onSet: () => Future<void>.sync(() => recorded++),
        ),
      );
      await tester.tap(find.text(l10n.liveWallSetLive));
      await tester.pump();
      await pumpWidget(tester, const SizedBox.shrink());

      pending.complete(const LiveApplyOutcome(LiveApplyStatus.applied));
      await tester.pumpAndSettle();

      expect(recorded, 1);
    });

    testWidgets('an apply already started records its original wall when the widget changes', (tester) async {
      final Completer<LiveApplyOutcome> pending = Completer<LiveApplyOutcome>();
      final List<String> recorded = <String>[];
      await pumpWidget(
        tester,
        LiveSetButton(
          live: live,
          wallId: 'wall-1',
          download: (_) async => video,
          apply: (_) => pending.future,
          onSet: () => Future<void>.sync(() => recorded.add('old')),
        ),
      );
      await tester.tap(find.text(l10n.liveWallSetLive));
      await tester.pump();
      await pumpWidget(
        tester,
        LiveSetButton(
          live: const WallLive(videoUrl: 'https://cdn.example.com/new.mp4'),
          wallId: 'wall-2',
          onSet: () => Future<void>.sync(() => recorded.add('new')),
        ),
      );

      pending.complete(const LiveApplyOutcome(LiveApplyStatus.applied));
      await tester.pumpAndSettle();

      expect(recorded, <String>['old']);
      expect(find.text(l10n.wallpaperLiveApplied), findsNothing);
    });

    testWidgets('does not apply a download after its button is disposed', (tester) async {
      final Completer<File> pending = Completer<File>();
      final List<String> applied = <String>[];
      await pumpWidget(
        tester,
        LiveSetButton(
          live: live,
          wallId: 'wall-1',
          download: (_) => pending.future,
          apply: (path) async {
            applied.add(path);
            return const LiveApplyOutcome(LiveApplyStatus.applied);
          },
        ),
      );
      await tester.tap(find.text(l10n.liveWallSetLive));
      await pumpWidget(tester, const SizedBox.shrink());

      pending.complete(video);
      await tester.pumpAndSettle();

      expect(applied, isEmpty);
    });

    testWidgets('changing walls ignores the old download and allows the new wall to apply', (tester) async {
      final Completer<File> pending = Completer<File>();
      final List<String> applied = <String>[];
      await pumpWidget(
        tester,
        LiveSetButton(
          live: live,
          wallId: 'wall-1',
          download: (_) => pending.future,
          apply: (path) async {
            applied.add('old:$path');
            return const LiveApplyOutcome(LiveApplyStatus.applied);
          },
        ),
      );
      await tester.tap(find.text(l10n.liveWallSetLive));
      await pumpWidget(
        tester,
        LiveSetButton(
          live: const WallLive(videoUrl: 'https://cdn.example.com/new.mp4'),
          wallId: 'wall-2',
          download: (_) async => File('/tmp/new.mp4'),
          apply: (path) async {
            applied.add('new:$path');
            return const LiveApplyOutcome(LiveApplyStatus.applied);
          },
        ),
      );
      pending.complete(video);
      await tester.pumpAndSettle();

      expect(applied, isEmpty);
      await tester.tap(find.text(l10n.liveWallSetLive));
      await tester.pumpAndSettle();
      expect(applied, <String>['new:/tmp/new.mp4']);
    });

    testWidgets('tap downloads the video, then applies the downloaded file', (tester) async {
      final List<String> calls = <String>[];
      await pumpWidget(
        tester,
        LiveSetButton(
          live: live,
          wallId: 'wall-1',
          download: (url) async {
            calls.add('download:$url');
            return video;
          },
          apply: (path) async {
            calls.add('apply:$path');
            return const LiveApplyOutcome(LiveApplyStatus.applied);
          },
        ),
      );

      await tester.tap(find.text(l10n.liveWallSetLive));
      await tester.pumpAndSettle();

      expect(calls, <String>['download:${live.videoUrl}', 'apply:${video.path}']);
    });

    testWidgets('run on its state starts the same flow as a tap', (tester) async {
      final GlobalKey<LiveSetButtonState> key = GlobalKey<LiveSetButtonState>();
      final List<String> calls = <String>[];
      await pumpWidget(
        tester,
        LiveSetButton(
          key: key,
          live: live,
          wallId: 'wall-1',
          download: (url) async {
            calls.add('download:$url');
            return video;
          },
          apply: (path) async {
            calls.add('apply:$path');
            return const LiveApplyOutcome(LiveApplyStatus.applied);
          },
        ),
      );

      unawaited(key.currentState!.run());
      await tester.pumpAndSettle();

      expect(calls, <String>['download:${live.videoUrl}', 'apply:${video.path}']);
    });

    testWidgets('shows the preparing text while the download is pending', (tester) async {
      final Completer<File> pending = Completer<File>();
      await pumpWidget(
        tester,
        LiveSetButton(
          live: live,
          wallId: 'wall-1',
          download: (_) => pending.future,
          apply: (_) async => const LiveApplyOutcome(LiveApplyStatus.applied),
        ),
      );

      await tester.tap(find.text(l10n.liveWallSetLive));
      await tester.pump();

      expect(find.text(l10n.liveWallPreparing), findsOneWidget);

      pending.complete(video);
      await tester.pumpAndSettle();
    });

    testWidgets('is disabled while the download is pending, so a screen reader does not offer a dead action', (
      tester,
    ) async {
      final Completer<File> pending = Completer<File>();
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpWidget(
        tester,
        LiveSetButton(
          live: live,
          wallId: 'wall-1',
          download: (_) => pending.future,
          apply: (_) async => const LiveApplyOutcome(LiveApplyStatus.applied),
        ),
      );

      await tester.tap(find.text(l10n.liveWallSetLive));
      await tester.pump();

      expect(
        tester.getSemantics(find.widgetWithText(FilledButton, l10n.liveWallPreparing)),
        matchesSemantics(
          label: l10n.liveWallPreparing,
          isButton: true,
          hasEnabledState: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );

      pending.complete(video);
      await tester.pumpAndSettle();
      semantics.dispose();
    });

    testWidgets('a download that throws shows the set failed message', (tester) async {
      await pumpWidget(
        tester,
        LiveSetButton(
          live: live,
          wallId: 'wall-1',
          download: (_) async => throw const HttpException('offline'),
          apply: (_) async => const LiveApplyOutcome(LiveApplyStatus.applied),
        ),
      );

      await tester.tap(find.text(l10n.liveWallSetLive));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't set the live wallpaper. Try again."), findsOneWidget);
    });
  });

  group('LiveSaveVideoButton', () {
    testWidgets('does not save a download after its button is disposed', (tester) async {
      final Completer<File> pending = Completer<File>();
      final List<String> saved = <String>[];
      await pumpWidget(
        tester,
        LiveSaveVideoButton(
          live: live,
          download: (_) => pending.future,
          save: (path) async {
            saved.add(path);
            return OperationResult(success: true);
          },
        ),
      );
      await tester.tap(find.text(l10n.liveWallSaveVideo));
      await pumpWidget(tester, const SizedBox.shrink());

      pending.complete(video);
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
    });

    testWidgets('changing videos does not save the old download as the new video', (tester) async {
      final List<MethodCall> toasts = <MethodCall>[];
      captureToasts(tester, toasts);
      final Completer<File> pending = Completer<File>();
      final List<String> saved = <String>[];
      await pumpWidget(
        tester,
        LiveSaveVideoButton(
          live: live,
          download: (_) => pending.future,
          save: (path) async {
            saved.add('old:$path');
            return OperationResult(success: true);
          },
        ),
      );
      await tester.tap(find.text(l10n.liveWallSaveVideo));
      await pumpWidget(
        tester,
        LiveSaveVideoButton(
          live: const WallLive(videoUrl: 'https://cdn.example.com/new.mp4'),
          download: (_) async => File('/tmp/new.mp4'),
          save: (path) async {
            saved.add('new:$path');
            return OperationResult(success: true);
          },
        ),
      );
      pending.complete(video);
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
      await tester.tap(find.text(l10n.liveWallSaveVideo));
      await tester.pumpAndSettle();
      expect(saved, <String>['new:/tmp/new.mp4']);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('tap saves the downloaded file and shows the saved message', (tester) async {
      final List<MethodCall> toasts = <MethodCall>[];
      captureToasts(tester, toasts);
      final List<String> saved = <String>[];
      await pumpWidget(
        tester,
        LiveSaveVideoButton(
          live: live,
          download: (_) async => video,
          save: (path) async {
            saved.add(path);
            return OperationResult(success: true);
          },
        ),
      );

      await tester.tap(find.text(l10n.liveWallSaveVideo));
      await tester.pumpAndSettle();

      expect(saved, <String>[video.path]);
      expect(toasted(toasts, 'Video saved to Photos.'), isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a failed save shows the save failed message', (tester) async {
      final List<MethodCall> toasts = <MethodCall>[];
      captureToasts(tester, toasts);
      await pumpWidget(
        tester,
        LiveSaveVideoButton(
          live: live,
          download: (_) async => video,
          save: (_) async => OperationResult(success: false, errorCode: 'permission-denied'),
        ),
      );

      await tester.tap(find.text(l10n.liveWallSaveVideo));
      await tester.pumpAndSettle();

      expect(toasted(toasts, "Couldn't save the video. Allow Photos access in Settings, then try again."), isTrue);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('LiveIosNote wraps at 2.0 text scale in a 320 wide box without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: Center(child: SizedBox(width: 320, child: LiveIosNote())),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.liveWallIosBody), findsOneWidget);
  });

  testWidgets('both buttons expose a button semantics node with their label', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpWidget(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LiveSetButton(live: live, wallId: 'wall-1'),
          LiveSaveVideoButton(live: live),
        ],
      ),
    );

    for (final String label in <String>[l10n.liveWallSetLive, l10n.liveWallSaveVideo]) {
      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.label, label);
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    }
    handle.dispose();
  });
}
