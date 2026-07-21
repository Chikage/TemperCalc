import 'dart:math' as math;

import '../core/double_matrix.dart';
import '../core/int_matrix.dart';
import '../core/lattice.dart';
import '../core/rational.dart';
import 'input_parser.dart';
import 'interval.dart';
import 'family_catalog.dart';
import 'metrics.dart';
import 'models.dart';
import 'temperament_builder.dart';

const _detailPrecision = 9;

class TemperamentInfoService {
  const TemperamentInfoService();

  TemperamentInfo calculate(CalculatorInput input) {
    try {
      final definition = buildTemperament(input);
      return _createInfo(definition, input);
    } on TemperamentException {
      rethrow;
    } on RangeError {
      throw const TemperamentException(
        'A calculation exceeded the supported range',
      );
    } on ArgumentError catch (error) {
      throw TemperamentException(error.message?.toString() ?? 'Invalid input');
    } on StateError catch (error) {
      throw TemperamentException(error.message);
    }
  }

  TemperamentInfo _createInfo(
    TemperamentDefinition definition,
    CalculatorInput input,
  ) {
    var mapping = definition.mapping;
    final expandedMapping = definition.expandedMapping;
    final basis = definition.basis;
    final expanded = definition.expanded;
    final subgroup = definition.subgroup;
    final expandedSubgroup = expanded
        .map(Rational.fromInt)
        .toList(growable: false);

    final basisDouble = DoubleMatrix.fromIntMatrix(basis);
    final wilsonExpandedInverse = metricWilson(expandedSubgroup).inverse();
    final wilson = _symmetrize(
      basisDouble
          .transpose()
          .multiply(wilsonExpandedInverse)
          .multiply(basisDouble),
    );
    var commas = weightedLll(kernel(mapping), weight: wilson, delta: 0.99);
    commas = _positiveColumns(commas, subgroup);

    final commaInfo = <CommaInfo>[];
    for (var column = 0; column < commas.columnCount; column++) {
      final vector = commas.column(column);
      commaInfo.add(
        CommaInfo(
          vector: _toIntsChecked(vector),
          ratio: ratioFromVector(vector, subgroup).toString(),
        ),
      );
    }

    final first = subgroup.first;
    final divisionRoot = first == Rational.fromInt(2)
        ? 'edo'
        : first == Rational.fromInt(3)
        ? 'edt'
        : 'ed$first';
    late String equalDivisionsLabel;
    late List<String> equalDivisions;
    String? equalDivisionJoinLabel;
    String? equalDivisionJoin;
    if (mapping.rowCount == 1) {
      equalDivisionsLabel = divisionRoot;
      equalDivisions = [edoMapNotation(mapping.row(0), subgroup)];
    } else {
      equalDivisionsLabel = '${divisionRoot}s';
      equalDivisions = findEdos(
        mapping,
        subgroup,
      ).map((map) => edoMapNotation(map.row(0), subgroup)).toList();

      final edoProjection = _symmetrize(
        projectedSubgroupMetric(
          basis,
          metricWeilK(expandedSubgroup, 1200.0),
        ).inverse(),
      );
      var joinMaps = weightedLll(
        mapping.transpose(),
        weight: edoProjection,
      ).transpose();
      joinMaps = _positiveFirstEntryRows(joinMaps);
      final rows = joinMaps.values.map(List<BigInt>.of).toList()
        ..sort((left, right) => left.first.compareTo(right.first));
      equalDivisionJoinLabel = '$divisionRoot join';
      equalDivisionJoin = rows
          .map((row) => edoMapNotation(row, subgroup))
          .join(' & ');
    }

    var reduction = input.reduction;
    if (mapping.rowCount == 1) reduction = GeneratorReduction.off;
    if (reduction == GeneratorReduction.layout) {
      final layoutProjection = _symmetrize(
        projectedSubgroupMetric(
          basis,
          metricWeilK(expandedSubgroup, 15.0),
        ).inverse(),
      );
      final quotient = _symmetrize(
        DoubleMatrix.fromIntMatrix(mapping)
            .multiply(layoutProjection)
            .multiply(DoubleMatrix.fromIntMatrix(mapping).transpose())
            .inverse(),
      );
      final generatorTransform = weightedLll(
        IntMatrix.identity(mapping.rowCount),
        weight: quotient,
      );
      mapping = solveDiophantine(generatorTransform, mapping);
    }

    var generators = simplifyIntervals(
      preimage(mapping),
      commas,
      weight: wilson,
    );
    var oriented = _orientGenerators(mapping, generators, subgroup);
    mapping = oriented.mapping;
    generators = oriented.generators;

    if (reduction == GeneratorReduction.layout) {
      final order = List<int>.generate(generators.columnCount, (index) => index)
        ..sort(
          (left, right) => logInterval(
            generators.column(right),
            subgroup,
          ).compareTo(logInterval(generators.column(left), subgroup)),
        );
      generators = _reorderColumns(generators, order);
      mapping = _reorderRows(mapping, order);
    } else if (reduction == GeneratorReduction.octave) {
      final reduced = _reduceByEquave(mapping, generators, subgroup);
      mapping = reduced.mapping;
      generators = reduced.generators;
    } else if (reduction == GeneratorReduction.spine) {
      final reduced = _spineReduce(
        mapping,
        generators,
        commas,
        subgroup,
        wilson,
      );
      mapping = reduced.mapping;
      generators = reduced.generators;
    }

    final preimageRatios = List<String>.generate(
      generators.columnCount,
      (column) =>
          ratioFromVector(generators.column(column), subgroup).toString(),
    );

    final equave = factorInterval(first, expanded);
    final unconstrained = leastSquaresTuning(
      expandedMapping,
      expandedSubgroup,
      weight: input.weight,
    );
    final constrained = constrainedTuning(
      expandedMapping,
      expandedSubgroup,
      weight: input.weight,
      constraints: DoubleMatrix.fromIntMatrix(equave),
    );
    final unconstrainedGenerators = _transformTuning(
      unconstrained.generators,
      expandedMapping,
      basis,
      generators,
    );
    final constrainedGenerators = _transformTuning(
      constrained.generators,
      expandedMapping,
      basis,
      generators,
    );
    final subgroupLogs = logSubgroup(subgroup);
    final unconstrainedPrimes = _rowTimesInt(unconstrainedGenerators, mapping);
    final constrainedPrimes = _rowTimesInt(constrainedGenerators, mapping);
    final unconstrainedErrors = List<double>.generate(
      subgroup.length,
      (index) => unconstrainedPrimes[index] - subgroupLogs[index],
    );
    final constrainedErrors = List<double>.generate(
      subgroup.length,
      (index) => constrainedPrimes[index] - subgroupLogs[index],
    );

    final abbreviation = input.weight.abbreviation;
    String formatCents(double value) =>
        cents(value, precision: _detailPrecision);
    final tunings = <String, List<String>>{
      '$abbreviation tuning': unconstrainedGenerators.map(formatCents).toList(),
      'C$abbreviation tuning': constrainedGenerators.map(formatCents).toList(),
    };
    final errors = <String, List<String>>{
      '$abbreviation errors': unconstrainedErrors.map(formatCents).toList(),
      'C$abbreviation errors': constrainedErrors.map(formatCents).toList(),
    };
    final primes = <String, List<String>>{
      '$abbreviation primes': unconstrainedPrimes.map(formatCents).toList(),
      'C$abbreviation primes': constrainedPrimes.map(formatCents).toList(),
    };

    final targetIntervals = input.target.trim().isEmpty
        ? const <IntMatrix>[]
        : parseIntervals(input.target, basis, expanded);
    if (targetIntervals.isNotEmpty) {
      final targets = IntMatrix.horizontalStack(
        targetIntervals,
        rowCount: expanded.length,
      );
      final targetMatrix = DoubleMatrix.fromIntMatrix(targets);
      final targetSolution = targets.columnCount >= expandedMapping.rowCount
          ? leastSquaresTuning(
              expandedMapping,
              expandedSubgroup,
              weight: TuningWeight.unweighted,
              targets: targetMatrix,
            )
          : constrainedTuning(
              expandedMapping,
              expandedSubgroup,
              weight: input.weight,
              constraints: targetMatrix,
            );
      final targetGenerators = _transformTuning(
        targetSolution.generators,
        expandedMapping,
        basis,
        generators,
      );
      final targetPrimes = _rowTimesInt(targetGenerators, mapping);
      final targetErrors = List<double>.generate(
        subgroup.length,
        (index) => targetPrimes[index] - subgroupLogs[index],
      );
      final targetNames = List<String>.generate(
        targets.columnCount,
        (column) => ratioFromVector(
          targets.column(column),
          expandedSubgroup,
        ).toString(),
      );
      tunings['target tuning (${targetNames.join(', ')})'] = targetGenerators
          .map(formatCents)
          .toList();
      errors['target errors'] = targetErrors.map(formatCents).toList();
      primes['target primes'] = targetPrimes.map(formatCents).toList();
    }

    final tenneyProjection = basisDouble
        .transpose()
        .multiply(metricTenney(expandedSubgroup).inverse())
        .multiply(basisDouble);
    final tenneyInverse = _symmetrize(tenneyProjection.inverse());
    final badness = temperamentBadness(
      mapping,
      subgroup,
      weight: tenneyInverse,
    );
    final complexity = temperamentComplexity(
      mapping,
      subgroup,
      weight: tenneyInverse,
    );

    final familyMatches = searchFamilies(expanded, expandedMapping);
    return TemperamentInfo(
      rank: mapping.rowCount,
      subgroup: subgroup.join('.'),
      families: (familyMatches.strong.toList()..sort()),
      weakFamilies: (familyMatches.weak.toList()..sort()),
      commaBasis: List.unmodifiable(commaInfo),
      equalDivisionsLabel: equalDivisionsLabel,
      equalDivisions: List.unmodifiable(equalDivisions),
      equalDivisionJoinLabel: equalDivisionJoinLabel,
      equalDivisionJoin: equalDivisionJoin,
      mapping: mapping.toIntsChecked(),
      preimage: List.unmodifiable(preimageRatios),
      tunings: Map.unmodifiable(tunings),
      errors: Map.unmodifiable(errors),
      primes: Map.unmodifiable(primes),
      badness: badness?.toStringAsFixed(_detailPrecision) ?? 'NA',
      complexity: complexity?.toStringAsFixed(_detailPrecision) ?? 'NA',
    );
  }
}

