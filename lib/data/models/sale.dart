import '../../core/utils/units.dart';

class SaleSummary {
  final int id;
  final DateTime createdAt;
  final int total;
  final int cashReceived;
  final int changeGiven;
  final int utangAmount;
  final int? customerId;
  final String? customerName;

  /// 'completed' or 'voided'
  final String status;
  final String? voidReason;
  final DateTime? voidedAt;

  const SaleSummary({
    required this.id,
    required this.createdAt,
    required this.total,
    required this.cashReceived,
    required this.changeGiven,
    required this.utangAmount,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.voidReason,
    required this.voidedAt,
  });

  bool get isVoided => status == 'voided';

  factory SaleSummary.fromMap(Map<String, Object?> m) => SaleSummary(
    id: m['id'] as int,
    createdAt: DateTime.parse(m['created_at'] as String),
    total: m['total'] as int,
    cashReceived: m['cash_received'] as int,
    changeGiven: m['change_given'] as int,
    utangAmount: m['utang_amount'] as int,
    customerId: m['customer_id'] as int?,
    customerName: m['customer_name'] as String?,
    status: m['status'] as String,
    voidReason: m['void_reason'] as String?,
    voidedAt: m['voided_at'] == null
        ? null
        : DateTime.parse(m['voided_at'] as String),
  );
}

/// One row of a sale: a quantity taken from one stock lot.
class SaleLineRow {
  final String itemName;
  final ItemUnit unit;
  final int qty;
  final int unitPrice;
  final int unitCost;
  final int lineTotal;

  const SaleLineRow({
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotal,
  });

  factory SaleLineRow.fromMap(Map<String, Object?> m) => SaleLineRow(
    itemName: m['item_name'] as String,
    unit: ItemUnit.fromName(m['unit'] as String),
    qty: m['qty'] as int,
    unitPrice: m['unit_price'] as int,
    unitCost: m['unit_cost'] as int,
    lineTotal: m['line_total'] as int,
  );
}

class SaleDetail {
  final SaleSummary sale;
  final List<SaleLineRow> lines;
  const SaleDetail({required this.sale, required this.lines});
}
