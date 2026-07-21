import 'dart:math' as math;

import '../core/double_matrix.dart';
import '../core/int_matrix.dart';
import '../core/lattice.dart';
import '../core/rational.dart';
import 'family_catalog.dart';
import 'input_parser.dart';
import 'interval.dart';
import 'metrics.dart';
import 'models.dart';
import 'temperament_builder.dart';

const _maximumCommaCoefficient = 2000;
const _combinationBudget = 320;

class TemperamentSearchService {
  const TemperamentSearchService();

  TemperamentSearchResult search(SearchInput input) {
    try {
      return _search(input);
    } on TemperamentException {
      rethrow;
    } on RangeError {
      throw const TemperamentException('A search exceeded the supported range');
    } on ArgumentError catch (error) {
      throw TemperamentException(error.message?.toString() ?? 'Invalid search');
    } on StateError catch (error) {
      throw TemperamentException(error.message);
    }
  }

  TemperamentSearchResult _search(SearchInput input) {
    final subgroupDefinition = parseSubgroup(input.subgroup);
    final basis = subgroupDefinition.basis;
    final expanded = subgroupDefinition.expanded;
    final subgroup = subgroupDefinition.subgroup;
    final expandedSubgroup = expanded
        .map(Rational.fromInt)
        .toList(growable: false);
    final nonPrimeSubgroup =
        basis.rowCount != basis.columnCount ||
        basis != IntMatrix.identity(basis.rowCount);

    var initialMap = IntMatrix.identity(subgroup.length);
    var searchUp = false;
    if (input.edos.trim().isNotEmpty) {
      initialMap = temperamentFromEdos(input.edos, basis, expanded).mapping;
      searchUp = true;
    } else if (input.commas.trim().isNotEmpty) {
      initialMap = temperamentFromCommas(input.commas, basis, expanded).mapping;
    }

    final rank = initialMap.rowCount;
    final dimension = initialMap.columnCount;
    if (dimension > input.parameters.maximumDimension) {
      return TemperamentSearchResult(
        groups: [],
        warning:
            'Search is limited to subgroup dimensions of '
            '${input.parameters.maximumDimension} or less',
      );
    }

    final subgroupSize = expanded
        .map((prime) => math.log(prime) / math.ln2)
        .reduce(math.max);
    final tenney = projectedSubgroupMetric(
      basis,
      metricTenney(expandedSubgroup),
    );
    final tenneyInverse = normalizeDeterminant(_symmetric(tenney.inverse()));
    final cangwuK = 800.0 * math.sqrt(rank / 4.0);
    final weil = projectedSubgroupMetric(
      basis,
      metricWeilK(expandedSubgroup, cangwuK),
    );
    final weilInverse = normalizeDeterminant(_symmetric(weil.inverse()));
    final wilson = _symmetric(
      projectedSubgroupMetric(basis, metricWilson(expandedSubgroup)),
    );
    final edoMetric = _symmetric(
      projectedSubgroupMetric(
        basis,
        metricWeilK(expandedSubgroup, 1200.0 * subgroupSize),
      ).inverse(),
    );
    final calibration = height(
      DoubleMatrix.fromIntMatrix(patentMap(41.0, subgroup)),
      tenneyInverse,
    );
    if (calibration == null) {
      throw const TemperamentException('Could not calibrate search complexity');
    }
    final complexityFactor = 41.0 / calibration;

    double badness(IntMatrix mapping) {
      if (input.badness == BadnessType.dirichlet) {
        return temperamentBadness(mapping, subgroup, weight: tenneyInverse) ??
            0.0;
      }
      return height(DoubleMatrix.fromIntMatrix(mapping), weilInverse) ?? 0.0;
    }

    final byRank = <int, List<_SearchEntry>>{};
    final checked = <String>{};

    if (searchUp) {
      if (rank + 1 >= dimension) {
        return const TemperamentSearchResult(
          groups: [],
          warning: 'Empty search',
        );
      }
      for (
        var candidateRank = rank + 1;
        candidateRank < dimension;
        candidateRank++
      ) {
        byRank[candidateRank] = [];
      }
      var lattice = kernel(initialMap);
      var factor = 8.0 * subgroupSize;
      final growth = math.min(1.4 * math.pow(1.1, dimension - 1), 2.0);
      final commas = <_SearchEntry>[];
      for (
        var iteration = 0;
        iteration < input.parameters.explorationIterations;
        iteration++
      ) {
        try {
          final metric = _symmetric(
            projectedSubgroupMetric(
              basis,
              metricWeilK(expandedSubgroup, factor),
            ),
          );
          lattice = weightedLll(lattice, weight: metric);
        } on StateError {
          break;
        } on ArgumentError {
          break;
        }
        if (lattice.flatten().any(
          (value) => value.abs() > BigInt.from(_maximumCommaCoefficient),
        )) {
          break;
        }
        factor *= growth;
        for (var column = 0; column < lattice.columnCount; column++) {
          final comma = makePositive(lattice.column(column), subgroup);
          final commaMatrix = IntMatrix.fromRows(
            comma.map((value) => [value]),
            columnCount: 1,
          );
          var label = ratioFromVector(comma, subgroup).toString();
          if (label.length >= 11) label = '[${comma.join(' ')}]';
          final mapping = cokernel(commaMatrix);
          final entry = _SearchEntry(label, mapping, badness(mapping));
          final key = _vectorKey(comma);
          if (checked.add(key)) {
            byRank[dimension - 1]!.add(entry);
            commas.add(entry.copyWithVector(comma));
          }
        }
      }
      commas.sort((left, right) => left.badness.compareTo(right.badness));
      final maximumPerRank = math.max(
        input.parameters.resultsPerRank,
        _combinationBudget ~/ math.max(1, dimension - 2),
      );
      for (var commaCount = 2; commaCount < dimension - rank; commaCount++) {
        var count = 0;
        for (final indices in combinationsBySum(
          commaCount,
          0,
          commas.length - 1,
        )) {
          final selected = indices.map((index) => commas[index]).toList();
          final commaMatrix = IntMatrix.fromRows(
            List.generate(
              dimension,
              (row) => selected.map((entry) => entry.vector![row]),
            ),
            columnCount: selected.length,
          );
          final mapping = cokernel(commaMatrix);
          if (_hasZeroColumn(mapping)) continue;
          final key = _matrixKey(mapping);
          if (!checked.add(key)) continue;
          final label = selected.map((entry) => entry.label).join(', ');
          byRank[dimension - commaCount]!.add(
            _SearchEntry(label, mapping, badness(mapping)),
          );
          count++;
          if (count >= maximumPerRank) break;
        }
      }
    } else {
      if (rank == 1) {
        return const TemperamentSearchResult(
          groups: [],
          warning: 'Empty search',
        );
      }
      for (var candidateRank = 1; candidateRank < rank; candidateRank++) {
        byRank[candidateRank] = [];
      }
      var factor = 16.0 * math.sqrt(rank) * subgroupSize;
      final growth = 1.4 * math.pow(1.1, dimension - 1);
      var lattice = initialMap;
      final edos = <_SearchEntry>[];
      for (
        var iteration = 0;
        iteration < input.parameters.explorationIterations;
        iteration++
      ) {
        try {
          final metric = _symmetric(
            projectedSubgroupMetric(
              basis,
              metricWeilK(expandedSubgroup, factor),
            ).inverse(),
          );
          lattice = weightedLll(
            lattice.transpose(),
            weight: metric,
          ).transpose();
        } on StateError {
          break;
        } on ArgumentError {
          break;
        }
        factor *= growth;
        final found = _absolute(lattice);
        if (found.values.any(
          (row) => row.first > BigInt.from(input.parameters.maximumEdo * 2),
        )) {
          break;
        }
        for (final row in found.values) {
          if (row.first < BigInt.two ||
              row.first > BigInt.from(input.parameters.maximumEdo)) {
            continue;
          }
          final mapping = IntMatrix.fromRows([row]);
          final entry = _SearchEntry(
            edoMapNotation(row, subgroup),
            mapping,
            badness(mapping),
          );
          if (checked.add(_matrixKey(mapping))) {
            byRank[1]!.add(entry);
            edos.add(entry);
          }
        }
      }
      edos.sort((left, right) => left.badness.compareTo(right.badness));
      final maximumPerRank = math.max(
        input.parameters.resultsPerRank,
        _combinationBudget ~/ math.max(1, rank - 2),
      );
      for (var candidateRank = 2; candidateRank < rank; candidateRank++) {
        var count = 0;
        for (final indices in combinationsBySum(
          candidateRank,
          0,
          edos.length - 1,
        )) {
          final selected = indices.map((index) => edos[index]).toList();
          final mapping = hnf(
            IntMatrix.verticalStack(selected.map((entry) => entry.mapping)),
          );
          if (mapping.values.any(_isZeroVector)) continue;
          if (!checked.add(_matrixKey(mapping))) continue;
          selected.sort(
            (left, right) => left.mapping[0][0].compareTo(right.mapping[0][0]),
          );
          byRank[candidateRank]!.add(
            _SearchEntry(
              selected.map((entry) => entry.label).join(' & '),
              mapping,
              badness(mapping),
            ),
          );
          count++;
          if (count >= maximumPerRank) break;
        }
      }
    }

    final groups = <SearchGroup>[];
    for (final candidateRank in byRank.keys.toList()..sort()) {
      final entries = byRank[candidateRank]!
        ..sort((left, right) => left.badness.compareTo(right.badness));
      final candidates = <SearchCandidate>[];
      for (final entry in entries) {
        if (candidates.length >= input.parameters.resultsPerRank) break;
        if (factorOrder(entry.mapping) > BigInt.one) continue;
        final mapHeight = height(
          DoubleMatrix.fromIntMatrix(entry.mapping),
          tenneyInverse,
        );
        if (mapHeight == null) continue;
        final complexity =
            math.pow(2.0, entry.mapping.rowCount - 1) *
            mapHeight *
            complexityFactor;
        final expandedMapping = nonPrimeSubgroup
            ? hnf(cokernel(basis.multiply(kernel(entry.mapping))))
            : entry.mapping;
        final matches = searchFamilies(expanded, expandedMapping);
        final familyNames = <String>[
          ...matches.strong.toList()..sort(),
          if (matches.strong.isEmpty)
            ...((matches.weak.toList()..sort()).map((name) => '($name)')),
        ];

        var label = entry.label;
        var source = searchUp
            ? CalculationSource.commas
            : CalculationSource.edos;
        if (searchUp && candidateRank <= dimension - candidateRank) {
          var newBasis = weightedLll(
            entry.mapping.transpose(),
            weight: edoMetric,
          ).transpose();
          newBasis = _positiveFirstEntryRows(newBasis);
          final rows = newBasis.values.map(List<BigInt>.of).toList()
            ..sort((left, right) => left.first.compareTo(right.first));
          label = rows.map((row) => edoMapNotation(row, subgroup)).join(' & ');
          source = CalculationSource.edos;
        } else if (!searchUp && candidateRank > dimension - candidateRank) {
          final reducedCommas = weightedLll(
            kernel(entry.mapping),
            weight: wilson,
          );
          final labels = <String>[];
          for (var column = 0; column < reducedCommas.columnCount; column++) {
            final comma = makePositive(reducedCommas.column(column), subgroup);
            var commaLabel = ratioFromVector(comma, subgroup).toString();
            if (commaLabel.length >= 11) commaLabel = '[${comma.join(' ')}]';
            labels.add(commaLabel);
          }
          label = labels.join(', ');
          source = CalculationSource.commas;
        }
        candidates.add(
          SearchCandidate(
            rank: candidateRank,
            label: label,
            source: source,
            families: List.unmodifiable(familyNames),
            badness: entry.badness == 0.0 ? null : entry.badness,
            complexity: complexity.toDouble(),
          ),
        );
      }
      if (candidates.isNotEmpty) {
        groups.add(SearchGroup(rank: candidateRank, candidates: candidates));
      }
    }
    return TemperamentSearchResult(groups: List.unmodifiable(groups));
  }
}

