class LiveCapabilities {
  const LiveCapabilities({
    this.supportsShaders = false,
    this.supportsVideo = false,
    this.supportsTilt = false,
    this.supportsPerScreen = false,
  });

  static const LiveCapabilities none = LiveCapabilities();

  final bool supportsShaders;
  final bool supportsVideo;

  /// The shader renderer feeds `u_tilt` from a tilt sensor.
  final bool supportsTilt;

  /// Android 16 and later: a shader live wall can differ between the Home and Lock screens.
  final bool supportsPerScreen;

  bool get isSupported => supportsShaders || supportsVideo;

  @override
  bool operator ==(Object other) =>
      other is LiveCapabilities &&
      other.supportsShaders == supportsShaders &&
      other.supportsVideo == supportsVideo &&
      other.supportsTilt == supportsTilt &&
      other.supportsPerScreen == supportsPerScreen;

  @override
  int get hashCode => Object.hash(supportsShaders, supportsVideo, supportsTilt, supportsPerScreen);
}
