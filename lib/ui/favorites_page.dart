import 'package:flutter/material.dart';

import '../data/favorites_store.dart';
import '../data/favorites_transfer.dart';
import '../domain/favorite.dart';
import 'result_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    required this.favorites,
    this.fileTransfer = const FilePickerFavoritesFileTransfer(),
    super.key,
  });

  final FavoritesController favorites;
  final FavoritesFileTransfer fileTransfer;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _transferring = false;

  FavoritesController get favorites => widget.favorites;

  Future<void> _import() async {
    setState(() => _transferring = true);
    try {
      final source = await widget.fileTransfer.pickArchive();
      if (source == null) return;
      final imported = FavoritesArchive.decode(source);
      final result = await favorites.importFavorites(imported);
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
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _export() async {
    setState(() => _transferring = true);
    try {
      final items = favorites.favorites;
      final now = DateTime.now();
      final saved = await widget.fileTransfer.saveArchive(
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
      if (mounted) setState(() => _transferring = false);
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

  Future<void> _remove(BuildContext context, FavoriteEntry favorite) async {
    try {
      await favorites.remove(favorite);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from favorites')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove favorite: $error')),
      );
    }
  }

  void _open(BuildContext context, FavoriteEntry favorite) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ResultPage(
          result: favorite.result,
          favorite: favorite,
          favorites: favorites,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: favorites,
        builder: (context, _) {
          final items = favorites.favorites;
          if (!favorites.loaded && favorites.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (favorites.loadError != null && items.isEmpty) {
            return _LoadFailure(onRetry: favorites.load);
          }
          return Column(
            children: [
              _TransferToolbar(
                transferring: _transferring,
                canExport: items.isNotEmpty,
                onImport: _import,
                onExport: _export,
              ),
              Expanded(
                child: items.isEmpty
                    ? const _EmptyFavorites()
                    : ListView.separated(
                        key: const ValueKey('favorites-list'),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final favorite = items[index];
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: Card(
                                child: ListTile(
                                  key: ValueKey('favorite-${favorite.id}'),
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    8,
                                    8,
                                  ),
                                  leading: const Icon(Icons.bookmark),
                                  title: Text(
                                    favorite.title,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(favorite.details),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Remove favorite',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _remove(context, favorite),
                                  ),
                                  onTap: () => _open(context, favorite),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TransferToolbar extends StatelessWidget {
  const _TransferToolbar({
    required this.transferring,
    required this.canExport,
    required this.onImport,
    required this.onExport,
  });

  final bool transferring;
  final bool canExport;
  final VoidCallback onImport;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (transferring)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  key: const ValueKey('import-favorites'),
                  tooltip: 'Import favorites',
                  onPressed: transferring ? null : onImport,
                  icon: const Icon(Icons.file_download_outlined),
                ),
                IconButton(
                  key: const ValueKey('export-favorites'),
                  tooltip: 'Export favorites',
                  onPressed: transferring || !canExport ? null : onExport,
                  icon: const Icon(Icons.file_upload_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              'No favorites yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Favorites could not be loaded'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
