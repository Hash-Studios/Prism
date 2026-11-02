import 'dart:ui' show Color, Size;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_photo/domain/repositories/live_photo_repository.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_photo_event.j.dart';
part 'live_photo_state.j.dart';
part 'live_photo_bloc.j.freezed.dart';

class LivePhotoBloc extends Bloc<LivePhotoEvent, LivePhotoState> {
  LivePhotoBloc(
    this._repository, {
    required this.wallId,
    required this.resolveSource,
    required bool isPro,
    this.depthMapUrl,
    Map<String, DateTime> unlockedStyles = const <String, DateTime>{},
  }) : super(
         LivePhotoState(
           phase: LivePhotoPhase.picking,
           styles: livePhotoStylesFor(hasDepthMap: depthMapUrl != null),
           style: MotionStyle.drift,
           isPro: isPro,
           unlockedStyles: unlockedStyles,
         ),
       ) {
    on<_StyleSelected>((event, emit) {
      if (state.phase == LivePhotoPhase.picking && state.styles.contains(event.style)) {
        emit(state.copyWith(style: event.style));
      }
    });
    on<_AccessChanged>((event, emit) => emit(state.copyWith(isPro: event.isPro, unlockedStyles: event.unlockedStyles)));
    on<_ExportRequested>(_onExport);
    on<_Progressed>((event, emit) {
      if (state.phase == LivePhotoPhase.exporting) emit(state.copyWith(progress: event.fraction));
    });
    on<_CancelRequested>(_onCancel);
    on<_Reset>((event, emit) {
      if (state.phase != LivePhotoPhase.exporting) emit(state.copyWith(phase: LivePhotoPhase.picking, outcome: null));
    });
  }

  final LivePhotoRepository _repository;
  final String wallId;
  final String? depthMapUrl;

  /// The wall the user may export, after sign-in and any consent. Null when the user stopped. Runs until it gives a
  /// source.
  final Future<String?> Function() resolveSource;
  Future<String?>? _source;

  Future<void> _onExport(_ExportRequested event, Emitter<LivePhotoState> emit) async {
    if (state.phase != LivePhotoPhase.picking || state.isLocked(state.style)) return;
    final MotionStyle style = state.style;
    final LiveWallpaperStyleValue styleValue = _styleValue(style);
    emit(state.copyWith(phase: LivePhotoPhase.exporting, progress: 0, cancelling: false, outcome: null));
    analytics.track(LivePhotoExportStartedEvent(style: styleValue));
    final String? source;
    try {
      source = await (_source ??= resolveSource());
    } catch (_) {
      _source = null;
      analytics.track(LivePhotoExportFailedEvent(style: styleValue, reason: 'source_unavailable'));
      emit(
        state.copyWith(
          phase: LivePhotoPhase.failed,
          cancelling: false,
          outcome: const LiveExportFailed(LiveExportFailure.sourceUnavailable),
        ),
      );
      return;
    }
    if (source == null) {
      _source = null;
      analytics.track(LivePhotoExportCancelledEvent(style: styleValue));
      emit(state.copyWith(phase: LivePhotoPhase.picking, cancelling: false));
      return;
    }
    if (state.cancelling) {
      analytics.track(LivePhotoExportCancelledEvent(style: styleValue));
      emit(state.copyWith(phase: LivePhotoPhase.picking, cancelling: false));
      return;
    }
    final LiveExport export = LiveExport(wallId: wallId, style: style, sizePx: event.sizePx);
    final LiveExportOutcome outcome = await _repository.export(
      export,
      imageUrl: source,
      tint: event.tint,
      depthMapUrl: depthMapUrl,
      onProgress: (fraction) {
        if (!isClosed) add(LivePhotoEvent.progressed(fraction));
      },
    );
    switch (outcome) {
      case LiveExportSaved():
        analytics.track(LivePhotoExportDoneEvent(style: styleValue, durationMs: export.duration.inMilliseconds));
        emit(state.copyWith(phase: LivePhotoPhase.saved, progress: 1, cancelling: false, outcome: outcome));
      case LiveExportCancelled():
        analytics.track(LivePhotoExportCancelledEvent(style: styleValue));
        emit(state.copyWith(phase: LivePhotoPhase.picking, cancelling: false, outcome: null));
      case LiveExportRefused(:final bool restricted):
        analytics.track(
          LivePhotoExportFailedEvent(
            style: styleValue,
            reason: restricted ? 'permission_restricted' : 'permission_denied',
          ),
        );
        emit(state.copyWith(phase: LivePhotoPhase.refused, cancelling: false, outcome: outcome));
      case LiveExportTimedOut():
        analytics.track(LivePhotoExportFailedEvent(style: styleValue, reason: 'timed_out'));
        emit(state.copyWith(phase: LivePhotoPhase.failed, cancelling: false, outcome: outcome));
      case LiveExportFailed(:final LiveExportFailure reason):
        analytics.track(LivePhotoExportFailedEvent(style: styleValue, reason: _snakeCase(reason.name)));
        emit(state.copyWith(phase: LivePhotoPhase.failed, cancelling: false, outcome: outcome));
    }
  }

  Future<void> _onCancel(_CancelRequested event, Emitter<LivePhotoState> emit) async {
    if (state.phase != LivePhotoPhase.exporting || state.cancelling) return;
    emit(state.copyWith(cancelling: true));
    await _repository.cancel();
  }

  @override
  Future<void> close() async {
    if (state.phase == LivePhotoPhase.exporting) await _repository.cancel();
    return super.close();
  }

  static LiveWallpaperStyleValue _styleValue(MotionStyle style) => switch (style) {
    MotionStyle.drift => LiveWallpaperStyleValue.drift,
    MotionStyle.breathe => LiveWallpaperStyleValue.breathe,
    MotionStyle.ripple => LiveWallpaperStyleValue.ripple,
    MotionStyle.shimmer => LiveWallpaperStyleValue.shimmer,
    MotionStyle.depth => LiveWallpaperStyleValue.threeD,
  };

  static String _snakeCase(String name) =>
      name.replaceAllMapped(RegExp('[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}');
}
