class LedgerEntry {
  final int id;
  final int customerId;
  final int? saleId;

  /// 'charge' (from a sale), 'payment', or 'adjustment'
  final String type;

  /// Centavos. Positive = they owe more, negative = they owe less.
  final int amount;
  final String? note;
  final DateTime createdAt;

  const LedgerEntry({
    required this.id,
    required this.customerId,
    required this.saleId,
    required this.type,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  factory LedgerEntry.fromMap(Map<String, Object?> m) => LedgerEntry(
    id: m['id'] as int,
    customerId: m['customer_id'] as int,
    saleId: m['sale_id'] as int?,
    type: m['type'] as String,
    amount: m['amount'] as int,
    note: m['note'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}