List<IntMatrix> findEdos(IntMatrix mapping, List<Rational> subgroup) {
  if (mapping.rowCount == 1) return const [];
  final commas = kernel(mapping);
  final candidates = <({IntMatrix map, double badness})>[];
  final divisions = <BigInt>{};
  var checked = 0;
  for (final map in generalPatentMaps((4.5, 1999.5), subgroup)) {
    checked++;
    if (checked > 20000) break;
    if (!map.multiply(commas).isZero) continue;
    var gcd = BigInt.zero;
    for (final value in map.flatten()) {
      gcd = gcd.gcd(value.abs());
    }
    if (gcd != BigInt.one) continue;
    final badness = temperamentBadness(map, subgroup);
    if (badness == null) continue;
    candidates.add((map: map, badness: badness));
    if (divisions.add(map[0][0]) && divisions.length > mapping.rowCount + 50) {
      break;
    }
  }
  candidates.sort((left, right) => left.badness.compareTo(right.badness));
  final seen = <BigInt>{};
  final result = <IntMatrix>[];
  for (final candidate in candidates) {
    if (seen.add(candidate.map[0][0])) result.add(candidate.map);
    if (result.length >= mapping.rowCount + 12) break;
  }
  return result;
}

Iterable<IntMatrix> generalPatentMaps(
  (double, double) bounds,
  List<Rational> subgroup,
) sync* {
  final logs = logSubgroup(subgroup);
  final normalized = logs.map((value) => value / logs.first).toList();
  if (normalized.any((value) => value < 0)) {
    throw const TemperamentException('Subgroup must be ordered above 1/1');
  }
  var current = patentMap(bounds.$1, subgroup).row(0).toList();
  final upper = List<double>.generate(
    current.length,
    (index) => (current[index].toDouble() + 0.5) / normalized[index],
  );
  var first = true;
  while (true) {
    if (!first) {
      var increment = 0;
      for (var index = 1; index < upper.length; index++) {
        if (upper[index] < upper[increment]) increment = index;
      }
      current[increment] += BigInt.one;
      upper[increment] += 1.0 / normalized[increment];
    }
    first = false;
    if (upper.reduce(math.min) >= bounds.$2) return;
    yield IntMatrix.fromRows([List<BigInt>.of(current)]);
  }
}

