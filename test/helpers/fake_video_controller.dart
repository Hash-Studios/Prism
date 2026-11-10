import 'dart:ui' show Size;

import 'package:video_player/video_player.dart';

/// A [VideoPlayerController] that never reaches a platform player. Tests install it with
/// `LiveWallVideo.createController`, and read [created] to inspect what the widget did.
class FakeVideoController extends VideoPlayerController {
  FakeVideoController(Uri url) : super.networkUrl(url) {
    created.add(this);
  }

  /// Every controller created in this test, in order. Clear it in `setUp`.
  static final List<FakeVideoController> created = <FakeVideoController>[];

  int playCalls = 0;
  int pauseCalls = 0;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    value = value.copyWith(isInitialized: true, duration: const Duration(seconds: 3), size: const Size(1080, 1920));
  }

  @override
  Future<void> play() async {
    playCalls++;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> setVolume(double volume) async {
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
  }

  // The base dispose only touches the platform after initialize, so calling super is safe here.
  @override
  Future<void> dispose() {
    disposed = true;
    return super.dispose();
  }
}
