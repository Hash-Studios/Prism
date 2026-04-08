// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transactionModel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrismTransaction _$PrismTransactionFromJson(Map<String, dynamic> json) => PrismTransaction(
  name: json['name'] as String,
  description: json['description'] as String,
  id: json['id'] as String,
  amount: json['amount'] as String,
  credit: json['credit'] as bool,
  by: json['by'] as String,
  processedAt: json['processedAt'] as String,
);

Map<String, dynamic> _$PrismTransactionToJson(PrismTransaction instance) => <String, dynamic>{
  'name': instance.name,
  'by': instance.by,
  'id': instance.id,
  'processedAt': instance.processedAt,
  'credit': instance.credit,
  'amount': instance.amount,
  'description': instance.description,
};
