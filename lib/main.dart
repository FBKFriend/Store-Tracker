import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/storage/app_prefs.dart';
import 'data/app_database.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/item_repository.dart';
import 'features/pos/cart_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await AppPrefs.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => CategoryRepository(AppDatabase.instance)..load(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => ItemRepository(AppDatabase.instance)..load(),
        ),
        ChangeNotifierProvider(
          create: (context) => CartController(context.read<ItemRepository>()),
        ),
      ],
      child: StoreApp(prefs: prefs),
    ),
  );
}
