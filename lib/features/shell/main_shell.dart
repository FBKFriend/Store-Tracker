import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/google_auth_service.dart';
import '../../core/storage/app_prefs.dart';
import '../backup/cloud_check.dart';
import '../home/home_screen.dart';
import '../inventory/inventory_screen.dart';
import '../more/more_screen.dart';
import '../pos/pos_screen.dart';
import '../utang/utang_screen.dart';
import 'store_bottom_bar.dart';

class MainShell extends StatefulWidget {
  final AppPrefs prefs;
  const MainShell({super.key, required this.prefs});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0 Home, 1 Inventory, 2 POS, 3 Utang, 4 More
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Reconnect to Google once per app start (Android may ask which account)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final connected = await context
          .read<GoogleAuthService>()
          .restoreSession();
      if (!mounted) return;
      if (connected && widget.prefs.cloudCheckPending) {
        await resolveCloudData(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(prefs: widget.prefs),
          const InventoryScreen(),
          const PosScreen(),
          const UtangScreen(),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: StoreBottomBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