({IntMatrix mapping, IntMatrix generators}) _orientGenerators(
  IntMatrix mapping,
  IntMatrix generators,
  List<Rational> subgroup,
) {
  final mapRows = mapping.toMutableRows();
  final genRows = generators.toMutableRows();
  for (var column = 0; column < generators.columnCount; column++) {
    if (logInterval(generators.column(column), subgroup) >= 0) continue;
    for (var index = 0; index < mapping.columnCount; index++) {
      mapRows[column][index] = -mapRows[column][index];
    }
    for (var row = 0; row < generators.rowCount; row++) {
      genRows[row][column] = -genRows[row][column];
    }
  }
  return (
    mapping: IntMatrix.fromRows(mapRows, columnCount: mapping.columnCount),
    generators: IntMatrix.fromRows(
      genRows,
      columnCount: generators.columnCount,
    ),
  );
}

({IntMatrix mapping, IntMatrix generators}) _reduceByEquave(
  IntMatrix mapping,
  IntMatrix generators,
  List<Rational> subgroup,
) {
  final mapRows = mapping.toMutableRows();
  final genRows = generators.toMutableRows();
  final octaveMultiplier = mapRows[0][0];
  final equave = logSubgroup(subgroup).first;
  for (var column = 1; column < generators.columnCount; column++) {
    final floorReduction =
        (logInterval(generators.column(column), subgroup) / equave).floor();
    genRows[0][column] -= BigInt.from(floorReduction);
    for (var index = 0; index < mapping.columnCount; index++) {
      mapRows[0][index] +=
          octaveMultiplier *
          BigInt.from(floorReduction) *
          mapRows[column][index];
    }
  }
  return (
    mapping: IntMatrix.fromRows(mapRows, columnCount: mapping.columnCount),
    generators: IntMatrix.fromRows(
      genRows,
      columnCount: generators.columnCount,
    ),
  );
}

