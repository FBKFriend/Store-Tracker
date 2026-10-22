import '../../core/utils/units.dart';

/// Which stretch of time a report covers.
enum ReportPeriod {
  today('Today'),
  week('This week'),
  month('This month'),
  all('All time');

  const ReportPeriod(this.label);
  final String label;

  /// (from, to). [to] is exclusive, and null means no limit.
  (DateTime?, DateTime?) get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    switch (this) {
      case ReportPeriod.today:
        return (today, tomorrow);
      case ReportPeriod.week:
        // Monday to now
        return (today.subtract(Duration(days: today.weekday - 1)), tomorrow);
      case ReportPeriod.month:
        return (DateTime(now.year, now.month, 1), tomorrow);
      case ReportPeriod.all:
        return (null, null);
    }
  }
}

class PeriodSummary {
  final int salesCount;
  final int salesTotal;

  /// What the sold items cost you.
  final int cost;

  /// Spent on stock (starting stock and restocks).
  final int expenses;

  /// Paid by customers toward their utang.
  final int utangCollected;

  /// Put on utang by sales in this period.
  final int newUtang;

  const PeriodSummary({
    required this.salesCount,
    required this.salesTotal,
    required this.cost,
    required this.expenses,
    required this.utangCollected,
    required this.newUtang,
  });

  int get profit => salesTotal - cost;
}

class ProfitRow {
  final int itemId;
  final String itemName;
  final ItemUnit unit;
  final int qty; // thousandths
  final int revenue;
  final int cost;

  const ProfitRow({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.revenue,
    required this.cost,
  });

  int get profit => revenue - cost;

  factory ProfitRow.fromMap(Map<String, Object?> m) => ProfitRow(
    itemId: m['item_id'] as int,
    itemName: m['item_name'] as String,
    unit: ItemUnit.fromName(m['unit'] as String),
    qty: m['qty'] as int,
    revenue: m['revenue'] as int,
    cost: m['cost'] as int,
  );
}

class ExpenseRow {
  final String itemName;
  final ItemUnit unit;
  final int qty; // thousandths
  final int unitCost;
  final int total;
  final DateTime receivedAt;

  /// 'initial' (starting stock) or 'restock'
  final String kind;

  const ExpenseRow({
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.unitCost,
    required this.total,
    required this.receivedAt,
    required this.kind,
  });

  factory ExpenseRow.fromMap(Map<String, Object?> m) => ExpenseRow(
    itemName: m['item_name'] as String,
    unit: ItemUnit.fromName(m['unit'] as String),
    qty: m['qty'] as int,
    unitCost: m['unit_cost'] as int,
    total: m['total'] as int,
    receivedAt: DateTime.parse(m['received_at'] as String),
    kind: m['kind'] as String,
  );
}
