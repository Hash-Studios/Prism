import 'package:Prism/logger/logger.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transactionModel.g.dart';

@JsonSerializable(explicitToJson: true)
class PrismTransaction {
  String name;
  String by;
  String id;
  String processedAt;
  bool credit;
  String amount;
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

  factory PrismTransaction.fromJson(Map<String, dynamic> json) => _$PrismTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$PrismTransactionToJson(this);
}