({IntMatrix mapping, IntMatrix generators}) _spineReduce(
  IntMatrix mapping,
  IntMatrix generators,
  IntMatrix commas,
  List<Rational> subgroup,
  DoubleMatrix wilson,
) {
  var reduced = _reduceFirstByEquave(mapping, generators, subgroup, 2);
  var reducedMapping = reduced.mapping;
  var reducedGenerators = reduced.generators;
  if (reducedMapping.rowCount > 2) {
    final mapRows = reducedMapping.toMutableRows();
    final genRows = reducedGenerators.toMutableRows();
    final octaveMultiplier = mapRows[0][0];
    final spineMultiplier = mapRows[1][1];
    final equave = logSubgroup(subgroup).first;
    final spine = logInterval(reducedGenerators.column(1), subgroup);
    const cutoff = 0.04736875252;
    const alternating = <int>[
      0,
      1,
      -1,
      2,
      -2,
      3,
      -3,
      4,
      -4,
      5,
      -5,
      6,
      -6,
      7,
      -7,
      8,
      -8,
      9,
      -9,
      10,
      -10,
      11,
      -11,
      12,
      -12,
    ];
    for (var column = 2; column < reducedGenerators.columnCount; column++) {
      final size = logInterval(reducedGenerators.column(column), subgroup);
      for (final multiplier in alternating) {
        var candidate = size + spineMultiplier.toDouble() * multiplier * spine;
        final equaveReduction = -roundTiesToEven(candidate / equave);
        candidate += equave * equaveReduction;
        if (candidate.abs() > cutoff) continue;
        for (var row = 0; row < reducedGenerators.rowCount; row++) {
          genRows[row][column] +=
              spineMultiplier * BigInt.from(multiplier) * genRows[row][1] +
              octaveMultiplier * BigInt.from(equaveReduction) * genRows[row][0];
        }
        for (var index = 0; index < reducedMapping.columnCount; index++) {
          mapRows[1][index] -=
              spineMultiplier *
              BigInt.from(multiplier) *
              mapRows[column][index];
          mapRows[0][index] -=
              octaveMultiplier *
              BigInt.from(equaveReduction) *
              mapRows[column][index];
        }
        break;
      }
    }
    reducedMapping = IntMatrix.fromRows(
      mapRows,
      columnCount: reducedMapping.columnCount,
    );
    reducedGenerators = IntMatrix.fromRows(
      genRows,
      columnCount: reducedGenerators.columnCount,
    );
    reducedGenerators = simplifyIntervals(
      reducedGenerators,
      commas,
      weight: wilson,
    );
    reduced = _orientGenerators(reducedMapping, reducedGenerators, subgroup);
  }
  return reduced;
}

