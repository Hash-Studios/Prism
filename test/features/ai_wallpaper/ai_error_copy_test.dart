import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_error_copy.dart';
import 'package:flutter_test/flutter_test.dart';

String _copy(String code) => aiGenerationErrorCopy(
  AiGenerationApiException(message: 'Quota coordinator unavailable', code: code, statusCode: 500),
);

void main() {
  test('each worker code maps to calm copy', () {
    expect(_copy('rate_limited'), "You reached today's AI limit.");
    expect(_copy('budget_exhausted'), 'AI is very busy right now. Try again later. Your coins were returned.');
    expect(_copy('unsafe_prompt'), 'That prompt is not allowed.');
    expect(_copy('unsafe_output'), 'The result was blocked. Try another prompt.');
    expect(_copy('charge_required'), 'Payment check failed. Your coins will be returned.');
    expect(_copy('charge_invalid'), 'Payment check failed. Your coins will be returned.');
    expect(_copy('charge_in_progress'), 'Still working on your last image.');
  });

  test('an unknown code gets the default copy and never the worker message', () {
    expect(_copy('provider_error'), "Couldn't generate right now. Try again.");
    expect(_copy('provider_error'), isNot(contains('Quota')));
  });
}
