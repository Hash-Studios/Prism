import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';

class CoinTransactionEntry {
  const CoinTransactionEntry({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.delta,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.action,
    required this.description,
    required this.sourceTag,
    required this.status,
    required this.type,
    this.reason,
    this.referenceType,
    this.referenceId,
    this.deepLinkUrl,
    this.shortLinkUrl,
    this.metadata,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final DateTime createdAt;
  final int delta;
  final int balanceBefore;
  final int balanceAfter;
  final String action;
  final String description;
  final String sourceTag;
  final String status;
  final String type;
  final String? reason;
  final String? referenceType;
  final String? referenceId;
  final String? deepLinkUrl;
  final String? shortLinkUrl;
  final Map<String, dynamic>? metadata;
  final DateTime? updatedAt;

  bool get isCredit => delta > 0;
  bool get isDebit => delta < 0;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'createdAt': createdAt.toUtc(),
      'updatedAt': updatedAt?.toUtc(),
      'delta': delta,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'action': action,
      'description': description,
      'sourceTag': sourceTag,
      'status': status,
      'type': type,
      if (reason != null && reason!.isNotEmpty) 'reason': reason,
      if (referenceType != null && referenceType!.isNotEmpty) 'referenceType': referenceType,
      if (referenceId != null && referenceId!.isNotEmpty) 'referenceId': referenceId,
      if (deepLinkUrl != null && deepLinkUrl!.isNotEmpty) 'deepLinkUrl': deepLinkUrl,
      if (shortLinkUrl != null && shortLinkUrl!.isNotEmpty) 'shortLinkUrl': shortLinkUrl,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory CoinTransactionEntry.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    return CoinTransactionEntry(
      id: (json['id'] ?? fallbackId ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: json['updatedAt'] == null ? null : _parseDate(json['updatedAt']),
      delta: parseIntOr(json['delta']),
      balanceBefore: parseIntOr(json['balanceBefore']),
      balanceAfter: parseIntOr(json['balanceAfter']),
      action: (json['action'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      sourceTag: (json['sourceTag'] ?? '').toString(),
      status: (json['status'] ?? 'completed').toString(),
      type: (json['type'] ?? (parseIntOr(json['delta']) >= 0 ? 'credit' : 'debit')).toString(),
      reason: json['reason']?.toString(),
      referenceType: json['referenceType']?.toString(),
      referenceId: json['referenceId']?.toString(),
      deepLinkUrl: json['deepLinkUrl']?.toString(),
      shortLinkUrl: json['shortLinkUrl']?.toString(),
      metadata: json['metadata'] is Map ? toJsonMap(json['metadata']) : null,
    );
  }

  static DateTime _parseDate(Object? raw) => parseDateTime(raw)?.toUtc() ?? DateTime.now().toUtc();
}