class _SearchEntry {
  const _SearchEntry(this.label, this.mapping, this.badness, [this.vector]);

  final String label;
  final IntMatrix mapping;
  final double badness;
  final List<BigInt>? vector;

  _SearchEntry copyWithVector(List<BigInt> value) =>
      _SearchEntry(label, mapping, badness, List.unmodifiable(value));
}

Iterable<List<int>> combinationsBySum(
  int size,
  int minimum,
  int maximum,
) sync* {
  if (size <= 0 || maximum < minimum || size > maximum - minimum + 1) return;
  final minimumTotal = minimum * size + size * (size - 1) ~/ 2;
  final maximumTotal = maximum * size - size * (size - 1) ~/ 2;
  for (var total = minimumTotal; total <= maximumTotal; total++) {
    yield* _combinationsOfSum(total, size, minimum, maximum);
  }
}

Iterable<List<int>> _combinationsOfSum(
  int total,
  int size,
  int minimum,
  int maximum,
) sync* {
  if (size == 1) {
    if (total >= minimum && total <= maximum) yield [total];
    return;
  }
  final base = List<int>.generate(size, (index) => minimum + index);
  base[size - 1] = math
      .min(
        total - base.take(size - 1).fold<int>(0, (sum, value) => sum + value),
        maximum,
      )
      .toInt();
  var maximumOffset = base[size - 1] - base[size - 2] - 1;
  var totalOffset = total - base.fold<int>(0, (sum, value) => sum + value);
  final minimumLast = (total + size * (size - 1) ~/ 2) ~/ size;
  while (base[size - 1] > base[size - 2] && base[size - 1] >= minimumLast) {
    for (final offsets in _offsets(size - 1, totalOffset, maximumOffset)) {
      yield List<int>.generate(
        size,
        (index) => base[index] + (index < offsets.length ? offsets[index] : 0),
      );
    }
    base[size - 1]--;
    totalOffset++;
    maximumOffset--;
  }
}

