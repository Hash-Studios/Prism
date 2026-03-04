class TransactionEntity {
  const TransactionEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.credit,
    required this.by,
    required this.processedAt,
  });

  final String id;
  final String name;
  final String description;
  final String amount;
  final bool credit;
  final String by;
  final String processedAt;
}
