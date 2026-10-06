class AppliedWallpaper {
  const AppliedWallpaper({
    required this.id,
    required this.source,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.target,
    required this.appliedAt,
  });

  final String id;
  final String source;
  final String thumbnailUrl;
  final String fullUrl;
  final String target;
  final DateTime appliedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source,
    'thumbnailUrl': thumbnailUrl,
    'fullUrl': fullUrl,
    'target': target,
    'appliedAt': appliedAt.toUtc().toIso8601String(),
  };

  static AppliedWallpaper? tryFromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return null;
    final Object? id = json['id'];
    final Object? source = json['source'];
    final Object? thumbnailUrl = json['thumbnailUrl'];
    final Object? fullUrl = json['fullUrl'];
    final Object? target = json['target'];
    final Object? appliedAt = json['appliedAt'];
    if (id is! String || source is! String || thumbnailUrl is! String) return null;
    if (fullUrl is! String || fullUrl.isEmpty || target is! String || appliedAt is! String) return null;
    final DateTime? parsed = DateTime.tryParse(appliedAt);
    if (parsed == null) return null;
    return AppliedWallpaper(
      id: id,
      source: source,
      thumbnailUrl: thumbnailUrl,
      fullUrl: fullUrl,
      target: target,
      appliedAt: parsed,
    );
  }
}
