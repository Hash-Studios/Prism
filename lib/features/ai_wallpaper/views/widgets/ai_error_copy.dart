import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';

/// Calm copy for a worker error code. The worker message is never shown.
String aiGenerationErrorCopy(AiGenerationApiException error) {
  switch (error.code) {
    case 'rate_limited':
      return "You reached today's AI limit.";
    case 'budget_exhausted':
      return 'AI is very busy right now. Try again later. Your coins were returned.';
    case 'unsafe_prompt':
      return 'That prompt is not allowed.';
    case 'unsafe_output':
      return 'The result was blocked. Try another prompt.';
    case 'charge_required':
    case 'charge_invalid':
      return 'Payment check failed. Your coins will be returned.';
    case 'charge_in_progress':
      return 'Still working on your last image.';
    default:
      return "Couldn't generate right now. Try again.";
  }
}
