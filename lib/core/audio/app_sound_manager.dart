import 'package:audioplayers/audioplayers.dart';

enum AppSoundEffect { onboardingOpenSwoosh, tap, click, success }

class AppSoundManager {
  AppSoundManager._();

  static final AppSoundManager instance = AppSoundManager._();

  final AudioPlayer _player = AudioPlayer();
  bool _isConfigured = false;
  int _fadeRunId = 0;

  Future<void> playEffect(AppSoundEffect effect, {double? volume}) async {
    try {
      await _ensureConfigured();
      await _player.stop();
      final targetVolume = volume ?? _defaultVolumeFor(effect);
      if (effect == AppSoundEffect.onboardingOpenSwoosh) {
        await _playOnboardingWithFade(assetPath: _assetFor(effect), startVolume: targetVolume);
        return;
      }
      await _player.play(AssetSource(_assetFor(effect)), volume: targetVolume);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<void> _ensureConfigured() async {
    if (_isConfigured) {
      return;
    }
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setPlayerMode(PlayerMode.lowLatency);
    _isConfigured = true;
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
      AppSoundEffect.onboardingOpenSwoosh => 0.11,
      AppSoundEffect.tap => 0.24,
      AppSoundEffect.click => 0.28,
      AppSoundEffect.success => 0.32,
    };
  }

  Future<void> _playOnboardingWithFade({required String assetPath, required double startVolume}) async {
    final runId = ++_fadeRunId;
    await _player.play(AssetSource(assetPath), volume: startVolume);

    const total = Duration(seconds: 4);
    const steps = 24;
    final stepDelay = Duration(milliseconds: total.inMilliseconds ~/ steps);

    for (var i = 1; i <= steps; i++) {
      if (runId != _fadeRunId) {
        return;
      }
      await Future<void>.delayed(stepDelay);
      final t = i / steps;
      final eased = 1 - t;
      await _player.setVolume(startVolume * eased);
    }

    if (runId != _fadeRunId) {
      return;
    }
    await _player.stop();
  }
}
