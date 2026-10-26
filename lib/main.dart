import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/auth/google_auth_service.dart';
import 'core/backup/backup_service.dart';
import 'core/backup/drive_backup_client.dart';
import 'core/security/pin_controller.dart';
import 'core/settings/settings_controller.dart';
import 'core/storage/app_prefs.dart';
import 'data/app_database.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/item_repository.dart';
import 'data/repositories/reports_repository.dart';
import 'data/repositories/sales_repository.dart';
import 'features/pos/cart_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await AppPrefs.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => SettingsController(prefs),
        ),
        ChangeNotifierProvider(create: (_) => PinController(prefs)),
        ChangeNotifierProvider(create: (_) => GoogleAuthService(prefs)),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => CategoryRepository(AppDatabase.instance)..load(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => ItemRepository(AppDatabase.instance)..load(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => CustomerRepository(AppDatabase.instance)..load(),
        ),
        ChangeNotifierProvider(
          create: (context) => CartController(context.read<ItemRepository>()),
        ),
        Provider(
          create: (context) => SalesRepository(
            AppDatabase.instance,
            context.read<ItemRepository>(),
            context.read<CustomerRepository>(),
          ),
        ),
        Provider(create: (_) => ReportsRepository(AppDatabase.instance)),
        ChangeNotifierProvider(
          create: (context) => BackupService(
            db: AppDatabase.instance,
            prefs: prefs,
            drive: DriveBackupClient(context.read<GoogleAuthService>()),
            settings: context.read<SettingsController>(),
            items: context.read<ItemRepository>(),
            categories: context.read<CategoryRepository>(),
            customers: context.read<CustomerRepository>(),
            clearCart: context.read<CartController>().clear,
          ),
        ),
      ],
      child: StoreApp(prefs: prefs),
    ),
  );
}