({IntMatrix mapping, IntMatrix generators}) _reduceFirstByEquave(
  IntMatrix mapping,
  IntMatrix generators,
  List<Rational> subgroup,
  int count,
) {
  final mapRows = mapping.toMutableRows();
  final genRows = generators.toMutableRows();
  final octaveMultiplier = mapRows[0][0];
  final equave = logSubgroup(subgroup).first;
  for (
    var column = 1;
    column < math.min(count, generators.columnCount);
    column++
  ) {
    final reduction =
        (logInterval(generators.column(column), subgroup) / equave).floor();
    genRows[0][column] -= BigInt.from(reduction);
    for (var index = 0; index < mapping.columnCount; index++) {
      mapRows[0][index] +=
          octaveMultiplier * BigInt.from(reduction) * mapRows[column][index];
    }
  }
  return (
    mapping: IntMatrix.fromRows(mapRows, columnCount: mapping.columnCount),
    generators: IntMatrix.fromRows(
      genRows,
      columnCount: generators.columnCount,
    ),
  );
}

IntMatrix _positiveColumns(IntMatrix matrix, List<Rational> subgroup) =>
    IntMatrix.fromRows(
      List.generate(
        matrix.rowCount,
        (row) => List.generate(matrix.columnCount, (column) {
          final vector = matrix.column(column);
          return logInterval(vector, subgroup) < 0
              ? -matrix[row][column]
              : matrix[row][column];
        }),
      ),
      columnCount: matrix.columnCount,
    );

IntMatrix _positiveFirstEntryRows(IntMatrix matrix) => IntMatrix.fromRows(
  List.generate(matrix.rowCount, (row) {
    final sign = matrix[row].isNotEmpty && matrix[row][0] < BigInt.zero
        ? -BigInt.one
        : BigInt.one;
    return matrix[row].map((value) => value * sign);
  }),
  columnCount: matrix.columnCount,
);

IntMatrix _reorderColumns(IntMatrix matrix, List<int> order) =>
    IntMatrix.fromRows(
      List.generate(
        matrix.rowCount,
        (row) => order.map((column) => matrix[row][column]),
      ),
      columnCount: order.length,
    );

IntMatrix _reorderRows(IntMatrix matrix, List<int> order) =>
    IntMatrix.fromRows(order.map(matrix.row), columnCount: matrix.columnCount);

List<double> _transformTuning(
  List<double> tuning,
  IntMatrix expandedMapping,
  IntMatrix basis,
  IntMatrix generators,
) => _rowTimesInt(
  _rowTimesInt(_rowTimesInt(tuning, expandedMapping), basis),
  generators,
);

List<double> _rowTimesInt(List<double> row, IntMatrix matrix) {
  if (row.length != matrix.rowCount) {
    throw ArgumentError('Row and matrix dimensions differ');
  }
  return List<double>.generate(matrix.columnCount, (column) {
    var sum = 0.0;
    var correction = 0.0;
    for (var index = 0; index < row.length; index++) {
      final product = row[index] * matrix[index][column].toDouble();
      final updated = sum + product;
      correction += sum.abs() >= product.abs()
          ? (sum - updated) + product
          : (product - updated) + sum;
      sum = updated;
    }
    return sum + correction;
  });
}

List<int> _toIntsChecked(List<BigInt> values) =>
    IntMatrix.fromRows([values]).toIntsChecked().single;

DoubleMatrix _symmetrize(DoubleMatrix matrix) => DoubleMatrix.fromRows(
  List.generate(
    matrix.rowCount,
    (row) => List.generate(
      matrix.columnCount,
      (column) => (matrix[row][column] + matrix[column][row]) / 2.0,
    ),
  ),
  columnCount: matrix.columnCount,
);
