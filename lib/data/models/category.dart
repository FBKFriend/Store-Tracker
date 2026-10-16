class ItemCategory {
  final int id;
  final String name;
  final int sortOrder;
  final bool isDefault;

  const ItemCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isDefault,
  });

  factory ItemCategory.fromMap(Map<String, Object?> m) => ItemCategory(
    id: m['id'] as int,
    name: m['name'] as String,
    sortOrder: m['sort_order'] as int,
    isDefault: (m['is_default'] as int) == 1,
  );
}
