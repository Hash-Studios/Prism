import 'dart:math';

import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';

/// Example scenes and modifiers that seed and shuffle the prompt field.
// ignore: avoid_classes_with_only_static_members
abstract final class AiPromptPools {
  static const String suffix = 'vertical phone wallpaper, no text';

  static const Map<AiStylePreset, List<String>> scenesByStyle = <AiStylePreset, List<String>>{
    AiStylePreset.anime: <String>[
      'an anime skyline above floating islands',
      'a lone samurai on a neon-lit rainy street',
      'a futuristic shrine with cherry blossoms and holograms',
      'a dreamy anime night market with lantern glow',
      'a cyber-anime city horizon at blue hour',
    ],
    AiStylePreset.minimal: <String>[
      'minimal dunes and a single sun disk',
      'clean geometric mountain layers',
      'a serene monochrome ocean horizon',
      'simple abstract lines with balanced spacing',
      'a soft gradient sky over flat hills',
    ],
    AiStylePreset.cyberpunk: <String>[
      'a neon megacity street with wet reflections',
      'a futuristic alley with holographic billboards',
      'a high-tech skyline with flying traffic lanes',
      'a cyberpunk rooftop overlooking glowing towers',
      'a midnight city crossing with teal-magenta lights',
    ],
    AiStylePreset.watercolor: <String>[
      'a watercolor forest valley at dawn',
      'a hand-painted mountain lake scene',
      'soft watercolor clouds above rolling hills',
      'a tranquil riverbank with pastel tones',
      'an artistic watercolor coastline at sunset',
    ],
    AiStylePreset.meshGradient: <String>[
      'a smooth mesh gradient flow with layered blobs',
      'vibrant fluid gradient waves with depth',
      'soft multi-color mesh forms and gentle curves',
      'high-contrast mesh gradient ribbons',
      'pastel mesh gradient bloom with subtle texture',
    ],
    AiStylePreset.abstract: <String>[
      'an abstract fractal composition with dynamic curves',
      'layered liquid forms with modern depth',
      'bold abstract shapes with soft edges',
      'a surreal abstract field of floating geometry',
      'organic abstract waves with cinematic contrast',
    ],
    AiStylePreset.nature: <String>[
      'a misty mountain range at sunrise',
      'a dense evergreen forest with sun rays',
      'a dramatic coastal cliff with crashing waves',
      'a calm alpine lake under twilight sky',
      'a desert canyon with warm golden light',
    ],
  };

  static const List<String> _lighting = <String>[
    'soft ambient',
    'cinematic rim',
    'golden hour',
    'moonlit',
    'volumetric',
  ];
  static const List<String> _moods = <String>['calm', 'dreamy', 'epic', 'moody', 'uplifting'];
  static const List<String> _qualities = <String>[
    'high detail',
    'ultra clean composition',
    'crisp textures',
    'balanced contrast',
    'vibrant but natural colors',
  ];

  static String _pick(Random random, List<String> values) => values[random.nextInt(values.length)];

  /// A full example prompt for [style].
  static String randomPrompt(AiStylePreset style, Random random) {
    final String scene = _pick(random, scenesByStyle[style]!);
    final String lighting = _pick(random, _lighting);
    final String mood = _pick(random, _moods);
    final String quality = _pick(random, _qualities);
    return '$scene, $lighting lighting, $mood mood, $quality, $suffix';
  }

  /// The scene at [index] in [style]'s first three ideas, wrapped into a prompt.
  static String sceneIdea(AiStylePreset style, int index) {
    final List<String> scenes = scenesByStyle[style]!.take(3).toList();
    return '${scenes[index % scenes.length]}, $suffix';
  }
}
