import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'wallpaper_position_event.j.dart';
part 'wallpaper_position_state.j.dart';
part 'wallpaper_position_bloc.j.freezed.dart';

@injectable
class WallpaperPositionBloc extends Bloc<WallpaperPositionEvent, WallpaperPositionState> {
  WallpaperPositionBloc(this._repository) : super(WallpaperPositionState.initial()) {
    on<_Started>(_onStarted);
    on<_FitChanged>(
      (event, emit) => emit(
        state.copyWith(
          placement: state.placement.copyWith(fit: event.fit),
          syncToken: state.syncToken + 1,
        ),
      ),
    );
    on<_Moved>(
      (event, emit) => emit(
        state.copyWith(
          placement: state.placement.copyWith(dx: event.dx, dy: event.dy, zoom: event.zoom),
        ),
      ),
    );
    on<_DimChanged>((event, emit) => emit(state.copyWith(placement: state.placement.copyWith(dim: event.dim))));
    on<_PreviewModeChanged>(
      (event, emit) => emit(state.copyWith(placement: state.placement.copyWith(previewMode: event.mode))),
    );
    on<_ResetRequested>(
      (event, emit) => emit(
        state.copyWith(
          placement: WallpaperPlacement(previewMode: state.placement.previewMode),
          syncToken: state.syncToken + 1,
        ),
      ),
    );
    on<_ApplyRequested>(_onApplyRequested);
  }

  final WallpaperPositionRepository _repository;
  String _imageUrl = '';
  String? _thumbnailUrl;

  Future<void> _onStarted(_Started event, Emitter<WallpaperPositionState> emit) async {
    _imageUrl = event.imageUrl;
    _thumbnailUrl = event.thumbnailUrl;
    emit(WallpaperPositionState.initial());
    unawaited(analytics.track(WallpaperPositionOpenedEvent(source: event.entryPoint ?? 'unknown')));
    try {
      final PlacementSource source = await _repository.load(event.imageUrl);
      if (isClosed) {
        source.image.dispose();
        return;
      }
      emit(state.copyWith(status: WallpaperPositionStatus.ready, source: source));
    } catch (error, stackTrace) {
      logger.w('WallpaperPositionBloc: could not load the wallpaper', error: error, stackTrace: stackTrace);
      if (!isClosed) emit(state.copyWith(status: WallpaperPositionStatus.failed));
    }
  }

  Future<void> _onApplyRequested(_ApplyRequested event, Emitter<WallpaperPositionState> emit) async {
    final PlacementSource? source = state.source;
    if (source == null || state.status != WallpaperPositionStatus.ready) return;
    final WallpaperPlacement placement = state.placement;
    emit(state.copyWith(status: WallpaperPositionStatus.applying));
    WallpaperSetResult result;
    File? file;
    try {
      file = await _repository.render(source, placement, event.outputSize);
      result = await WallpaperService.setWallpaper(
        file.path,
        event.target,
        historySource: _imageUrl,
        historyThumbnail: _thumbnailUrl,
      );
    } catch (error, stackTrace) {
      logger.e('WallpaperPositionBloc: could not set the wallpaper', error: error, stackTrace: stackTrace);
      result = const WallpaperSetResult(
        WallpaperSetStatus.failed,
        "Couldn't prepare the wallpaper. Try again.",
        errorCode: 'render_failed',
      );
    }
    // The plugin may still read the file while the system preview is open.
    if (file != null && !result.isInfo) await _repository.discard(file);
    _track(placement, event.target, result);
    if (isClosed) return;
    emit(state.copyWith(status: WallpaperPositionStatus.ready, result: result, resultToken: state.resultToken + 1));
  }

  void _track(WallpaperPlacement placement, WallpaperTarget target, WallpaperSetResult result) {
    if (!result.isSuccess && !result.isFailure) return;
    unawaited(
      analytics.track(
        WallpaperPlacementAppliedEvent(
          fit: placement.fit.name,
          zoomed: placement.isZoomed,
          dimBucket: placement.dimBucket,
          wallpaperTarget: target,
          result: result.isSuccess ? BinaryResultValue.success : BinaryResultValue.failure,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    state.source?.image.dispose();
    return super.close();
  }
}
