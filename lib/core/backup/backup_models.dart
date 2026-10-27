class BackupException implements Exception {
  final String message;
  BackupException(this.message);

  @override
  String toString() => message;
}

/// A few headline numbers, shown next to each backup.
class BackupSummary {
  final int items;
  final int sales;
  final int salesTotal;
  final int customers;

  const BackupSummary({
    required this.items,
    required this.sales,
    required this.salesTotal,
    required this.customers,
  });

  // Drive stores these as text, next to the file
  Map<String, String> toProps() => {
    'items': '$items',
    'sales': '$sales',
    'salesTotal': '$salesTotal',
    'customers': '$customers',
  };

  Map<String, Object> toJson() => {
    'items': items,
    'sales': sales,
    'salesTotal': salesTotal,
    'customers': customers,
  };

  factory BackupSummary.fromProps(Map<String, dynamic>? props) {
    int number(String key) => int.tryParse('${props?[key] ?? 0}') ?? 0;
    return BackupSummary(
      items: number('items'),
      sales: number('sales'),
      salesTotal: number('salesTotal'),
      customers: number('customers'),
    );
  }
}

/// A backup file in the user's Google Drive.
class CloudBackup {
  final String id;
  final String name;

  /// When the file was last written (today's backup is updated in place).
  final DateTime modifiedAt;
  final int sizeBytes;
  final BackupSummary summary;

  const CloudBackup({
    required this.id,
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
    required this.summary,
  });

  /// The copy of your data saved just before the last restore.
  static const beforeRestoreName = 'before-restore.json';

  bool get isBeforeRestore => name == beforeRestoreName;
  bool get isDaily => name.startsWith('daily-');

  factory CloudBackup.fromJson(Map<String, dynamic> json) => CloudBackup(
    id: json['id'] as String,
    name: json['name'] as String,
    modifiedAt: DateTime.parse(
      (json['modifiedTime'] ?? json['createdTime']) as String,
    ).toLocal(),
    sizeBytes: int.tryParse('${json['size'] ?? 0}') ?? 0,
    summary: BackupSummary.fromProps(
      (json['appProperties'] as Map?)?.cast<String, dynamic>(),
    ),
  );
}
