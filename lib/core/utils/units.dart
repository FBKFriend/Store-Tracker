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

  /// Turns typed text like "12.50" or "1,200" into centavos. Null if invalid.
  static int? parse(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', ''));
    if (value == null || value < 0) return null;
    return fromDouble(value);
  }

  /// Number only for typing into a field: 1250 -> "12.50".
  static String plain(int cents) => (cents / 100).toStringAsFixed(2);

  /// Price x quantity (quantity in thousandths), rounded to the nearest centavo.
  static int lineTotal(int qtyMilli, int priceCents) =>
      (qtyMilli * priceCents / 1000).round();
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

  /// Turns typed text like "0.25" into thousandths. Null if invalid.
  static int? parse(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', ''));
    if (value == null || value < 0) return null;
    return fromDouble(value);
  }

  /// Number only for typing into a field: 2500 -> "2.5", 3000 -> "3".
  static String plain(int milli) {
    final text = (milli / 1000).toStringAsFixed(3);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
