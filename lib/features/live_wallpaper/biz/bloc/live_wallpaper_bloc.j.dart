import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_screens.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/features/live_wallpaper/domain/repositories/live_wallpaper_repository.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_wallpaper_event.j.dart';
part 'live_wallpaper_state.j.dart';
part 'live_wallpaper_bloc.j.freezed.dart';

class LiveWallpaperBloc extends Bloc<LiveWallpaperEvent, LiveWallpaperState> {
  LiveWallpaperBloc(this._repository, {this.imageUrl, this.depthMapUrl}) : super(LiveWallpaperState.initial()) {
    on<LiveWallpaperEvent>(
      (event, emit) => event.map<Future<void>>(
        started: (event) => _onStarted(event, emit),
        proChanged: (event) async => emit(state.copyWith(isPro: event.isPro)),
        unlockedStylesChanged: (event) async => emit(state.copyWith(unlockedStyles: event.unlockedStyles)),
        motionSelected: (event) async {
          if (!event.style.needsDepthMap || depthMapUrl != null) emit(state.copyWith(motionStyle: event.style));
        },
        gradientSelected: (event) async => emit(state.copyWith(gradientStyle: event.style)),
        batterySaverChanged: (event) async => emit(state.copyWith(batterySaver: event.enabled)),
        targetSelected: (event) async => emit(state.copyWith(target: event.target)),
        screensChecked: (event) => _onScreensChecked(emit),
        otherScreenPicked: (event) async {
          if (imageUrl != null) _repository.nextTarget = event.screen;
          emit(state.copyWith(target: event.screen));
        },
        motionApplied: (event) => _onMotionApplied(event, emit),
        gradientApplied: (event) => _onGradientApplied(event, emit),
        videoPicked: (event) => _onVideoPicked(event, emit),
        videoApplied: (event) => _onVideoApplied(emit),
        outcomeHandled: (event) async => emit(state.copyWith(outcome: null)),
      ),
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    if (getIt.isRegistered<SessionRepository>()) {
      String? previousOwner = _currentOwner;
      _session = getIt<SessionRepository>().watchCurrentUser().listen((user) {
        final String? owner = user.loggedIn ? user.id : null;
        if (owner != previousOwner) {
          _sessionRevision++;
          previousOwner = owner;
        }
      });
    }
  }

  final LiveWallpaperRepository _repository;
  StreamSubscription<Object?>? _session;
  int _sessionRevision = 0;
  int? _pendingSessionRevision;
  String? _pendingOwner;
  final String? imageUrl;

  /// The wall's depth map. Without it the 3D style is not offered.
  final String? depthMapUrl;

  @override
  Future<void> close() async {
    await _session?.cancel();
    await super.close();
  }

  Future<void> _onStarted(_Started event, Emitter<LiveWallpaperState> emit) async {
    _pendingOwner = null;
    emit(
      state.copyWith(
        isPro: event.isPro,
        unlockedStyles: event.unlockedStyles,
        status: LiveWallpaperStatus.loading,
        outcome: null,
        pendingTag: null,
      ),
    );
    LiveCapabilities capabilities;
    try {
      capabilities = await _repository.getCapabilities();
    } catch (_) {
      capabilities = LiveCapabilities.none;
    }
    final WallpaperTarget? next = _repository.nextTarget;
    _repository.nextTarget = null;
    emit(
      state.copyWith(
        capabilities: capabilities,
        status: capabilities.isSupported ? LiveWallpaperStatus.ready : LiveWallpaperStatus.unsupported,
        target: capabilities.supportsPerScreen ? next ?? WallpaperTarget.both : WallpaperTarget.home,
      ),
    );
  }

  /// Without per-screen support the screen hides the choice and keeps the plugin's default, Home.
  WallpaperTarget get _applyTarget => state.capabilities.supportsPerScreen ? state.target : WallpaperTarget.home;

  LiveContentTag _newTag(Enum style) =>
      LiveContentTag(style: style, applyId: DateTime.now().microsecondsSinceEpoch.toRadixString(36));

  String? get _currentOwner => app_state.prismUser.loggedIn ? app_state.prismUser.id : null;

  /// Remembers a per-screen apply until the user is back from the preview and the screens can be read.
  LiveContentTag? _pendingFor(LiveApplyOutcome outcome, LiveContentTag tag, String? owner) {
    final bool pending =
        owner != null && state.capabilities.supportsPerScreen && outcome.status == LiveApplyStatus.confirmInPreview;
    _pendingOwner = pending ? owner : null;
    _pendingSessionRevision = pending ? _sessionRevision : null;
    return pending ? tag : null;
  }

  Future<void> _onScreensChecked(Emitter<LiveWallpaperState> emit) async {
    final LiveContentTag? tag = state.pendingTag;
    if (tag == null) return;
    final String? owner = _pendingOwner;
    if (owner == null || owner != _currentOwner || _pendingSessionRevision != _sessionRevision) {
      _pendingOwner = null;
      emit(state.copyWith(pendingTag: null, outcome: null));
      return;
    }
    LiveScreens screens;
    try {
      screens = await _repository.getScreens();
    } catch (_) {
      screens = LiveScreens.unknown;
    }
    final WallpaperTarget? landed = owner == _currentOwner && _pendingSessionRevision == _sessionRevision
        ? screens.screensShowing(tag)
        : null;
    _pendingOwner = null;
    emit(
      state.copyWith(
        pendingTag: null,
        outcome: landed == null ? null : LiveApplyOutcome.screensSet(target: landed, screens: screens),
      ),
    );
  }

  Future<void> _onMotionApplied(_MotionApplied event, Emitter<LiveWallpaperState> emit) async {
    final String? url = imageUrl;
    if (state.applying || url == null) return;
    if (state.isLocked(state.motionStyle.name, isFree: state.motionStyle.isFree)) {
      emit(state.copyWith(outcome: const LiveApplyOutcome.proRequired()));
      return;
    }
    final String? owner = _currentOwner;
    final int sessionRevision = _sessionRevision;
    _pendingOwner = null;
    emit(state.copyWith(applying: true, pendingTag: null));
    final LiveContentTag tag = _newTag(state.motionStyle);
    final WallpaperTarget target = _applyTarget;
    final LiveApplyOutcome outcome = await _repository.applyMotion(
      imageUrl: url,
      style: state.motionStyle,
      palette: event.palette,
      screenAspectRatio: event.screenAspectRatio,
      batterySaver: state.batterySaver,
      target: target,
      tag: tag,
      depthMapUrl: depthMapUrl,
      tilt: state.capabilities.supportsTilt,
    );
    if (owner != _currentOwner || sessionRevision != _sessionRevision) {
      emit(state.copyWith(applying: false, outcome: null, pendingTag: null));
      return;
    }
    _trackApplied(_motionAnalytics(state.motionStyle), outcome, target: target);
    emit(state.copyWith(applying: false, outcome: outcome, pendingTag: _pendingFor(outcome, tag, owner)));
  }

  void _trackApplied(LiveWallpaperStyleValue style, LiveApplyOutcome outcome, {WallpaperTarget? target}) {
    analytics.track(
      LiveWallpaperAppliedEvent(
        style: style,
        result: outcome.status.name,
        target: target,
        perScreen: target != null && state.capabilities.supportsPerScreen,
        fallback: outcome.fallback,
      ),
    );
  }

  static LiveWallpaperStyleValue _motionAnalytics(MotionStyle style) => switch (style) {
    MotionStyle.drift => LiveWallpaperStyleValue.drift,
    MotionStyle.breathe => LiveWallpaperStyleValue.breathe,
    MotionStyle.ripple => LiveWallpaperStyleValue.ripple,
    MotionStyle.shimmer => LiveWallpaperStyleValue.shimmer,
    MotionStyle.depth => LiveWallpaperStyleValue.threeD,
  };

  static LiveWallpaperStyleValue _gradientAnalytics(GradientStyle style) => switch (style) {
    GradientStyle.aurora => LiveWallpaperStyleValue.aurora,
    GradientStyle.mesh => LiveWallpaperStyleValue.mesh,
    GradientStyle.waves => LiveWallpaperStyleValue.waves,
    GradientStyle.plasma => LiveWallpaperStyleValue.plasma,
    GradientStyle.starfield => LiveWallpaperStyleValue.starfield,
  };

  Future<void> _onGradientApplied(_GradientApplied event, Emitter<LiveWallpaperState> emit) async {
    if (state.applying) return;
    if (state.isLocked(state.gradientStyle.name, isFree: state.gradientStyle.isFree)) {
      emit(state.copyWith(outcome: const LiveApplyOutcome.proRequired()));
      return;
    }
    final String? owner = _currentOwner;
    final int sessionRevision = _sessionRevision;
    _pendingOwner = null;
    emit(state.copyWith(applying: true, pendingTag: null));
    final LiveContentTag tag = _newTag(state.gradientStyle);
    final WallpaperTarget target = _applyTarget;
    final LiveApplyOutcome outcome = await _repository.applyGradient(
      style: state.gradientStyle,
      palette: event.palette,
      batterySaver: state.batterySaver,
      target: target,
      tag: tag,
    );
    if (owner != _currentOwner || sessionRevision != _sessionRevision) {
      emit(state.copyWith(applying: false, outcome: null, pendingTag: null));
      return;
    }
    _trackApplied(_gradientAnalytics(state.gradientStyle), outcome, target: target);
    emit(state.copyWith(applying: false, outcome: outcome, pendingTag: _pendingFor(outcome, tag, owner)));
  }

  Future<void> _onVideoPicked(_VideoPicked event, Emitter<LiveWallpaperState> emit) async {
    final LiveApplyFailure? problem = await _repository.validateVideo(event.path);
    if (problem != null) {
      emit(state.copyWith(videoPath: null, outcome: LiveApplyOutcome.failed(problem)));
      return;
    }
    emit(state.copyWith(videoPath: event.path));
  }

  Future<void> _onVideoApplied(Emitter<LiveWallpaperState> emit) async {
    final String? path = state.videoPath;
    if (state.applying || path == null) return;
    emit(state.copyWith(applying: true, pendingTag: null));
    final LiveApplyOutcome applied = await _repository.applyVideo(path);
    final LiveApplyOutcome outcome = LiveApplyOutcome(applied.status, failure: applied.failure);
    _trackApplied(LiveWallpaperStyleValue.video, outcome);
    emit(state.copyWith(applying: false, outcome: outcome));
  }
}
