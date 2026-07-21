import 'dart:math' as math;

import '../core/double_matrix.dart';
import '../core/int_matrix.dart';
import '../core/lattice.dart';
import '../core/rational.dart';
import 'input_parser.dart';
import 'interval.dart';
import 'models.dart';

class TuningSolution {
  const TuningSolution({required this.generators, required this.errors});

  final List<double> generators;
  final List<double> errors;
}

DoubleMatrix tuningMetric(List<Rational> subgroup, TuningWeight weight) =>
    switch (weight) {
      TuningWeight.unweighted => DoubleMatrix.identity(subgroup.length),
      TuningWeight.tenney => metricTenney(subgroup),
      TuningWeight.weil => metricWeil(subgroup),
    };

DoubleMatrix metricTenney(List<Rational> subgroup) {
  final logs = logSubgroup(subgroup);
  return DoubleMatrix.diagonal(logs.map((value) => 1.0 / (value * value)));
}

DoubleMatrix metricWilson(List<Rational> subgroup) => DoubleMatrix.diagonal(
  subgroup.map((value) {
    final number = value.toDouble();
    return 1.0 / (number * number);
  }),
);

DoubleMatrix metricWeil(List<Rational> subgroup) => metricWeilK(subgroup, 1.0);

DoubleMatrix metricWeilK(List<Rational> subgroup, double k) {
  final logs = logSubgroup(subgroup);
  final kSquared = k * k;
  final dual = DoubleMatrix.fromRows(
    List.generate(
      logs.length,
      (row) => List.generate(logs.length, (column) {
        final diagonal = row == column ? logs[row] * logs[row] : 0.0;
        return diagonal + kSquared * logs[row] * logs[column];
      }),
    ),
    columnCount: logs.length,
  );
  final metric = dual.inverse();
  return metric.scaled(1.0 / metric[0][0]);
}

TuningSolution leastSquaresTuning(
  IntMatrix mapping,
  List<Rational> subgroup, {
  TuningWeight weight = TuningWeight.tenney,
  DoubleMatrix? targets,
}) {
  final m = DoubleMatrix.fromIntMatrix(mapping);
  final j = logSubgroup(subgroup);
  late final DoubleMatrix factor;
  if (targets == null) {
    final lower = _cholesky(tuningMetric(subgroup, weight));
    if (lower == null) {
      throw StateError('Tuning metric is not positive definite');
    }
    factor = lower.transpose();
  } else {
    if (targets.rowCount != mapping.columnCount) {
      throw ArgumentError('Target vectors must match the subgroup dimension');
    }
    factor = targets.transpose();
  }
  final design = factor.multiply(m.transpose());
  final transformedJust = factor.multiplyVector(j);
  final generators = design.leastSquaresVector(transformedJust).solution;
  final tuned = m.transpose().multiplyVector(generators);
  final errors = List<double>.generate(
    j.length,
    (index) => tuned[index] - j[index],
  );
  return TuningSolution(
    generators: List.unmodifiable(generators),
    errors: List.unmodifiable(errors),
  );
}

TuningSolution constrainedTuning(
  IntMatrix mapping,
  List<Rational> subgroup, {
  TuningWeight weight = TuningWeight.tenney,
  DoubleMatrix? constraints,
}) {
  final m = DoubleMatrix.fromIntMatrix(mapping);
  final rank = mapping.rowCount;
  final dimension = mapping.columnCount;
  final j = logSubgroup(subgroup);
  final jColumn = _column(j);
  final metric = tuningMetric(subgroup, weight);
  final v =
      constraints ??
      DoubleMatrix.fromRows(
        List.generate(dimension, (row) => [row == 0 ? 1.0 : 0.0]),
        columnCount: 1,
      );
  if (v.rowCount != dimension || v.columnCount == 0) {
    throw ArgumentError('Constraint vectors must be dimension x count');
  }

  final c = m.multiply(v).transpose();
  final constraintRight = v.transpose().multiply(jColumn).column(0);
  final parameterization = _parameterizeConstraints(c, constraintRight);
  final lower = _cholesky(metric);
  if (lower == null) {
    throw StateError('Tuning metric is not positive definite');
  }
  final factor = lower.transpose();
  final design = factor.multiply(m.transpose());
  final transformedJust = factor.multiplyVector(j);
  late final List<double> generators;
  if (parameterization.nullspace.columnCount == 0) {
    generators = parameterization.particular;
  } else {
    final reducedDesign = design.multiply(parameterization.nullspace);
    final particularTuning = design.multiplyVector(parameterization.particular);
    final reducedRight = List<double>.generate(
      transformedJust.length,
      (index) => transformedJust[index] - particularTuning[index],
    );
    final free = reducedDesign.leastSquaresVector(reducedRight).solution;
    final freeContribution = parameterization.nullspace.multiplyVector(free);
    generators = List<double>.generate(
      rank,
      (index) => parameterization.particular[index] + freeContribution[index],
    );
  }
  final tuned = m.transpose().multiplyVector(generators);
  final errors = List<double>.generate(
    j.length,
    (index) => tuned[index] - j[index],
  );
  return TuningSolution(
    generators: List.unmodifiable(generators),
    errors: List.unmodifiable(errors),
  );
}

