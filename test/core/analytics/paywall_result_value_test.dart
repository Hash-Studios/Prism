import 'package:Prism/core/analytics/events/events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only an actual paywall purchase counts as a purchase', () {
    expect(PaywallResultValue.purchased.indicatesPurchase, isTrue);
    expect(PaywallResultValue.restored.indicatesPurchase, isFalse);
    expect(PaywallResultValue.cancelled.indicatesPurchase, isFalse);
  });
}
