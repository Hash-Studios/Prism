import 'package:Prism/core/wallpaper/duo_reveal_spec.g.dart';

final class AiDuoComposition {
  AiDuoComposition({required String foldedPrompt, required String revealedPrompt})
    : foldedPrompt = foldedPrompt.trim(),
      revealedPrompt = revealedPrompt.trim() {
    if (!isValidPrompt(this.foldedPrompt) || !isValidPrompt(this.revealedPrompt)) {
      throw ArgumentError('Duo prompts must each contain 1 to 160 characters.');
    }
  }

  static const String format = 'duo-reveal';
  static const int maxPromptChars = 160;
  static String get targetSize => '${DuoRevealSpec.canvasWidth}x${DuoRevealSpec.canvasHeight}';
  static bool isValidPrompt(String value) => value.trim().isNotEmpty && value.trim().length <= maxPromptChars;

  final String foldedPrompt;
  final String revealedPrompt;
}
