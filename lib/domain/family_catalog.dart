import '../core/int_matrix.dart';
import '../core/lattice.dart';
import '../data/temperament_families.dart';
import 'input_parser.dart';
import 'interval.dart';

final class FamilyMatches {
  FamilyMatches._({required Set<String> strong, required Set<String> weak})
    : strong = Set<String>.unmodifiable(strong),
      weak = Set<String>.unmodifiable(weak);

  final Set<String> strong;
  final Set<String> weak;
}

final class FamilyCatalog {
  FamilyCatalog._(this._familiesBySubgroup);

  static final FamilyCatalog instance = FamilyCatalog._fromSeeds(
    temperamentFamilySeeds,
  );

  final Map<_SubgroupKey, Map<_MappingKey, String>> _familiesBySubgroup;

  factory FamilyCatalog._fromSeeds(List<TemperamentFamilySeed> seeds) {
    final expanded = primeLimit(19);
    final basis = IntMatrix.identity(expanded.length);
    final mutableIndex = <_SubgroupKey, Map<_MappingKey, String>>{};

    for (final seed in seeds) {
      final intervals = parseIntervals(seed.comma, basis, expanded);
      if (intervals.length != 1) {
        throw StateError(
          'Family seed ${seed.name} must contain exactly one comma',
        );
      }

      final comma = intervals.single;
      final supportIndices = <int>[
        for (var row = 0; row < comma.rowCount; row++)
          if (comma[row][0] != BigInt.zero) row,
      ];
      if (supportIndices.isEmpty) {
        throw StateError('Family seed ${seed.name} has an empty comma');
      }

      final subgroupKey = _SubgroupKey(
        supportIndices.map((index) => expanded[index]),
      );
      final restrictedComma = IntMatrix.fromRows(
        supportIndices.map((index) => <BigInt>[comma[index][0]]),
        columnCount: 1,
      );
      final mappingKey = _MappingKey(cokernel(restrictedComma).flatten());

      // Match process_names.py: a later seed replaces the same canonical key.
      (mutableIndex[subgroupKey] ??= <_MappingKey, String>{})[mappingKey] =
          seed.name;
    }

    return FamilyCatalog._(
      Map<_SubgroupKey, Map<_MappingKey, String>>.unmodifiable(
        mutableIndex.map(
          (_SubgroupKey subgroup, Map<_MappingKey, String> families) =>
              MapEntry<_SubgroupKey, Map<_MappingKey, String>>(
                subgroup,
                Map<_MappingKey, String>.unmodifiable(families),
              ),
        ),
      ),
    );
  }

  FamilyMatches search({
    required List<int> expandedSubgroup,
    required IntMatrix expandedMapping,
  }) {
    if (expandedMapping.columnCount != expandedSubgroup.length) {
      throw ArgumentError(
        'Expanded mapping columns must match the expanded subgroup',
      );
    }

    final strong = <String>{};
    final weak = <String>{};

    for (final entry in _familiesBySubgroup.entries) {
      final indices = _subgroupIndices(expandedSubgroup, entry.key.primes);
      if (indices == null) continue;

      var restrictedMapping = IntMatrix.fromRows(
        List<List<BigInt>>.generate(
          expandedMapping.rowCount,
          (row) => <BigInt>[
            for (final index in indices) expandedMapping[row][index],
          ],
        ),
        columnCount: indices.length,
      );
      restrictedMapping = hnf(restrictedMapping, removeZeroRows: true);

      if (restrictedMapping.rowCount >= restrictedMapping.columnCount) {
        continue;
      }

      final family = entry.value[_MappingKey(restrictedMapping.flatten())];
      if (family != null) strong.add(family);

      final weakFamily =
          entry.value[_MappingKey(defactoredHnf(restrictedMapping).flatten())];
      if (weakFamily != null) weak.add(weakFamily);
    }

    weak.removeAll(strong);
    return FamilyMatches._(strong: strong, weak: weak);
  }
}

FamilyMatches searchFamilies(
  List<int> expandedSubgroup,
  IntMatrix expandedMapping,
) => FamilyCatalog.instance.search(
  expandedSubgroup: expandedSubgroup,
  expandedMapping: expandedMapping,
);

List<int>? _subgroupIndices(List<int> subgroup, List<int> restriction) {
  final result = <int>[];
  for (final prime in restriction) {
    final index = subgroup.indexOf(prime);
    if (index < 0) return null;
    result.add(index);
  }
  return result;
}

final class _SubgroupKey {
  _SubgroupKey(Iterable<int> primes)
    : primes = List<int>.unmodifiable(primes),
      _hashCode = Object.hashAll(primes);

  final List<int> primes;
  final int _hashCode;

  @override
  bool operator ==(Object other) =>
      other is _SubgroupKey && _equalLists(primes, other.primes);

  @override
  int get hashCode => _hashCode;
}

final class _MappingKey {
  _MappingKey(Iterable<BigInt> entries)
    : entries = List<BigInt>.unmodifiable(entries),
      _hashCode = Object.hashAll(entries);

  final List<BigInt> entries;
  final int _hashCode;

  @override
  bool operator ==(Object other) =>
      other is _MappingKey && _equalLists(entries, other.entries);

  @override
  int get hashCode => _hashCode;
}

bool _equalLists<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