({List<double> particular, DoubleMatrix nullspace}) _parameterizeConstraints(
  DoubleMatrix constraints,
  List<double> rightHandSide, {
  double tolerance = 1e-12,
}) {
  if (constraints.rowCount != rightHandSide.length) {
    throw ArgumentError('Constraint right-hand side dimension differs');
  }
  if (constraints.rowCount > constraints.columnCount) {
    throw StateError('There are more constraints than tuning generators');
  }

  final rowCount = constraints.rowCount;
  final columnCount = constraints.columnCount;
  final rows = constraints.toMutableRows();
  final right = List<double>.of(rightHandSide);
  final scales = rows
      .map(
        (row) => row.fold<double>(
          0.0,
          (maximum, value) => math.max(maximum, value.abs()),
        ),
      )
      .toList(growable: false);
  final pivots = <int>[];
  var pivotRow = 0;
  for (var column = 0; column < columnCount && pivotRow < rowCount; column++) {
    var selected = pivotRow;
    var largest = scales[selected] == 0.0
        ? 0.0
        : rows[selected][column].abs() / scales[selected];
    for (var row = pivotRow + 1; row < rowCount; row++) {
      final magnitude = scales[row] == 0.0
          ? 0.0
          : rows[row][column].abs() / scales[row];
      if (magnitude > largest) {
        largest = magnitude;
        selected = row;
      }
    }
    if (scales[selected] == 0.0 ||
        rows[selected][column].abs() <= tolerance * scales[selected]) {
      continue;
    }
    if (selected != pivotRow) {
      final temporary = rows[pivotRow];
      rows[pivotRow] = rows[selected];
      rows[selected] = temporary;
      final rightTemporary = right[pivotRow];
      right[pivotRow] = right[selected];
      right[selected] = rightTemporary;
      final scaleTemporary = scales[pivotRow];
      scales[pivotRow] = scales[selected];
      scales[selected] = scaleTemporary;
    }

    final pivot = rows[pivotRow][column];
    for (var target = 0; target < columnCount; target++) {
      rows[pivotRow][target] /= pivot;
    }
    right[pivotRow] /= pivot;
    for (var row = 0; row < rowCount; row++) {
      if (row == pivotRow) continue;
      final multiplier = rows[row][column];
      if (multiplier == 0.0) continue;
      for (var target = 0; target < columnCount; target++) {
        rows[row][target] -= multiplier * rows[pivotRow][target];
      }
      right[row] -= multiplier * right[pivotRow];
    }
    pivots.add(column);
    pivotRow++;
  }
  if (pivots.length != rowCount) {
    throw StateError('Constraint vectors are numerically rank deficient');
  }

  final pivotSet = pivots.toSet();
  final freeColumns = [
    for (var column = 0; column < columnCount; column++)
      if (!pivotSet.contains(column)) column,
  ];
  final particular = List<double>.filled(columnCount, 0.0);
  for (var row = 0; row < rowCount; row++) {
    particular[pivots[row]] = right[row];
  }
  final nullspace = DoubleMatrix.fromRows(
    List.generate(columnCount, (row) {
      return List<double>.generate(freeColumns.length, (column) {
        if (row == freeColumns[column]) return 1.0;
        final pivotIndex = pivots.indexOf(row);
        return pivotIndex < 0 ? 0.0 : -rows[pivotIndex][freeColumns[column]];
      });
    }),
    columnCount: freeColumns.length,
  );
  return (
    particular: List<double>.unmodifiable(particular),
    nullspace: nullspace,
  );
}

