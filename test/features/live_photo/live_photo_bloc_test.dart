import 'dart:async';
import 'dart:ui' show Color, Size;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/live_photo/biz/bloc/live_photo_bloc.j.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import 'fake_live_photo_repository.dart';

const String _source = 'https://example.com/source.jpg';
const Color _tint = Color(0xFFE57697);
const Size _phone = Size(1179, 2556);

void main() {
  late FakeLivePhotoRepository repository;
  late FakeAppAnalytics analytics;

  setUp(() {
    repository = FakeLivePhotoRepository();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(AnalyticsRuntime.reset);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  LivePhotoBloc build({
    bool isPro = true,
    String? depthMapUrl,
    Map<String, DateTime> unlockedStyles = const <String, DateTime>{},
    Future<String?> Function()? resolveSource,
    bool Function(MotionStyle)? canExport,
  }) {
    final LivePhotoBloc bloc = LivePhotoBloc(
      repository,
      wallId: 'wall-1',
      canExport: canExport,
      resolveSource: resolveSource ?? () async => _source,
      isPro: isPro,
      depthMapUrl: depthMapUrl,
      unlockedStyles: unlockedStyles,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  void requestExport(LivePhotoBloc bloc) {
    bloc.add(const LivePhotoEvent.styleSelected(MotionStyle.breathe));
    bloc.add(const LivePhotoEvent.exportRequested(sizePx: _phone, tint: _tint));
  }

  group('styles', () {
    test('without a depth map, the styles are drift, breathe and shimmer', () {
      final LivePhotoBloc bloc = build();
      expect(bloc.state.styles, <MotionStyle>[MotionStyle.drift, MotionStyle.breathe, MotionStyle.shimmer]);
    });

    test('with a depth map, the styles add depth', () {
      final LivePhotoBloc bloc = build(depthMapUrl: 'https://example.com/depth.png');
      expect(bloc.state.styles, <MotionStyle>[
        MotionStyle.drift,
        MotionStyle.breathe,
        MotionStyle.shimmer,
        MotionStyle.depth,
      ]);
    });
  });

  test('a locked style does not export and stays on the picker', () async {
    final LivePhotoBloc bloc = build(isPro: false);
    requestExport(bloc);
    await settle();

    expect(repository.exports, isEmpty);
    expect(bloc.state.phase, LivePhotoPhase.picking);
  });

  group('export', () {
    test('a Pro user exports breathe and saves it', () async {
      final LivePhotoBloc bloc = build();
      requestExport(bloc);
      await settle();

      expect(bloc.state.phase, LivePhotoPhase.exporting);
      expect(repository.exports, hasLength(1));
      expect(repository.exports.single.style, MotionStyle.breathe);
      expect(repository.exports.single.sizePx, _phone);
      expect(repository.exports.single.duration, const Duration(seconds: 3));
      expect(repository.imageUrls.single, _source);

      repository.lastOnProgress!(0.5);
      await settle();
      expect(bloc.state.progress, 0.5);

      repository.complete(const LiveExportSaved(assetId: 'a', verified: true));
      await settle();
      expect(bloc.state.phase, LivePhotoPhase.saved);
      expect(bloc.state.progress, 1);
      expect(
        bloc.state.outcome,
        isA<LiveExportSaved>()
            .having((LiveExportSaved outcome) => outcome.assetId, 'assetId', 'a')
            .having((LiveExportSaved outcome) => outcome.verified, 'verified', true),
      );
    });

    test('a refusal gives the refused phase, and reset returns to the picker', () async {
      final LivePhotoBloc bloc = build();
      requestExport(bloc);
      await settle();

      repository.complete(const LiveExportRefused(restricted: true));
      await settle();
      expect(bloc.state.phase, LivePhotoPhase.refused);
      expect(
        bloc.state.outcome,
        isA<LiveExportRefused>().having((LiveExportRefused outcome) => outcome.restricted, 'restricted', true),
      );

      bloc.add(const LivePhotoEvent.reset());
      await settle();
      expect(bloc.state.phase, LivePhotoPhase.picking);
    });

    test('a timeout gives the failed phase', () async {
      final LivePhotoBloc bloc = build();
      requestExport(bloc);
      await settle();

      repository.complete(const LiveExportTimedOut());
      await settle();
      expect(bloc.state.phase, LivePhotoPhase.failed);
      expect(bloc.state.outcome, isA<LiveExportTimedOut>());
    });

    test('a null source returns to the picker without exporting', () async {
      final LivePhotoBloc bloc = build(resolveSource: () async => null);
      requestExport(bloc);
      await settle();

      expect(bloc.state.phase, LivePhotoPhase.picking);
      expect(repository.exports, isEmpty);
    });

    test('a source that throws gives the failed phase with sourceUnavailable', () async {
      final LivePhotoBloc bloc = build(resolveSource: () async => throw StateError('no wall'));
      requestExport(bloc);
      await settle();

      expect(bloc.state.phase, LivePhotoPhase.failed);
      expect(
        bloc.state.outcome,
        isA<LiveExportFailed>().having(
          (LiveExportFailed outcome) => outcome.reason,
          'reason',
          LiveExportFailure.sourceUnavailable,
        ),
      );
      expect(repository.exports, isEmpty);
    });

    test('each export rechecks source access after reset', () async {
      int resolveCalls = 0;
      final LivePhotoBloc bloc = build(
        resolveSource: () async {
          resolveCalls++;
          return _source;
        },
      );

      requestExport(bloc);
      await settle();
      repository.complete(const LiveExportSaved(assetId: 'first', verified: null));
      await settle();
      bloc.add(const LivePhotoEvent.reset());
      await settle();

      requestExport(bloc);
      await settle();
      repository.complete(const LiveExportSaved(assetId: 'second', verified: null));
      await settle();

      expect(bloc.state.phase, LivePhotoPhase.saved);
      expect(repository.exports, hasLength(2));
      expect(resolveCalls, 2);
    });

    test('current access is checked before resolving a source', () async {
      int resolveCalls = 0;
      final LivePhotoBloc bloc = build(
        canExport: (_) => false,
        resolveSource: () async {
          resolveCalls++;
          return _source;
        },
      );
      requestExport(bloc);
      await settle();

      expect(resolveCalls, 0);
      expect(repository.exports, isEmpty);
      expect(bloc.state.phase, LivePhotoPhase.picking);
    });

    test('account or wall access lost during consent prevents export', () async {
      bool allowed = true;
      final Completer<String?> source = Completer<String?>();
      final LivePhotoBloc bloc = build(resolveSource: () => source.future, canExport: (_) => allowed);
      requestExport(bloc);
      await settle();
      allowed = false;
      source.complete(_source);
      await settle();

      expect(repository.exports, isEmpty);
      expect(bloc.state.phase, LivePhotoPhase.picking);
    });

    test('a paid style locked during consent never reaches the repository', () async {
      final Completer<String?> source = Completer<String?>();
      final LivePhotoBloc bloc = build(resolveSource: () => source.future);
      requestExport(bloc);
      await settle();
      bloc.add(const LivePhotoEvent.accessChanged(isPro: false, unlockedStyles: <String, DateTime>{}));
      await settle();
      source.complete(_source);
      await settle();

      expect(repository.exports, isEmpty);
      expect(bloc.state.phase, LivePhotoPhase.picking);
    });

    test('losing a paid style during export cancels the native work', () async {
      final LivePhotoBloc bloc = build();
      requestExport(bloc);
      await settle();
      bloc.add(const LivePhotoEvent.accessChanged(isPro: false, unlockedStyles: <String, DateTime>{}));
      await settle();

      expect(repository.cancelCount, 1);
      expect(bloc.state.phase, LivePhotoPhase.picking);
    });

    test('closing during consent cannot start an export afterwards', () async {
      final Completer<String?> source = Completer<String?>();
      final LivePhotoBloc bloc = build(resolveSource: () => source.future);
      requestExport(bloc);
      await settle();
      final Future<void> closing = bloc.close();
      source.complete(_source);
      await closing;

      expect(repository.exports, isEmpty);
    });

    test('progress from an earlier export cannot update a retry', () async {
      final LivePhotoBloc bloc = build();
      requestExport(bloc);
      await settle();
      final void Function(double) oldProgress = repository.lastOnProgress!;
      repository.complete(const LiveExportFailed(LiveExportFailure.encodeFailed));
      await settle();
      bloc.add(const LivePhotoEvent.reset());
      await settle();
      requestExport(bloc);
      await settle();

      oldProgress(0.9);
      await settle();
      expect(bloc.state.progress, 0);
      repository.lastOnProgress!(0.4);
      await settle();
      expect(bloc.state.progress, 0.4);
      repository.complete(const LiveExportCancelled());
      await settle();
    });

    test('cancel stops the export and returns to the picker', () async {
      final LivePhotoBloc bloc = build();
      final List<LivePhotoState> states = <LivePhotoState>[];
      final StreamSubscription<LivePhotoState> subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);

      requestExport(bloc);
      await settle();

      bloc.add(const LivePhotoEvent.cancelRequested());
      await settle();

      expect(states.any((LivePhotoState state) => state.phase == LivePhotoPhase.exporting && state.cancelling), isTrue);
      expect(repository.cancelCount, 1);
      expect(bloc.state.phase, LivePhotoPhase.picking);
      expect(bloc.state.cancelling, isFalse);
    });

    test('a saved export tracks started then done with its duration', () async {
      final LivePhotoBloc bloc = build();
      requestExport(bloc);
      await settle();
      repository.complete(const LiveExportSaved(assetId: 'a', verified: true));
      await settle();

      expect(analytics.events.map((AnalyticsEvent event) => event.eventName).toList(), <String>[
        'live_photo_export_started',
        'live_photo_export_done',
      ]);
      expect(analytics.events.first.toWireParameters(), <String, Object?>{'style': 'breathe'});
      expect(analytics.events.last.toWireParameters(), <String, Object?>{'style': 'breathe', 'duration_ms': 3000});
    });

    test('a cancel tracks live_photo_export_cancelled', () async {
      final LivePhotoBloc bloc = build();
      requestExport(bloc);
      await settle();
      bloc.add(const LivePhotoEvent.cancelRequested());
      await settle();

      expect(analytics.events.last.eventName, 'live_photo_export_cancelled');
      expect(analytics.events.last.toWireParameters(), <String, Object?>{'style': 'breathe'});
    });

    test('a refusal tracks live_photo_export_failed with permission_restricted', () async {
      final LivePhotoBloc bloc = build();
      requestExport(bloc);
      await settle();
      repository.complete(const LiveExportRefused(restricted: true));
      await settle();

      expect(analytics.events.last.eventName, 'live_photo_export_failed');
      expect(analytics.events.last.toWireParameters(), <String, Object?>{
        'style': 'breathe',
        'reason': 'permission_restricted',
      });
    });
  });
}
