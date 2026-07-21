import 'dart:async';

import 'package:flutter/material.dart';

import '../data/favorites_store.dart';
import '../data/favorites_transfer.dart';
import '../data/settings_store.dart';
import 'app_callbacks.dart' as callbacks;
import 'calculator_page.dart';
import 'favorites_page.dart';
import 'search_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.onCalculate,
    required this.onSearch,
    this.favoritesController,
    this.settingsController,
    this.favoritesFileTransfer = const FilePickerFavoritesFileTransfer(),
    super.key,
  });

  final callbacks.CalculateCallback onCalculate;
  final callbacks.SearchCallback onSearch;
  final FavoritesController? favoritesController;
  final SettingsController? settingsController;
  final FavoritesFileTransfer favoritesFileTransfer;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final FavoritesController _favorites;
  late final bool _ownsFavorites;
  late final SettingsController _settings;
  late final bool _ownsSettings;
  int _index = 0;
  bool _transferringFavorites = false;

  @override
  void initState() {
    super.initState();
    _ownsFavorites = widget.favoritesController == null;
    _favorites =
        widget.favoritesController ??
        FavoritesController(const SharedPreferencesFavoritesStorage());
    _ownsSettings = widget.settingsController == null;
    _settings =
        widget.settingsController ??
        SettingsController(const SharedPreferencesSettingsStorage());
    unawaited(_favorites.load());
    unawaited(_settings.load());
  }

  @override
  void dispose() {
    if (_ownsFavorites) _favorites.dispose();
    if (_ownsSettings) _settings.dispose();
    super.dispose();
  }

  Future<void> _importFavorites() async {
    setState(() => _transferringFavorites = true);
    try {
      final source = await widget.favoritesFileTransfer.pickArchive();
      if (source == null) return;
      final imported = FavoritesArchive.decode(source);
      final result = await _favorites.importFavorites(imported);
      if (!mounted) return;
      final message = switch (result) {
        FavoritesImportResult(total: 0) =>
          'The selected file contains no favorites',
        FavoritesImportResult(added: 0, updated: 0) =>
          'All ${result.total} favorites are already in your list',
        _ => _importMessage(result),
      };
      _showMessage(message);
    } catch (error) {
      if (mounted) _showMessage('Could not import favorites: $error');
    } finally {
      if (mounted) setState(() => _transferringFavorites = false);
    }
  }

  Future<void> _exportFavorites() async {
    setState(() => _transferringFavorites = true);
    try {
      final items = _favorites.favorites;
      final now = DateTime.now();
      final saved = await widget.favoritesFileTransfer.saveArchive(
        contents: FavoritesArchive.encode(items, exportedAt: now),
        fileName: 'temper-calc-favorites-${_date(now)}.json',
      );
      if (mounted && saved) {
        _showMessage(
          'Exported ${items.length} ${items.length == 1 ? 'favorite' : 'favorites'}',
        );
      }
    } catch (error) {
      if (mounted) _showMessage('Could not export favorites: $error');
    } finally {
      if (mounted) setState(() => _transferringFavorites = false);
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _importMessage(FavoritesImportResult result) {
    final changes = [
      if (result.added > 0) '${result.added} added',
      if (result.updated > 0) '${result.updated} updated',
    ];
    return 'Imported ${changes.join(', ')}';
  }

  String _date(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => Scaffold(
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
                  2 => 'Favorites',
                  _ => 'Settings',
                },
                maxLines: 1,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          actions: [
            if (_index == 2) ...[
              if (_transferringFavorites)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              IconButton(
                key: const ValueKey('import-favorites'),
                tooltip: 'Import favorites',
                onPressed: _transferringFavorites ? null : _importFavorites,
                icon: const Icon(Icons.file_download_outlined),
              ),
              AnimatedBuilder(
                animation: _favorites,
                builder: (context, _) => IconButton(
                  key: const ValueKey('export-favorites'),
                  tooltip: 'Export favorites',
                  onPressed:
                      _transferringFavorites || _favorites.favorites.isEmpty
                      ? null
                      : _exportFavorites,
                  icon: const Icon(Icons.file_upload_outlined),
                ),
              ),
            ],
            IconButton(
              tooltip: 'About Temper Calc',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: 'Temper Calc',
                applicationVersion: '1.0.8 b11',
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
                settings: _settings.settings,
              ),
            ),
            TickerMode(
              enabled: _index == 1,
              child: SearchPage(
                active: _index == 1,
                onCalculate: widget.onCalculate,
                onSearch: widget.onSearch,
                favorites: _favorites,
                settings: _settings.settings,
              ),
            ),
            TickerMode(
              enabled: _index == 2,
              child: FavoritesPage(
                favorites: _favorites,
                settings: _settings.settings,
              ),
            ),
            TickerMode(
              enabled: _index == 3,
              child: SettingsPage(controller: _settings),
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
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