double? height(DoubleMatrix matrix, DoubleMatrix weight) {
  if (weight.rowCount != matrix.columnCount ||
      weight.columnCount != matrix.columnCount) {
    throw ArgumentError('Weight matrix dimension does not match the vectors');
  }
  if (matrix.rowCount > matrix.columnCount) return null;
  if (matrix.rowCount == 0) return 1.0;

  final lower = _cholesky(weight);
  if (lower == null) return null;
  final transformed = matrix.multiply(lower);
  final work = transformed.transpose().toMutableRows();
  var logVolume = 0.0;

  for (var column = 0; column < matrix.rowCount; column++) {
    final norm = _stableNorm(
      List<double>.generate(
        work.length - column,
        (offset) => work[column + offset][column],
      ),
    );
    if (!norm.isFinite || norm == 0.0) return null;
    logVolume += math.log(norm);

    final alpha = work[column][column] >= 0.0 ? -norm : norm;
    final reflector = List<double>.generate(
      work.length - column,
      (offset) => work[column + offset][column],
    );
    reflector[0] -= alpha;
    final reflectorNorm = _stableNorm(reflector);
    if (reflectorNorm == 0.0 || !reflectorNorm.isFinite) return null;
    for (var index = 0; index < reflector.length; index++) {
      reflector[index] /= reflectorNorm;
    }
    for (var target = column; target < matrix.rowCount; target++) {
      var projection = 0.0;
      for (var index = 0; index < reflector.length; index++) {
        projection += reflector[index] * work[column + index][target];
      }
      for (var index = 0; index < reflector.length; index++) {
        work[column + index][target] -= 2.0 * projection * reflector[index];
      }
    }
  }

  if (logVolume <= math.log(1e-4)) return null;
  final volume = math.exp(logVolume);
  return volume.isFinite ? volume : null;
}

DoubleMatrix? _cholesky(DoubleMatrix matrix) {
  if (!matrix.isSquare) return null;
  final size = matrix.rowCount;
  final lower = List.generate(size, (_) => List<double>.filled(size, 0.0));
  for (var row = 0; row < size; row++) {
    for (var column = 0; column <= row; column++) {
      var value = (matrix[row][column] + matrix[column][row]) / 2.0;
      for (var index = 0; index < column; index++) {
        value -= lower[row][index] * lower[column][index];
      }
      if (row == column) {
        if (!value.isFinite || value <= 0.0) return null;
        lower[row][column] = math.sqrt(value);
      } else {
        lower[row][column] = value / lower[column][column];
      }
    }
  }
  return DoubleMatrix.fromRows(lower, columnCount: size);
}

double _stableNorm(List<double> values) {
  var scale = 0.0;
  var sumSquares = 1.0;
  for (final value in values) {
    final magnitude = value.abs();
    if (magnitude == 0.0) continue;
    if (scale < magnitude) {
      final ratio = scale / magnitude;
      sumSquares = 1.0 + sumSquares * ratio * ratio;
      scale = magnitude;
    } else {
      final ratio = magnitude / scale;
      sumSquares += ratio * ratio;
    }
  }
  return scale == 0.0 ? 0.0 : scale * math.sqrt(sumSquares);
}

double? temperamentBadness(
  IntMatrix mapping,
  List<Rational> subgroup, {
  DoubleMatrix? weight,
}) {
  final rank = mapping.rowCount;
  final dimension = mapping.columnCount;
  if (dimension <= rank || dimension == 0) return null;
  final logs = logSubgroup(subgroup);
  var metric =
      weight ??
      DoubleMatrix.diagonal(logs.map((value) => 1.0 / (value * value)));
  final determinant = metric.determinant();
  if (!determinant.isFinite || determinant <= 0) return null;
  metric = metric.scaled(1.0 / math.pow(determinant, 1.0 / dimension));

  final m = DoubleMatrix.fromIntMatrix(mapping);
  final j = DoubleMatrix.fromRows([logs]);
  final mapHeight = height(m, metric);
  final justHeight = height(j, metric);
  final lower = _cholesky(metric);
  if (mapHeight == null || justHeight == null || lower == null) {
    return null;
  }
  late final double errorHeight;
  if (rank + 1 == dimension) {
    final exactHeight = _codimensionOneErrorHeight(mapping, logs, lower);
    if (exactHeight == null) return null;
    errorHeight = exactHeight;
  } else {
    final factor = lower.transpose();
    final design = factor.multiply(m.transpose());
    final transformedJust = factor.multiplyVector(logs);
    late final LeastSquaresResult fit;
    try {
      fit = design.leastSquaresVector(transformedJust);
    } on StateError {
      return null;
    }
    final residualNorm = _stableNorm(fit.transformedResidual);
    errorHeight = mapHeight * residualNorm;
  }
  if (!errorHeight.isFinite || errorHeight <= 1e-4) return null;
  final exponent = rank / (dimension - rank);
  return errorHeight * math.pow(mapHeight, exponent) / justHeight;
}

