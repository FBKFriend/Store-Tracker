import '../../core/utils/units.dart';

/// One slice of stock (a lot) that still has quantity left.
class StockTier {
  final int qty; // thousandths
  final int price; // selling price in centavos
  const StockTier({required this.qty, required this.price});
}

/// Part of a sale taken from one lot, at that lot's price.
class PriceLine {
  final int qty; // thousandths
  final int price; // centavos
  const PriceLine({required this.qty, required this.price});

  int get total => Money.lineTotal(qty, price);
}

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

  /// Remaining stock lots, oldest first.
  final List<StockTier> tiers;

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
    this.tiers = const [],
  });

  bool get inStock => quantity > 0;

  /// True when a new price is waiting for the current stock to sell out.
  bool get priceChangePending =>
      quantity > 0 && latestSellingPrice != sellingPrice;

  /// Low when stock is at or below the item's alert level (or the default).
  bool isLowStock(int globalDefault) =>
      quantity > 0 && quantity <= (lowStockThreshold ?? globalDefault);

  /// Splits a quantity across the stock lots, oldest first, so each part
  /// has its own price.
  List<PriceLine> priceLines(int qty) {
    final lines = <PriceLine>[];
    var left = qty;
    for (final tier in tiers) {
      if (left <= 0) break;
      final take = left < tier.qty ? left : tier.qty;
      lines.add(PriceLine(qty: take, price: tier.price));
      left -= take;
    }
    return lines;
  }

  /// Total price (centavos) for buying [qty] of this item.
  int totalFor(int qty) => priceLines(qty).fold(0, (sum, l) => sum + l.total);

  Item copyWithTiers(List<StockTier> tiers) => Item(
    id: id,
    name: name,
    categoryId: categoryId,
    unit: unit,
    quantity: quantity,
    sellingPrice: sellingPrice,
    buyingPrice: buyingPrice,
    latestSellingPrice: latestSellingPrice,
    latestBuyingPrice: latestBuyingPrice,
    lowStockThreshold: lowStockThreshold,
    isArchived: isArchived,
    tiers: tiers,
  );

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
