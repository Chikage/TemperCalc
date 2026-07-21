import 'package:flutter/material.dart';

import '../data/favorites_store.dart';
import '../domain/favorite.dart';
import 'result_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({required this.favorites, super.key});

  final FavoritesController favorites;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  FavoritesController get favorites => widget.favorites;

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
          if (items.isEmpty) return const _EmptyFavorites();
          return ListView.separated(
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
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
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
          );
        },
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
