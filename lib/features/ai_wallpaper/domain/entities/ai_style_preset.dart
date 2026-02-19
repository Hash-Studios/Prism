enum AiStylePreset {
  anime,
  minimal,
  cyberpunk,
  watercolor,
  meshGradient,
  abstract,
  nature;

  String get apiValue {
    switch (this) {
      case AiStylePreset.anime:
        return 'anime';
      case AiStylePreset.minimal:
        return 'minimal';
      case AiStylePreset.cyberpunk:
        return 'cyberpunk';
      case AiStylePreset.watercolor:
        return 'watercolor';
      case AiStylePreset.meshGradient:
        return 'mesh gradient';
      case AiStylePreset.abstract:
        return 'abstract';
      case AiStylePreset.nature:
        return 'nature';
    }
  }

  String get label {
    switch (this) {
      case AiStylePreset.anime:
        return 'Anime';
      case AiStylePreset.minimal:
        return 'Minimal';
      case AiStylePreset.cyberpunk:
        return 'Cyberpunk';
      case AiStylePreset.watercolor:
        return 'Watercolor';
      case AiStylePreset.meshGradient:
        return 'Mesh Gradient';
      case AiStylePreset.abstract:
        return 'Abstract';
      case AiStylePreset.nature:
        return 'Nature';
    }
  }

  static AiStylePreset fromApiValue(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'anime':
        return AiStylePreset.anime;
      case 'minimal':
        return AiStylePreset.minimal;
      case 'cyberpunk':
        return AiStylePreset.cyberpunk;
      case 'watercolor':
        return AiStylePreset.watercolor;
      case 'mesh gradient':
      case 'mesh_gradient':
      case 'meshgradient':
        return AiStylePreset.meshGradient;
      case 'nature':
        return AiStylePreset.nature;
      case 'abstract':
      default:
        return AiStylePreset.abstract;
    }
  }
}
