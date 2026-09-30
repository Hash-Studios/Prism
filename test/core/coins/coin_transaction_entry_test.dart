import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
