import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/l10n/l10n.dart';

/// Calm copy for a worker error code. The worker message is never shown.
String aiGenerationErrorCopy(AppLocalizations l10n, AiGenerationApiException error) {
  switch (error.code) {
    case 'rate_limited':
      return l10n.economyAiDailyLimit;
    case 'budget_exhausted':
      return l10n.economyAiBusyRefunded;
    case 'unsafe_prompt':
      return l10n.economyAiPromptBlocked;
    case 'unsafe_output':
      return l10n.economyAiResultBlocked;
    case 'charge_required':
    case 'charge_invalid':
      return l10n.economyAiPaymentCheckFailed;
    case 'charge_in_progress':
      return l10n.economyAiStillWorking;
    default:
      return l10n.economyAiGenerateFailed;
  }
}

bool aiGenerationErrorMentionsRefund(Object error) =>
    error is AiGenerationApiException &&
    const <String>{'budget_exhausted', 'charge_required', 'charge_invalid'}.contains(error.code);
