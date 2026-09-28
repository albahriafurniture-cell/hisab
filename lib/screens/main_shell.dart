import 'package:flutter/material.dart';

import '../widgets/app_background.dart';
import '../widgets/glass_bottom_nav.dart';
import 'add_txn_sheet.dart';
import 'home_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

/// Root after unlock: 4 glass tabs + center "Add" FAB.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTxnSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _index,
              children: [
                HomeScreen(
                  onSeeAllTxns: () => setState(() => _index = 1),
                ),
                const TransactionsScreen(),
                const ReportsScreen(),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlassBottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        onAdd: _openAdd,
      ),
    );
  }
}
