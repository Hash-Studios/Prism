import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serialization keeps the ledger values and references while normalizing dates to UTC', () {
    final entry = CoinTransactionEntry(
      id: 'download-42',
      userId: 'u1',
      createdAt: DateTime.parse('2026-01-02T10:00:00+02:00'),
      updatedAt: DateTime.parse('2026-01-02T10:01:00+02:00'),
      delta: -5,
      balanceBefore: 20,
      balanceAfter: 15,
      action: 'download',
      description: 'Original download',
      sourceTag: 'original_access',
      status: 'completed',
      type: 'debit',
      reason: 'purchase',
      referenceType: 'wallpaper',
      referenceId: 'wall-42',
      deepLinkUrl: 'prism://wallpaper/wall-42',
      shortLinkUrl: 'https://prism.test/w42',
      metadata: <String, dynamic>{'requestId': 'request-42'},
    );

    expect(entry.toJson(), <String, dynamic>{
      'id': 'download-42',
      'userId': 'u1',
      'createdAt': DateTime.utc(2026, 1, 2, 8),
      'updatedAt': DateTime.utc(2026, 1, 2, 8, 1),
      'delta': -5,
      'balanceBefore': 20,
      'balanceAfter': 15,
      'action': 'download',
      'description': 'Original download',
      'sourceTag': 'original_access',
      'status': 'completed',
      'type': 'debit',
      'reason': 'purchase',
      'referenceType': 'wallpaper',
      'referenceId': 'wall-42',
      'deepLinkUrl': 'prism://wallpaper/wall-42',
      'shortLinkUrl': 'https://prism.test/w42',
      'metadata': <String, dynamic>{'requestId': 'request-42'},
    });
    expect(entry.isCredit, isFalse);
  });

  test('serialization omits empty optional references rather than writing blank links', () {
    final entry = CoinTransactionEntry.fromJson(<String, dynamic>{
      'createdAt': DateTime.utc(2026),
      'delta': 5,
      'reason': '',
      'referenceType': '',
      'referenceId': '',
      'deepLinkUrl': '',
      'shortLinkUrl': '',
    });
    final json = entry.toJson();

    for (final field in <String>['reason', 'referenceType', 'referenceId', 'deepLinkUrl', 'shortLinkUrl', 'metadata']) {
      expect(json.containsKey(field), isFalse, reason: field);
    }
    expect(json['updatedAt'], isNull);
    expect(entry.isCredit, isTrue);
  });

  test('fromJson coerces numbers, dates and metadata from loose Firestore data', () {
    final DateTime created = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final entry = CoinTransactionEntry.fromJson(<String, dynamic>{
      'userId': 'u1',
      'createdAt': Timestamp.fromDate(created),
      'updatedAt': '2026-01-03T00:00:00Z',
      'delta': '-5',
      'balanceBefore': 20.0,
      'balanceAfter': 15,
      'action': 'wallpaperDownload',
      'metadata': <Object, Object>{1: 'a'},
    }, fallbackId: 'doc1');

    expect(entry.id, 'doc1');
    expect(entry.createdAt, created);
    expect(entry.updatedAt, DateTime.utc(2026, 1, 3));
    expect(entry.delta, -5);
    expect(entry.balanceBefore, 20);
    expect(entry.balanceAfter, 15);
    expect(entry.type, 'debit');
    expect(entry.status, 'completed');
    expect(entry.metadata, <String, dynamic>{'1': 'a'});
  });

  test('fromJson leaves optional fields empty and treats zero delta as a credit', () {
    final entry = CoinTransactionEntry.fromJson(<String, dynamic>{'id': 'x', 'createdAt': DateTime.utc(2026)});

    expect(entry.updatedAt, isNull);
    expect(entry.metadata, isNull);
    expect(entry.delta, 0);
    expect(entry.type, 'credit');
  });
}
