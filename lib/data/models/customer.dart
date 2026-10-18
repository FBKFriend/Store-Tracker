class Customer {
  final int id;
  final String name;

  /// What they owe, in centavos (sum of their utang ledger).
  final int balance;

  const Customer({required this.id, required this.name, required this.balance});

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
    id: m['id'] as int,
    name: m['name'] as String,
    balance: m['balance'] as int,
  );
}
