class LiveCapabilities {
  const LiveCapabilities({this.supportsShaders = false, this.supportsVideo = false});

  static const LiveCapabilities none = LiveCapabilities();

  final bool supportsShaders;
  final bool supportsVideo;

  bool get isSupported => supportsShaders || supportsVideo;

  @override
  bool operator ==(Object other) =>
      other is LiveCapabilities && other.supportsShaders == supportsShaders && other.supportsVideo == supportsVideo;

  @override
  int get hashCode => Object.hash(supportsShaders, supportsVideo);
}
