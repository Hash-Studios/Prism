import 'package:audioplayers/audioplayers.dart';

enum AppSoundEffect { onboardingOpenSwoosh, tap, click, success }

class AppSoundManager {
  AppSoundManager._();

  static final AppSoundManager instance = AppSoundManager._();

  // Low-latency player for short tap/click effects.
  final AudioPlayer _player = AudioPlayer();
  bool _isConfigured = false;

  // Separate media-mode player for the onboarding fade — lowLatency does not
  // support setVolume reliably on Android.
  final AudioPlayer _fadePlayer = AudioPlayer();
  bool _fadePlayerConfigured = false;
  int _fadeRunId = 0;

  Future<void> playEffect(AppSoundEffect effect, {double? volume}) async {
    try {
      final targetVolume = volume ?? _defaultVolumeFor(effect);
      if (effect == AppSoundEffect.onboardingOpenSwoosh) {
        await _playOnboardingWithFade(assetPath: _assetFor(effect), startVolume: targetVolume);
        return;
      }
      await _ensureConfigured();
      await _player.stop();
      await _player.play(AssetSource(_assetFor(effect)), volume: targetVolume);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _fadePlayer.dispose();
  }

  Future<void> _ensureConfigured() async {
    if (_isConfigured) {
      return;
    }
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setPlayerMode(PlayerMode.lowLatency);
    _isConfigured = true;
  }

  Future<void> _ensureFadePlayerConfigured() async {
    if (_fadePlayerConfigured) {
      return;
    }
    await _fadePlayer.setReleaseMode(ReleaseMode.stop);
    await _fadePlayer.setPlayerMode(PlayerMode.mediaPlayer);
    _fadePlayerConfigured = true;
  }

  String _assetFor(AppSoundEffect effect) {
    return switch (effect) {
      AppSoundEffect.onboardingOpenSwoosh => 'sounds/onboarding_open_candidate_a.mp3',
      AppSoundEffect.tap => 'sounds/onboarding_open_candidate_a.mp3',
      AppSoundEffect.click => 'sounds/onboarding_open_candidate_a.mp3',
      AppSoundEffect.success => 'sounds/onboarding_open_candidate_a.mp3',
    };
  }

  double _defaultVolumeFor(AppSoundEffect effect) {
    return switch (effect) {
      AppSoundEffect.onboardingOpenSwoosh => 0.07,
      AppSoundEffect.tap => 0.24,
      AppSoundEffect.click => 0.28,
      AppSoundEffect.success => 0.32,
    };
  }

  Future<void> _playOnboardingWithFade({required String assetPath, required double startVolume}) async {
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
