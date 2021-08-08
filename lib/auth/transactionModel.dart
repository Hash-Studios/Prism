import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transactionModel.g.dart';

@HiveType(typeId: 13)
@JsonSerializable(
  explicitToJson: true,
)
class PrismTransaction {
  @HiveField(0)
  String name;
  @HiveField(1)
  String by;
  @HiveField(2)
  String id;
  @HiveField(3)
  String processedAt;
  @HiveField(4)
  bool credit;
  @HiveField(5)
  String amount;
  @HiveField(6)
  String description;

  PrismTransaction({
    required this.name,
    required this.description,
    required this.id,
    required this.amount,
    required this.credit,
    required this.by,
    required this.processedAt,
  }) {
    logger.d("Default constructor !!!!");
  }

  factory PrismTransaction.fromJson(Map<String, dynamic> json) =>
      _$PrismTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$PrismTransactionToJson(this);
}
