import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/storage/app_prefs.dart';
import 'data/app_database.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/item_repository.dart';

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
      ],
      child: StoreApp(prefs: prefs),
    ),
  );
}