Iterable<List<int>> _offsets(int size, int total, int maximum) sync* {
  if (total == 0) {
    yield List<int>.filled(size, 0);
    return;
  }
  if (size == 1 && total == maximum) {
    yield [maximum];
    return;
  }
  var value = maximum;
  while (total >= 0 && total <= size * value) {
    for (final prefix in _offsets(size - 1, total - value, value)) {
      yield [...prefix, value];
    }
    value--;
  }
}

bool _hasZeroColumn(IntMatrix matrix) {
  for (var column = 0; column < matrix.columnCount; column++) {
    if (_isZeroVector(matrix.column(column))) return true;
  }
  return false;
}

bool _isZeroVector(List<BigInt> vector) =>
    vector.every((value) => value == BigInt.zero);

String _vectorKey(List<BigInt> vector) => vector.join(',');
String _matrixKey(IntMatrix matrix) =>
    '${matrix.rowCount}x${matrix.columnCount}:${matrix.flatten().join(',')}';

IntMatrix _absolute(IntMatrix matrix) => IntMatrix.fromRows(
  matrix.values.map((row) => row.map((value) => value.abs())),
  columnCount: matrix.columnCount,
);

IntMatrix _positiveFirstEntryRows(IntMatrix matrix) => IntMatrix.fromRows(
  matrix.values.map((row) {
    if (row.isNotEmpty && row.first < BigInt.zero) {
      return row.map((value) => -value);
    }
    return row;
  }),
  columnCount: matrix.columnCount,
);

DoubleMatrix _symmetric(DoubleMatrix matrix) => DoubleMatrix.fromRows(
  List.generate(
    matrix.rowCount,
    (row) => List.generate(
      matrix.columnCount,
      (column) => (matrix[row][column] + matrix[column][row]) / 2.0,
    ),
  ),
  columnCount: matrix.columnCount,
);
