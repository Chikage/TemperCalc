import 'package:flutter/material.dart';

import 'app_callbacks.dart' as callbacks;
import 'calculator_page.dart';
import 'search_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.onCalculate,
    required this.onSearch,
    super.key,
  });

  final callbacks.CalculateCallback onCalculate;
  final callbacks.SearchCallback onSearch;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temper Calc'),
        actions: [
          IconButton(
            tooltip: 'About Temper Calc',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'Temper Calc',
              applicationVersion: '1.0.0',
              applicationLegalese:
                  'Copyright (c) 2026 Shiryee Lin\nBased on Sin-tel/temper',
              applicationIcon: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/app_icon_flat.png',
                  width: 52,
                  height: 52,
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          TickerMode(
            enabled: _index == 0,
            child: CalculatorPage(
              active: _index == 0,
              onCalculate: widget.onCalculate,
            ),
          ),
          TickerMode(
            enabled: _index == 1,
            child: SearchPage(
              active: _index == 1,
              onCalculate: widget.onCalculate,
              onSearch: widget.onSearch,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_search_outlined),
            selectedIcon: Icon(Icons.manage_search),
            label: 'Search',
          ),
        ],
      ),
    );
  }
}
