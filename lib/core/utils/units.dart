/// Units an item can be sold in. Only kg allows decimals (0.25 kg, etc.).
enum ItemUnit {
  pcs('pcs', false),
  kg('kg', true);

  const ItemUnit(this.label, this.allowsDecimal);
  final String label;
  final bool allowsDecimal;

  static ItemUnit fromName(String name) => ItemUnit.values.firstWhere(
    (u) => u.name == name,
    orElse: () => ItemUnit.pcs,
  );
}

/// Money is stored as whole centavos (₱12.50 is saved as 1250).
class Money {
  Money._();

  static int fromDouble(double amount) => (amount * 100).round();
  static double toDouble(int cents) => cents / 100;
  static String format(int cents, {String symbol = '₱'}) =>
      '$symbol${(cents / 100).toStringAsFixed(2)}';
}

/// Quantities are stored in thousandths so kg can have decimals without
/// floating-point errors (0.25 kg is saved as 250, 3 pcs as 3000).
class Qty {
  Qty._();

  static int fromDouble(double qty) => (qty * 1000).round();
  static double toDouble(int milli) => milli / 1000;

  static String format(int milli, ItemUnit unit) {
    var text = (milli / 1000).toStringAsFixed(3);
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$text ${unit.label}';
  }
}
