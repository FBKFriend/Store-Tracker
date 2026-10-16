import '../../core/utils/units.dart';

class Item {
  final int id;
  final String name;
  final int categoryId;
  final ItemUnit unit;

  /// Total in stock (thousandths), the sum of all lots.
  final int quantity;

  /// What customers pay right now (price of the oldest stock still available).
  final int sellingPrice;
  final int buyingPrice;

  /// Price of the newest stock, used as the default in the restock form.
  final int latestSellingPrice;
  final int latestBuyingPrice;

  /// Thousandths. Null means "use the global default".
  final int? lowStockThreshold;
  final bool isArchived;

  const Item({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.unit,
    required this.quantity,
    required this.sellingPrice,
    required this.buyingPrice,
    required this.latestSellingPrice,
    required this.latestBuyingPrice,
    required this.lowStockThreshold,
    required this.isArchived,
  });

  bool get inStock => quantity > 0;

  /// True when a new price is waiting for the current stock to sell out.
  bool get priceChangePending =>
      quantity > 0 && latestSellingPrice != sellingPrice;

  /// Low when stock is at or below the item's alert level (or the default).
  bool isLowStock(int globalDefault) =>
      quantity > 0 && quantity <= (lowStockThreshold ?? globalDefault);

  factory Item.fromMap(Map<String, Object?> m) => Item(
    id: m['id'] as int,
    name: m['name'] as String,
    categoryId: m['category_id'] as int,
    unit: ItemUnit.fromName(m['unit'] as String),
    quantity: m['quantity'] as int,
    sellingPrice: m['current_selling_price'] as int,
    buyingPrice: m['current_buying_price'] as int,
    latestSellingPrice: m['selling_price'] as int,
    latestBuyingPrice: m['buying_price'] as int,
    lowStockThreshold: m['low_stock_threshold'] as int?,
    isArchived: (m['is_archived'] as int) == 1,
  );
}