double? temperamentComplexity(
  IntMatrix mapping,
  List<Rational> subgroup, {
  DoubleMatrix? weight,
}) {
  if (mapping.columnCount != subgroup.length) {
    throw ArgumentError('Mapping and subgroup dimensions differ');
  }
  final logs = logSubgroup(subgroup);
  final normalizedWeight = normalizeDeterminant(
    weight ?? DoubleMatrix.diagonal(logs.map((value) => 1.0 / (value * value))),
  );
  final mapHeight = height(
    DoubleMatrix.fromIntMatrix(mapping),
    normalizedWeight,
  );
  final calibration = height(
    DoubleMatrix.fromIntMatrix(patentMap(41.0, subgroup)),
    normalizedWeight,
  );
  if (mapHeight == null || calibration == null) return null;
  final complexity =
      math.pow(2.0, mapping.rowCount - 1) * mapHeight * 41.0 / calibration;
  return complexity.isFinite ? complexity.toDouble() : null;
}

double? _codimensionOneErrorHeight(
  IntMatrix mapping,
  List<double> logs,
  DoubleMatrix metricLower,
) {
  var determinant = 0.0;
  var correction = 0.0;
  for (var column = 0; column < mapping.columnCount; column++) {
    final minor = IntMatrix.fromRows(
      mapping.values.map(
        (row) => [
          for (var index = 0; index < mapping.columnCount; index++)
            if (index != column) row[index],
        ],
      ),
      columnCount: mapping.rowCount,
    );
    var cofactor = integerDeterminant(minor);
    if ((mapping.rowCount + column).isOdd) cofactor = -cofactor;
    final coefficient = cofactor.toDouble();
    if (!coefficient.isFinite) return null;
    final term = coefficient * logs[column];
    final updated = determinant + term;
    correction += determinant.abs() >= term.abs()
        ? (determinant - updated) + term
        : (term - updated) + determinant;
    determinant = updated;
  }

  var logMetricFactor = 0.0;
  for (var index = 0; index < metricLower.rowCount; index++) {
    final diagonal = metricLower[index][index];
    if (!diagonal.isFinite || diagonal <= 0.0) return null;
    logMetricFactor += math.log(diagonal);
  }
  final metricFactor = math.exp(logMetricFactor);
  if (!metricFactor.isFinite) return null;
  return (determinant + correction).abs() * metricFactor;
}

DoubleMatrix projectedSubgroupMetric(
  IntMatrix basis,
  DoubleMatrix expandedMetric,
) {
  final basisDouble = DoubleMatrix.fromIntMatrix(basis);
  return basisDouble
      .transpose()
      .multiply(expandedMetric.inverse())
      .multiply(basisDouble);
}

DoubleMatrix normalizeDeterminant(DoubleMatrix matrix) {
  final determinant = matrix.determinant();
  if (!determinant.isFinite || determinant <= 0) {
    throw const TemperamentException('Metric is not positive definite');
  }
  return matrix.scaled(1.0 / math.pow(determinant, 1.0 / matrix.rowCount));
}

String cents(double octaves, {int precision = 3}) {
  final value = 1200.0 * octaves;
  final roundingThreshold = 0.5 * math.pow(10.0, -precision);
  return (value.abs() < roundingThreshold ? 0.0 : value).toStringAsFixed(
    precision,
  );
}

DoubleMatrix _column(List<double> values) =>
    DoubleMatrix.fromRows(values.map((value) => [value]), columnCount: 1);
