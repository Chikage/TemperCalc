import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:temper_calc/data/favorites_store.dart';
import 'package:temper_calc/domain/favorite.dart';
import 'package:temper_calc/domain/models.dart';

const _result = TemperamentInfo(
  rank: 1,
  subgroup: '2.3.5',
  commaBasis: [],
  equalDivisionsLabel: 'EDO',
  equalDivisions: ['12'],
  mapping: [
    [12, 19, 28],
  ],
  preimage: [],
  tunings: {},
  errors: {},
  primes: {},
  badness: '0.471',
);

void main() {
  test(
    'controller persists toggles and restores newest favorites first',
    () async {
      final older = _favorite('12', DateTime.utc(2026, 7, 20));
      final newer = _favorite('19', DateTime.utc(2026, 7, 21));
      final storage = _MemoryFavoritesStorage([older, newer]);
      final controller = FavoritesController(storage);
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.favorites.map((item) => item.title), [
        newer.title,
        older.title,
      ]);

      expect(await controller.toggle(older), isFalse);
      expect(controller.contains(older.id), isFalse);
      expect(storage.values.map((item) => item.id), [newer.id]);

      expect(await controller.toggle(older), isTrue);
      expect(controller.favorites.first.id, older.id);
      expect(storage.values.map((item) => item.id), [older.id, newer.id]);
    },
  );

  test(
    'a toggle waits for the initial load instead of being overwritten',
    () async {
      final existing = _favorite('12', DateTime.utc(2026, 7, 20));
      final added = _favorite('19', DateTime.utc(2026, 7, 21));
      final storage = _DelayedFavoritesStorage();
      final controller = FavoritesController(storage);
      addTearDown(controller.dispose);

      final load = controller.load();
      final toggle = controller.toggle(added);
      storage.loadResult.complete([existing]);
      await load;

      expect(await toggle, isTrue);
      expect(controller.favorites.map((item) => item.id), [
        added.id,
        existing.id,
      ]);
      expect(storage.values.map((item) => item.id), [added.id, existing.id]);
    },
  );

  test(
    'import merges by id, updates duplicates, and persists newest first',
    () async {
      final existing = _favorite('12', DateTime.utc(2026, 7, 20));
      final replacement = FavoriteEntry(
        id: existing.id,
        title: 'Updated favorite',
        details: existing.details,
        origin: existing.origin,
        savedAt: DateTime.utc(2026, 7, 22),
        result: existing.result,
      );
      final added = _favorite('19', DateTime.utc(2026, 7, 21));
      final storage = _MemoryFavoritesStorage([existing]);
      final controller = FavoritesController(storage);
      addTearDown(controller.dispose);

      final result = await controller.importFavorites([replacement, added]);

      expect(result.added, 1);
      expect(result.updated, 1);
      expect(result.unchanged, 0);
      expect(controller.favorites.map((item) => item.title), [
        replacement.title,
        added.title,
      ]);
      expect(storage.values.map((item) => item.id), [replacement.id, added.id]);
    },
  );

  test('import rolls back when persistence fails', () async {
    final existing = _favorite('12', DateTime.utc(2026, 7, 20));
    final storage = _FailingFavoritesStorage([existing]);
    final controller = FavoritesController(storage);
    addTearDown(controller.dispose);
    await controller.load();

    await expectLater(
      controller.importFavorites([_favorite('19', DateTime.utc(2026, 7, 21))]),
      throwsA(isA<StateError>()),
    );

    expect(controller.favorites.map((item) => item.id), [existing.id]);
  });
}

FavoriteEntry _favorite(String edo, DateTime savedAt) {
  return FavoriteEntry.fromCalculator(
    input: CalculatorInput(
      subgroup: '5',
      source: CalculationSource.edos,
      reduction: GeneratorReduction.octave,
      weight: TuningWeight.weil,
      edos: edo,
    ),
    result: _result,
    savedAt: savedAt,
  );
}

class _MemoryFavoritesStorage implements FavoritesStorage {
  _MemoryFavoritesStorage([List<FavoriteEntry> initial = const []])
    : values = List.of(initial);

  List<FavoriteEntry> values;

  @override
  Future<List<FavoriteEntry>> load() async => List.of(values);

  @override
  Future<void> save(List<FavoriteEntry> favorites) async {
    values = List.of(favorites);
  }
}

class _DelayedFavoritesStorage implements FavoritesStorage {
  final loadResult = Completer<List<FavoriteEntry>>();
  List<FavoriteEntry> values = [];

  @override
  Future<List<FavoriteEntry>> load() => loadResult.future;

  @override
  Future<void> save(List<FavoriteEntry> favorites) async {
    values = List.of(favorites);
  }
}

class _FailingFavoritesStorage extends _MemoryFavoritesStorage {
  _FailingFavoritesStorage(super.initial);

  @override
  Future<void> save(List<FavoriteEntry> favorites) {
    throw StateError('save failed');
  }
}
