import 'package:audioplayers/audioplayers.dart';

class AppSoundManager {
  AppSoundManager._();

  static final AppSoundManager instance = AppSoundManager._();

  static const String _onboardingSwooshAsset = 'sounds/onboarding_open_candidate_a.mp3';
  static const double _onboardingSwooshVolume = 0.07;

  // Media-mode player for the onboarding fade: lowLatency does not
  // support setVolume reliably on Android.
  final AudioPlayer _fadePlayer = AudioPlayer();
  bool _fadePlayerConfigured = false;
  int _fadeRunId = 0;

  Future<void> playOnboardingSwoosh({double volume = _onboardingSwooshVolume}) async {
    try {
      await _playWithFade(assetPath: _onboardingSwooshAsset, startVolume: volume);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _fadePlayer.dispose();
  }

  Future<void> _ensureFadePlayerConfigured() async {
    if (_fadePlayerConfigured) {
      return;
    }
    await _fadePlayer.setReleaseMode(ReleaseMode.stop);
    await _fadePlayer.setPlayerMode(PlayerMode.mediaPlayer);
    _fadePlayerConfigured = true;
  }

  Future<void> _playWithFade({required String assetPath, required double startVolume}) async {
    await _ensureFadePlayerConfigured();
    final runId = ++_fadeRunId;
    await _fadePlayer.stop();
    await _fadePlayer.play(AssetSource(assetPath), volume: startVolume);

    // Hold at full volume for the first 2 s, then fade out over the remaining 2 s.
    const holdMs = 2000;
    const fadeMs = 2000;
    const steps = 24;
    final stepDelay = Duration(milliseconds: fadeMs ~/ steps);

    await Future<void>.delayed(const Duration(milliseconds: holdMs));

    for (var i = 1; i <= steps; i++) {
      if (runId != _fadeRunId) {
        return;
      }
      await Future<void>.delayed(stepDelay);
      final t = i / steps;
      // Ease-out curve so the fade feels smooth rather than cutting abruptly.
      final eased = (1 - t) * (1 - t);
      await _fadePlayer.setVolume(startVolume * eased);
    }

    if (runId != _fadeRunId) {
      return;
    }
    await _fadePlayer.stop();
  }
}
