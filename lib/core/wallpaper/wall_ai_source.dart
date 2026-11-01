/// The prompt behind an AI wall. A wall that is not AI, or has no prompt, has none.
final class WallAiSource {
  const WallAiSource({required this.prompt, this.stylePreset, this.model, this.isStudio = false});

  final String prompt;

  /// The `aiStylePreset` api value. Null on Studio walls and on walls made before styles were stored.
  final String? stylePreset;
  final String? model;
  final bool isStudio;

  static WallAiSource? parse({
    required Object? isAiGenerated,
    required Object? prompt,
    Object? stylePreset,
    Object? model,
    Object? origin,
  }) {
    final String text = prompt is String ? prompt.trim() : '';
    if (isAiGenerated != true || text.isEmpty) return null;
    String? optional(Object? value) => value is String && value.trim().isNotEmpty ? value.trim() : null;
    return WallAiSource(
      prompt: text,
      stylePreset: optional(stylePreset),
      model: optional(model),
      isStudio: origin == 'studio',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'isAiGenerated': true,
    'aiPrompt': prompt,
    if (stylePreset != null) 'aiStylePreset': stylePreset,
    if (model != null) 'aiModel': model,
    if (isStudio) 'origin': 'studio',
  };

  static WallAiSource? fromJson(Object? json) {
    if (json is! Map) return null;
    return parse(
      isAiGenerated: json['isAiGenerated'],
      prompt: json['aiPrompt'],
      stylePreset: json['aiStylePreset'],
      model: json['aiModel'],
      origin: json['origin'],
    );
  }
}
