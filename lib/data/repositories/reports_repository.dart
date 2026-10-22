import '../app_database.dart';
import '../models/report.dart';

/// Read-only numbers for the dashboard and reports. Voided sales never count.
class ReportsRepository {
  ReportsRepository(this._db);
  final AppDatabase _db;

  // Builds "column >= ? AND column < ?" for whichever limits are given
  (String, List<Object?>) _range(String column, DateTime? from, DateTime? to) {
    final parts = <String>[];
    final args = <Object?>[];
    if (from != null) {
      parts.add('$column >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      parts.add('$column < ?');
      args.add(to.toIso8601String());
    }
    return (parts.isEmpty ? '1=1' : parts.join(' AND '), args);
  }

  Future<PeriodSummary> summary({DateTime? from, DateTime? to}) async {
    final db = await _db.database;

    final (saleWhere, saleArgs) = _range('s.created_at', from, to);
    final sales = await db.rawQuery('''
      SELECT COUNT(*) AS cnt,
             COALESCE(SUM(s.total), 0) AS total,
             COALESCE(SUM(s.utang_amount), 0) AS utang
      FROM sales s
      WHERE s.status = 'completed' AND $saleWhere
    ''', saleArgs);

    final cost = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(ROUND(si.qty * si.unit_cost / 1000.0) AS INTEGER)), 0) AS cost
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'completed' AND $saleWhere
    ''', saleArgs);

    final (lotWhere, lotArgs) = _range('l.received_at', from, to);
    final expenses = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(ROUND(l.qty_received * l.buying_price / 1000.0) AS INTEGER)), 0) AS expenses
      FROM stock_lots l
      WHERE l.counts_as_expense = 1 AND $lotWhere
    ''', lotArgs);

    final (payWhere, payArgs) = _range('d.created_at', from, to);
    final collected = await db.rawQuery('''
      SELECT COALESCE(SUM(-d.amount), 0) AS collected
      FROM debt_ledger d
      WHERE d.type = 'payment' AND $payWhere
    ''', payArgs);

    return PeriodSummary(
      salesCount: sales.first['cnt'] as int,
      salesTotal: sales.first['total'] as int,
      newUtang: sales.first['utang'] as int,
      cost: cost.first['cost'] as int,
      expenses: expenses.first['expenses'] as int,
      utangCollected: collected.first['collected'] as int,
    );
  }

  /// Per item: what was sold, what it earned, what it cost. Best profit first.
  Future<List<ProfitRow>> profitBreakdown({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.database;
    final (where, args) = _range('s.created_at', from, to);
    final rows = await db.rawQuery('''
      SELECT si.item_id AS item_id,
             MAX(si.item_name) AS item_name,
             MAX(si.unit) AS unit,
             SUM(si.qty) AS qty,
             SUM(si.line_total) AS revenue,
             SUM(CAST(ROUND(si.qty * si.unit_cost / 1000.0) AS INTEGER)) AS cost
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'completed' AND $where
      GROUP BY si.item_id
      ORDER BY (SUM(si.line_total) -
                SUM(CAST(ROUND(si.qty * si.unit_cost / 1000.0) AS INTEGER))) DESC
    ''', args);
    return rows.map(ProfitRow.fromMap).toList();
  }

  /// Every stock purchase counted as an expense, newest first.
  Future<List<ExpenseRow>> expenseBreakdown({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.database;
    final (where, args) = _range('l.received_at', from, to);
    final rows = await db.rawQuery('''
      SELECT i.name AS item_name,
             i.unit AS unit,
             l.qty_received AS qty,
             l.buying_price AS unit_cost,
             l.received_at AS received_at,
             CAST(ROUND(l.qty_received * l.buying_price / 1000.0) AS INTEGER) AS total,
             COALESCE((SELECT m.type FROM stock_movements m
                       WHERE m.lot_id = l.id AND m.type IN ('initial', 'restock')
                       ORDER BY m.id LIMIT 1), 'restock') AS kind
      FROM stock_lots l JOIN items i ON i.id = l.item_id
      WHERE l.counts_as_expense = 1 AND $where
      ORDER BY l.received_at DESC, l.id DESC
    ''', args);
    return rows.map(ExpenseRow.fromMap).toList();
  }

  /// Sales that were made in the period but later voided: (count, total).
  Future<(int, int)> voidedSales({DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    final (where, args) = _range('s.created_at', from, to);
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS cnt, COALESCE(SUM(s.total), 0) AS total
      FROM sales s
      WHERE s.status = 'voided' AND $where
    ''', args);
    return (rows.first['cnt'] as int, rows.first['total'] as int);
  }

  /// Utang payments and manual adjustments in the period, newest first.
  Future<List<UtangActivityRow>> utangActivity({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.database;
    final (where, args) = _range('d.created_at', from, to);
    final rows = await db.rawQuery('''
      SELECT c.name AS customer_name, d.type AS type, d.amount AS amount,
             d.note AS note, d.created_at AS created_at
      FROM debt_ledger d JOIN customers c ON c.id = d.customer_id
      WHERE d.type IN ('payment', 'adjustment') AND $where
      ORDER BY d.id DESC
    ''', args);
    return rows.map(UtangActivityRow.fromMap).toList();
  }
}
