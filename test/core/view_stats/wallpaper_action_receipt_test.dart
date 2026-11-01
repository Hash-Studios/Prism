import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> response() => <String, Object?>{
    'counted': true,
    'questReceiptComplete': true,
    'questReceiptId': 'request_1234',
    'questCoins': 15,
    'questAwards': <Object?>[
      <String, Object?>{'id': 'set', 'coins': 10, 'xp': 5},
      <String, Object?>{'id': 'weekly', 'coins': 5, 'xp': 2},
    ],
  };

  test('returns only complete server-confirmed awards for this request', () {
    final receipt = WallpaperActionReceipt.fromResponse(response(), 'request_1234');
    expect(receipt.coins, 15);
    expect(receipt.receiptId, 'request_1234');
    expect(receipt.counted, isTrue);
  });

  test('legacy, zero, partial and mismatched replies contain no earned amount', () {
    for (final raw in <Object?>[
      null,
      <String, Object?>{'counted': true},
      response()..['questReceiptId'] = 'other_request',
      response()..['questReceiptComplete'] = false,
      response()..['questCoins'] = 0,
      response()..['questCoins'] = 30,
      response()
        ..['questAwards'] = <Object?>[
          <String, Object?>{'id': 'set', 'coins': -1},
        ],
    ]) {
      final receipt = WallpaperActionReceipt.fromResponse(raw, 'request_1234');
      expect(receipt.coins, 0, reason: '$raw');
      expect(receipt.receiptId, isNull);
    }
  });
}
