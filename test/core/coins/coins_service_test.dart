import 'package:Prism/core/coins/coins_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CoinMutationResult carries the transactionId returned by the awardCoins/spendCoins callables', () {
    const result = CoinMutationResult(
      success: true,
      changed: true,
      previousBalance: 10,
      currentBalance: 20,
      delta: 10,
      transactionId: 'ctx_refund_123',
    );

    expect(result.transactionId, 'ctx_refund_123');
  });

  test('CoinMutationResult defaults transactionId to empty when not provided', () {
    const result = CoinMutationResult(success: true, changed: false, previousBalance: 5, currentBalance: 5, delta: 0);

    expect(result.transactionId, '');
    expect(CoinMutationResult.noChange(balance: 5).transactionId, '');
  });
}
