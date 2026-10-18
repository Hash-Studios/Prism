/// Where one chest is, from the first tap to the prize on screen. `spent` is a chest that was opened earlier today.
enum ChestPhase { ready, charging, opening, revealed, spent }

enum ChestPlayback {
  /// Plays the span again and again.
  loop,

  /// Plays the span once and holds its last frame.
  once,

  /// Shows the first frame of the span and does not tick.
  hold,
}

/// One named span of the box animation.
class ChestMarker {
  const ChestMarker(
    this.name, {
    required this.startFrame,
    required this.endFrame,
    required this.playback,
    this.burstFrame,
  });

  /// The marker name in the Lottie file.
  final String name;
  final int startFrame;
  final int endFrame;
  final ChestPlayback playback;

  /// The frame where the light leaves the box, if this span has one. The prize shows from here.
  final int? burstFrame;

  int get frames => endFrame - startFrame;
}

/// The frame rate and the length of `assets/lottie/daily_chest.json`, as `docs/features/daily-chest.md` fixes them.
const int chestFrameRate = 60;
const int chestTotalFrames = 392;

/// The timeline of the box. The box reads the real spans from the file's markers when it can and falls back to these.
const Map<ChestPhase, ChestMarker> chestMarkers = <ChestPhase, ChestMarker>{
  ChestPhase.ready: ChestMarker('idle', startFrame: 0, endFrame: 120, playback: ChestPlayback.loop),
  ChestPhase.charging: ChestMarker('charge', startFrame: 120, endFrame: 180, playback: ChestPlayback.loop),
  ChestPhase.opening: ChestMarker(
    'open',
    startFrame: 180,
    endFrame: 270,
    playback: ChestPlayback.once,
    burstFrame: 196,
  ),
  ChestPhase.revealed: ChestMarker('opened', startFrame: 270, endFrame: 390, playback: ChestPlayback.loop),
  ChestPhase.spent: ChestMarker('spent', startFrame: 390, endFrame: 392, playback: ChestPlayback.hold),
};

/// The phase whose first frame a box shows when it does not animate: the row icon and reduced motion.
ChestPhase chestStillPhase(ChestPhase phase) => switch (phase) {
  ChestPhase.ready || ChestPhase.charging => ChestPhase.ready,
  ChestPhase.opening || ChestPhase.revealed => ChestPhase.revealed,
  ChestPhase.spent => ChestPhase.spent,
};
