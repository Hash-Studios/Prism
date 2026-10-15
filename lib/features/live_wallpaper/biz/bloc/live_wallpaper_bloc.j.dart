import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/features/live_wallpaper/domain/repositories/live_wallpaper_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_wallpaper_event.j.dart';
part 'live_wallpaper_state.j.dart';
part 'live_wallpaper_bloc.j.freezed.dart';

class LiveWallpaperBloc extends Bloc<LiveWallpaperEvent, LiveWallpaperState> {
  LiveWallpaperBloc(this._repository, {this.imageUrl}) : super(LiveWallpaperState.initial()) {
    on<LiveWallpaperEvent>(
      (event, emit) => event.map<Future<void>>(
        started: (event) => _onStarted(event, emit),
        proChanged: (event) async => emit(state.copyWith(isPro: event.isPro)),
        motionSelected: (event) async => emit(state.copyWith(motionStyle: event.style)),
        gradientSelected: (event) async => emit(state.copyWith(gradientStyle: event.style)),
        batterySaverChanged: (event) async => emit(state.copyWith(batterySaver: event.enabled)),
        motionApplied: (event) => _onMotionApplied(event, emit),
        gradientApplied: (event) => _onGradientApplied(event, emit),
        videoPicked: (event) => _onVideoPicked(event, emit),
        videoApplied: (event) => _onVideoApplied(emit),
        outcomeHandled: (event) async => emit(state.copyWith(outcome: null)),
      ),
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final LiveWallpaperRepository _repository;
  final String? imageUrl;

  Future<void> _onStarted(_Started event, Emitter<LiveWallpaperState> emit) async {
    emit(state.copyWith(isPro: event.isPro, status: LiveWallpaperStatus.loading));
    LiveCapabilities capabilities;
    try {
      capabilities = await _repository.getCapabilities();
    } catch (_) {
      capabilities = LiveCapabilities.none;
    }
    emit(
      state.copyWith(
        capabilities: capabilities,
        status: capabilities.isSupported ? LiveWallpaperStatus.ready : LiveWallpaperStatus.unsupported,
      ),
    );
  }

  Future<void> _onMotionApplied(_MotionApplied event, Emitter<LiveWallpaperState> emit) async {
    final String? url = imageUrl;
    if (state.applying || url == null) return;
    if (!state.isPro && !state.motionStyle.isFree) {
      emit(state.copyWith(outcome: const LiveApplyOutcome.proRequired()));
      return;
    }
    emit(state.copyWith(applying: true));
    final LiveApplyOutcome outcome = await _repository.applyMotion(
      imageUrl: url,
      style: state.motionStyle,
      palette: event.palette,
      screenAspectRatio: event.screenAspectRatio,
      batterySaver: state.batterySaver,
    );
    _trackApplied(state.motionStyle.name, outcome);
    emit(state.copyWith(applying: false, outcome: outcome));
  }

  void _trackApplied(String style, LiveApplyOutcome outcome) {
    analytics.track(LiveWallpaperAppliedEvent(style: style, result: outcome.status.name));
  }

  Future<void> _onGradientApplied(_GradientApplied event, Emitter<LiveWallpaperState> emit) async {
    if (state.applying) return;
    if (!state.isPro && !state.gradientStyle.isFree) {
      emit(state.copyWith(outcome: const LiveApplyOutcome.proRequired()));
      return;
    }
    emit(state.copyWith(applying: true));
    final LiveApplyOutcome outcome = await _repository.applyGradient(
      style: state.gradientStyle,
      palette: event.palette,
      batterySaver: state.batterySaver,
    );
    _trackApplied(state.gradientStyle.name, outcome);
    emit(state.copyWith(applying: false, outcome: outcome));
  }

  Future<void> _onVideoPicked(_VideoPicked event, Emitter<LiveWallpaperState> emit) async {
    final String? problem = await _repository.validateVideo(event.path);
    if (problem != null) {
      emit(state.copyWith(videoPath: null, outcome: LiveApplyOutcome.failed(problem)));
      return;
    }
    emit(state.copyWith(videoPath: event.path));
  }

  Future<void> _onVideoApplied(Emitter<LiveWallpaperState> emit) async {
    final String? path = state.videoPath;
    if (state.applying || path == null) return;
    emit(state.copyWith(applying: true));
    final LiveApplyOutcome outcome = await _repository.applyVideo(path);
    _trackApplied('video', outcome);
    emit(state.copyWith(applying: false, outcome: outcome));
  }
}
