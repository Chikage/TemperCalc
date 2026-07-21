import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/favorite.dart';

abstract interface class FavoritesStorage {
  Future<List<FavoriteEntry>> load();

  Future<void> save(List<FavoriteEntry> favorites);
}

class SharedPreferencesFavoritesStorage implements FavoritesStorage {
  static const storageKey = 'favorite_temperaments_v1';

  const SharedPreferencesFavoritesStorage();

  @override
  Future<List<FavoriteEntry>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(storageKey);
    if (stored == null) return [];
    final values = jsonDecode(stored) as List<Object?>;
    return [
      for (final value in values)
        FavoriteEntry.fromJson(
          (value! as Map<Object?, Object?>).cast<String, Object?>(),
        ),
    ];
  }

  @override
  Future<void> save(List<FavoriteEntry> favorites) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode([for (final favorite in favorites) favorite.toJson()]),
    );
  }
}

class FavoritesController extends ChangeNotifier {
  FavoritesController(this._storage);

  final FavoritesStorage _storage;
  final List<FavoriteEntry> _favorites = [];

  bool _loaded = false;
  bool _loading = false;
  bool _disposed = false;
  Object? _loadError;
  Future<void>? _loadOperation;
  Future<void> _mutationChain = Future.value();

  List<FavoriteEntry> get favorites => List.unmodifiable(_favorites);
  bool get loaded => _loaded;
  bool get loading => _loading;
  Object? get loadError => _loadError;

  bool contains(String id) => _favorites.any((favorite) => favorite.id == id);

  Future<void> load() {
    if (_loaded) return Future.value();
    return _loadOperation ??= _performLoad();
  }

  Future<void> _performLoad() async {
    _loading = true;
    _loadError = null;
    _notify();
    try {
      final loaded = List<FavoriteEntry>.of(await _storage.load());
      loaded.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      _favorites
        ..clear()
        ..addAll(loaded);
      _loaded = true;
    } catch (error) {
      _loadError = error;
    } finally {
      _loading = false;
      _loadOperation = null;
      _notify();
    }
  }

  Future<bool> toggle(FavoriteEntry favorite) {
    return _enqueueMutation(() async {
      await load();
      return _toggleNow(favorite);
    });
  }

  Future<bool> _toggleNow(FavoriteEntry favorite) async {
    final existingIndex = _favorites.indexWhere(
      (saved) => saved.id == favorite.id,
    );
    final previous = List<FavoriteEntry>.of(_favorites);
    final added = existingIndex == -1;
    if (added) {
      _favorites.insert(0, favorite);
    } else {
      _favorites.removeAt(existingIndex);
    }
    _notify();
    try {
      await _storage.save(_favorites);
      _loadError = null;
      _loaded = true;
      return added;
    } catch (_) {
      _favorites
        ..clear()
        ..addAll(previous);
      _notify();
      rethrow;
    }
  }

  Future<void> remove(FavoriteEntry favorite) {
    return _enqueueMutation(() async {
      await load();
      final existingIndex = _favorites.indexWhere(
        (saved) => saved.id == favorite.id,
      );
      if (existingIndex == -1) return;
      await _toggleNow(_favorites[existingIndex]);
    });
  }

  Future<FavoritesImportResult> importFavorites(List<FavoriteEntry> imported) {
    return _enqueueMutation(() async {
      await load();
      if (!_loaded) {
        throw StateError('Favorites could not be loaded');
      }

      final uniqueImported = <String, FavoriteEntry>{
        for (final favorite in imported) favorite.id: favorite,
      };
      final merged = <String, FavoriteEntry>{
        for (final favorite in _favorites) favorite.id: favorite,
      };
      var added = 0;
      var updated = 0;
      var unchanged = 0;
      for (final entry in uniqueImported.entries) {
        final existing = merged[entry.key];
        if (existing == null) {
          added++;
        } else if (jsonEncode(existing.toJson()) ==
            jsonEncode(entry.value.toJson())) {
          unchanged++;
        } else {
          updated++;
        }
        merged[entry.key] = entry.value;
      }

      if (added == 0 && updated == 0) {
        return FavoritesImportResult(
          added: added,
          updated: updated,
          unchanged: unchanged,
        );
      }

      final previous = List<FavoriteEntry>.of(_favorites);
      final next = merged.values.toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      _favorites
        ..clear()
        ..addAll(next);
      _notify();
      try {
        await _storage.save(_favorites);
        _loadError = null;
        _loaded = true;
      } catch (_) {
        _favorites
          ..clear()
          ..addAll(previous);
        _notify();
        rethrow;
      }
      return FavoritesImportResult(
        added: added,
        updated: updated,
        unchanged: unchanged,
      );
    });
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
    final completer = Completer<T>();
    _mutationChain = _mutationChain.then((_) async {
      try {
        completer.complete(await mutation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class FavoritesImportResult {
  const FavoritesImportResult({
    required this.added,
    required this.updated,
    required this.unchanged,
  });

  final int added;
  final int updated;
  final int unchanged;

  int get total => added + updated + unchanged;
}
