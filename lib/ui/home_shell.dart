import 'dart:async';

import 'package:flutter/material.dart';

import '../data/favorites_store.dart';
import '../data/favorites_transfer.dart';
import 'app_callbacks.dart' as callbacks;
import 'calculator_page.dart';
import 'favorites_page.dart';
import 'search_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.onCalculate,
    required this.onSearch,
    this.favoritesController,
    this.favoritesFileTransfer = const FilePickerFavoritesFileTransfer(),
    super.key,
  });

  final callbacks.CalculateCallback onCalculate;
  final callbacks.SearchCallback onSearch;
  final FavoritesController? favoritesController;
  final FavoritesFileTransfer favoritesFileTransfer;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final FavoritesController _favorites;
  late final bool _ownsFavorites;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ownsFavorites = widget.favoritesController == null;
    _favorites =
        widget.favoritesController ??
        FavoritesController(const SharedPreferencesFavoritesStorage());
    unawaited(_favorites.load());
  }

  @override
  void dispose() {
    if (_ownsFavorites) _favorites.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              switch (_index) {
                0 => 'Temperament calculator',
                1 => 'Search temperaments',
                _ => 'Favorites',
              },
              maxLines: 1,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'About Temper Calc',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'Temper Calc',
              applicationVersion: '1.0.7 b8',
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
              favorites: _favorites,
            ),
          ),
          TickerMode(
            enabled: _index == 1,
            child: SearchPage(
              active: _index == 1,
              onCalculate: widget.onCalculate,
              onSearch: widget.onSearch,
              favorites: _favorites,
            ),
          ),
          TickerMode(
            enabled: _index == 2,
            child: FavoritesPage(
              favorites: _favorites,
              fileTransfer: widget.favoritesFileTransfer,
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
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
}
